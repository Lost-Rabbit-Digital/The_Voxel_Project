#ifndef THREAD_POOL_H
#define THREAD_POOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/classes/semaphore.hpp>
#include <godot_cpp/classes/mutex.hpp>
#include <vector>
#include <queue>
#include <functional>
#include <atomic>
#include <memory>

namespace voxel {

// Job types
enum class JobType {
    GENERATE_TERRAIN,
    BUILD_MESH,
    BUILD_REGION_MESH
};

// Job structure
struct Job {
    JobType type;
    std::function<void()> task;
    int32_t priority; // Higher = more important

    Job() : type(JobType::GENERATE_TERRAIN), priority(0) {}
    Job(JobType t, std::function<void()> fn, int32_t prio = 0) :
        type(t), task(std::move(fn)), priority(prio) {}

    bool operator<(const Job& other) const {
        return priority < other.priority; // Lower priority = higher in queue
    }
};

class ThreadPool : public godot::RefCounted {
    GDCLASS(ThreadPool, godot::RefCounted)

private:
    int32_t num_threads;
    std::vector<godot::Ref<godot::Thread>> workers;

    // Job queue (priority queue)
    std::priority_queue<Job> job_queue;
    godot::Ref<godot::Mutex> queue_mutex;
    godot::Ref<godot::Semaphore> queue_semaphore;

    std::atomic<bool> should_stop;
    std::atomic<int32_t> active_jobs;
    std::atomic<int32_t> pending_jobs;

    int32_t max_pending_jobs;

    // Worker thread function
    void worker_thread();
    static void _worker_thread_func(void* userdata);

protected:
    static void _bind_methods();

public:
    ThreadPool();
    ThreadPool(int32_t threads);
    ~ThreadPool();

    void initialize(int32_t threads);
    void shutdown();

    // Submit job
    bool submit_job(JobType type, std::function<void()> task, int32_t priority = 0);

    // Query
    int32_t get_active_job_count() const { return active_jobs.load(); }
    int32_t get_pending_job_count() const { return pending_jobs.load(); }
    int32_t get_num_threads() const { return num_threads; }

    void set_max_pending_jobs(int32_t max) { max_pending_jobs = max; }
    int32_t get_max_pending_jobs() const { return max_pending_jobs; }

    // Godot-exposed methods
    void _initialize(int threads);
    void _shutdown();
    int _get_active_job_count() const;
    int _get_pending_job_count() const;
};

} // namespace voxel

#endif // THREAD_POOL_H
