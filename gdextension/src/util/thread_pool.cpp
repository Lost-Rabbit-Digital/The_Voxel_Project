#include "thread_pool.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace voxel {

void ThreadPool::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "threads"), &ThreadPool::_initialize);
    ClassDB::bind_method(D_METHOD("shutdown"), &ThreadPool::_shutdown);
    ClassDB::bind_method(D_METHOD("get_active_job_count"), &ThreadPool::_get_active_job_count);
    ClassDB::bind_method(D_METHOD("get_pending_job_count"), &ThreadPool::_get_pending_job_count);
}

ThreadPool::ThreadPool() :
    num_threads(0),
    should_stop(false),
    active_jobs(0),
    pending_jobs(0),
    max_pending_jobs(1000) {

    queue_mutex.instantiate();
    queue_semaphore.instantiate();
}

ThreadPool::ThreadPool(int32_t threads) : ThreadPool() {
    initialize(threads);
}

ThreadPool::~ThreadPool() {
    shutdown();
}

void ThreadPool::initialize(int32_t threads) {
    if (num_threads > 0) {
        shutdown(); // Shutdown existing pool
    }

    num_threads = threads;
    should_stop.store(false);
    workers.clear();
    workers.reserve(num_threads);

    // Create worker threads
    for (int32_t i = 0; i < num_threads; i++) {
        Ref<Thread> thread;
        thread.instantiate();
        thread->start(callable_mp(this, &ThreadPool::worker_thread));
        workers.push_back(thread);
    }
}

void ThreadPool::shutdown() {
    if (num_threads == 0) {
        return;
    }

    // Signal all threads to stop
    should_stop.store(true);

    // Wake up all threads
    for (int32_t i = 0; i < num_threads; i++) {
        queue_semaphore->post();
    }

    // Wait for all threads to finish
    for (auto& thread : workers) {
        if (thread.is_valid() && thread->is_started()) {
            thread->wait_to_finish();
        }
    }

    workers.clear();
    num_threads = 0;

    // Clear remaining jobs
    queue_mutex->lock();
    while (!job_queue.empty()) {
        job_queue.pop();
    }
    pending_jobs.store(0);
    queue_mutex->unlock();
}

bool ThreadPool::submit_job(JobType type, std::function<void()> task, int32_t priority) {
    if (should_stop.load()) {
        return false;
    }

    // Check if we're at max pending jobs
    if (pending_jobs.load() >= max_pending_jobs) {
        return false;
    }

    queue_mutex->lock();
    job_queue.emplace(type, std::move(task), priority);
    pending_jobs.fetch_add(1);
    queue_mutex->unlock();

    queue_semaphore->post();
    return true;
}

void ThreadPool::worker_thread() {
    while (!should_stop.load()) {
        // Wait for job
        queue_semaphore->wait();

        if (should_stop.load()) {
            break;
        }

        // Get job
        queue_mutex->lock();
        if (job_queue.empty()) {
            queue_mutex->unlock();
            continue;
        }

        Job job = job_queue.top();
        job_queue.pop();
        pending_jobs.fetch_sub(1);
        queue_mutex->unlock();

        // Execute job
        active_jobs.fetch_add(1);
        if (job.task) {
            job.task();
        }
        active_jobs.fetch_sub(1);
    }
}

// Godot-exposed methods
void ThreadPool::_initialize(int threads) {
    initialize(static_cast<int32_t>(threads));
}

void ThreadPool::_shutdown() {
    shutdown();
}

int ThreadPool::_get_active_job_count() const {
    return get_active_job_count();
}

int ThreadPool::_get_pending_job_count() const {
    return get_pending_job_count();
}

} // namespace voxel
