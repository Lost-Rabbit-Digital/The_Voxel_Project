#include "voxel_world.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/engine.hpp>

using namespace godot;

namespace voxel {

void VoxelWorld::_bind_methods() {
    // Properties
    ClassDB::bind_method(D_METHOD("set_render_distance", "distance"), &VoxelWorld::_set_render_distance);
    ClassDB::bind_method(D_METHOD("get_render_distance"), &VoxelWorld::_get_render_distance);
    ClassDB::add_property("VoxelWorld", PropertyInfo(Variant::INT, "render_distance"), "set_render_distance", "get_render_distance");

    ClassDB::bind_method(D_METHOD("set_world_seed", "seed"), &VoxelWorld::_set_world_seed);
    ClassDB::bind_method(D_METHOD("get_world_seed"), &VoxelWorld::_get_world_seed);
    ClassDB::add_property("VoxelWorld", PropertyInfo(Variant::INT, "world_seed"), "set_world_seed", "get_world_seed");

    ClassDB::bind_method(D_METHOD("set_player_path", "path"), &VoxelWorld::set_player_path);
    ClassDB::bind_method(D_METHOD("get_player_path"), &VoxelWorld::get_player_path);
    ClassDB::add_property("VoxelWorld", PropertyInfo(Variant::NODE_PATH, "player_path"), "set_player_path", "get_player_path");

    // Methods
    ClassDB::bind_method(D_METHOD("regenerate_world"), &VoxelWorld::_regenerate_world);
    ClassDB::bind_method(D_METHOD("clear_world"), &VoxelWorld::_clear_world);
    ClassDB::bind_method(D_METHOD("get_loaded_chunk_count"), &VoxelWorld::_get_loaded_chunk_count);
}

VoxelWorld::VoxelWorld() :
    last_player_position(Vector3(0, 0, 0)),
    last_player_chunk(Vector3i(0, 0, 0)),
    render_distance(8),
    vertical_render_distance(4),
    world_seed(12345),
    num_worker_threads(4),
    max_chunks_per_frame(4),
    use_threading(true),
    initialized(false),
    chunks_generated_this_frame(0),
    meshes_created_this_frame(0) {
}

VoxelWorld::~VoxelWorld() {
    clear_world();
}

void VoxelWorld::_ready() {
    if (Engine::get_singleton()->is_editor_hint()) {
        return; // Don't initialize in editor
    }

    initialize_systems();
}

void VoxelWorld::initialize_systems() {
    if (initialized) {
        return;
    }

    // Create type registry
    type_registry.instantiate();

    // Create terrain generator
    terrain_generator.instantiate();
    terrain_generator->initialize(world_seed);

    // Create mesh builder
    mesh_builder.instantiate();

    // Create thread pool
    if (use_threading) {
        thread_pool.instantiate();
        thread_pool->initialize(num_worker_threads);
    }

    initialized = true;
    UtilityFunctions::print("VoxelWorld: Systems initialized");
}

void VoxelWorld::_process(double delta) {
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }

    if (!initialized) {
        return;
    }

    // Reset frame counters
    chunks_generated_this_frame = 0;
    meshes_created_this_frame = 0;

    update_player_position();
    load_chunks_around_player();
    unload_distant_chunks();
}

void VoxelWorld::update_player_position() {
    if (player_path.is_empty()) {
        return;
    }

    Node* player_node = get_node_or_null(player_path);
    if (!player_node) {
        return;
    }

    Node3D* player_3d = Object::cast_to<Node3D>(player_node);
    if (!player_3d) {
        return;
    }

    Vector3 player_pos = player_3d->get_global_position();
    Vector3i player_chunk = world_to_chunk_pos(player_pos);

    last_player_position = player_pos;
    last_player_chunk = player_chunk;
}

void VoxelWorld::load_chunks_around_player() {
    // Radial loading pattern (spiral from center)
    Vector3i center = last_player_chunk;

    for (int32_t dy = -vertical_render_distance; dy <= vertical_render_distance; dy++) {
        for (int32_t r = 0; r <= render_distance; r++) {
            for (int32_t dx = -r; dx <= r; dx++) {
                for (int32_t dz = -r; dz <= r; dz++) {
                    // Only load chunks on the edge of current radius
                    if (abs(dx) != r && abs(dz) != r) {
                        continue;
                    }

                    Vector3i chunk_pos = Vector3i(center.x + dx, center.y + dy, center.z + dz);

                    // Check if chunk already exists
                    if (chunks.find(chunk_pos) != chunks.end()) {
                        continue;
                    }

                    // Limit chunks per frame
                    if (chunks_generated_this_frame >= max_chunks_per_frame) {
                        return;
                    }

                    // Create chunk
                    generate_chunk_async(chunk_pos);
                    chunks_generated_this_frame++;
                }
            }
        }
    }
}

void VoxelWorld::unload_distant_chunks() {
    std::vector<Vector3i> to_unload;

    for (const auto& pair : chunks) {
        const Vector3i& pos = pair.first;
        if (!is_chunk_in_range(pos, last_player_chunk, render_distance, vertical_render_distance)) {
            to_unload.push_back(pos);
        }
    }

    for (const Vector3i& pos : to_unload) {
        remove_chunk_mesh_instance(pos);
        chunks.erase(pos);
    }
}

void VoxelWorld::generate_chunk_async(const Vector3i& pos) {
    // Create chunk
    Ref<Chunk> chunk;
    chunk.instantiate();

    int32_t chunk_height = get_chunk_height_for_y(pos.y);
    chunk->initialize(pos, chunk_height);
    chunk->set_state(ChunkState::GENERATING);

    chunks[pos] = chunk;

    if (use_threading && thread_pool.is_valid()) {
        // Generate terrain async
        thread_pool->submit_job(JobType::GENERATE_TERRAIN, [this, pos, chunk]() {
            terrain_generator->generate_chunk(chunk.ptr());

            // Build mesh async
            Ref<ArrayMesh> mesh = mesh_builder->build_mesh(chunk.ptr());

            // Schedule mesh creation on main thread (must be done on main thread)
            call_deferred("create_chunk_mesh_instance", pos, mesh);
        }, 0);
    } else {
        // Synchronous generation
        terrain_generator->generate_chunk(chunk.ptr());
        Ref<ArrayMesh> mesh = mesh_builder->build_mesh(chunk.ptr());
        create_chunk_mesh_instance(pos, mesh);
    }
}

void VoxelWorld::create_chunk_mesh_instance(const Vector3i& pos, const Ref<ArrayMesh>& mesh) {
    if (mesh.is_null()) {
        return;
    }

    // Check if chunk still exists (might have been unloaded)
    auto it = chunks.find(pos);
    if (it == chunks.end()) {
        return;
    }

    // Remove old mesh instance if exists
    remove_chunk_mesh_instance(pos);

    // Create mesh instance
    MeshInstance3D* mesh_instance = memnew(MeshInstance3D);
    mesh_instance->set_mesh(mesh);

    Vector3 world_pos = Vector3(
        pos.x * CHUNK_SIZE_XZ,
        pos.y * it->second->get_voxel_data()->get_chunk_size_y(),
        pos.z * CHUNK_SIZE_XZ
    );
    mesh_instance->set_position(world_pos);

    add_child(mesh_instance);
    chunk_mesh_instances[pos] = mesh_instance;

    it->second->set_mesh(mesh);
    it->second->set_state(ChunkState::ACTIVE);
}

void VoxelWorld::remove_chunk_mesh_instance(const Vector3i& pos) {
    auto it = chunk_mesh_instances.find(pos);
    if (it != chunk_mesh_instances.end()) {
        if (it->second) {
            it->second->queue_free();
        }
        chunk_mesh_instances.erase(it);
    }
}

Vector3i VoxelWorld::world_to_chunk_pos(const Vector3& world_pos) const {
    return Vector3i(
        static_cast<int32_t>(floor(world_pos.x / CHUNK_SIZE_XZ)),
        world_y_to_chunk_y(static_cast<int32_t>(world_pos.y)),
        static_cast<int32_t>(floor(world_pos.z / CHUNK_SIZE_XZ))
    );
}

bool VoxelWorld::is_chunk_in_range(const Vector3i& chunk_pos, const Vector3i& center, int32_t h_range, int32_t v_range) const {
    int32_t dx = abs(chunk_pos.x - center.x);
    int32_t dy = abs(chunk_pos.y - center.y);
    int32_t dz = abs(chunk_pos.z - center.z);

    return dx <= h_range && dz <= h_range && dy <= v_range;
}

void VoxelWorld::set_render_distance(int32_t distance) {
    render_distance = distance;
}

void VoxelWorld::set_vertical_render_distance(int32_t distance) {
    vertical_render_distance = distance;
}

void VoxelWorld::set_world_seed(int32_t seed) {
    world_seed = seed;
    if (terrain_generator.is_valid()) {
        terrain_generator->initialize(seed);
    }
}

void VoxelWorld::set_player_path(const NodePath& path) {
    player_path = path;
}

void VoxelWorld::set_use_threading(bool enabled) {
    use_threading = enabled;
}

void VoxelWorld::set_num_worker_threads(int32_t threads) {
    num_worker_threads = threads;
    if (thread_pool.is_valid()) {
        thread_pool->shutdown();
        thread_pool->initialize(threads);
    }
}

Ref<Chunk> VoxelWorld::get_chunk_at(const Vector3i& pos) const {
    auto it = chunks.find(pos);
    if (it != chunks.end()) {
        return it->second;
    }
    return Ref<Chunk>();
}

VoxelTypeID VoxelWorld::get_voxel_at(const Vector3& world_pos) const {
    Vector3i chunk_pos = world_to_chunk_pos(world_pos);
    Ref<Chunk> chunk = get_chunk_at(chunk_pos);

    if (chunk.is_null()) {
        return AIR;
    }

    int32_t local_x = static_cast<int32_t>(world_pos.x) % CHUNK_SIZE_XZ;
    int32_t local_y = static_cast<int32_t>(world_pos.y) % chunk->get_voxel_data()->get_chunk_size_y();
    int32_t local_z = static_cast<int32_t>(world_pos.z) % CHUNK_SIZE_XZ;

    return chunk->get_voxel(local_x, local_y, local_z);
}

void VoxelWorld::set_voxel_at(const Vector3& world_pos, VoxelTypeID type) {
    Vector3i chunk_pos = world_to_chunk_pos(world_pos);
    Ref<Chunk> chunk = get_chunk_at(chunk_pos);

    if (chunk.is_null()) {
        return;
    }

    int32_t local_x = static_cast<int32_t>(world_pos.x) % CHUNK_SIZE_XZ;
    int32_t local_y = static_cast<int32_t>(world_pos.y) % chunk->get_voxel_data()->get_chunk_size_y();
    int32_t local_z = static_cast<int32_t>(world_pos.z) % CHUNK_SIZE_XZ;

    chunk->set_voxel(local_x, local_y, local_z, type);
    chunk->mark_mesh_dirty();

    // Rebuild mesh
    Ref<ArrayMesh> mesh = mesh_builder->build_mesh(chunk.ptr());
    create_chunk_mesh_instance(chunk_pos, mesh);
}

void VoxelWorld::regenerate_world() {
    clear_world();
    if (terrain_generator.is_valid()) {
        terrain_generator->clear_cache();
    }
}

void VoxelWorld::clear_world() {
    // Remove all mesh instances
    for (auto& pair : chunk_mesh_instances) {
        if (pair.second) {
            pair.second->queue_free();
        }
    }
    chunk_mesh_instances.clear();

    // Clear chunks
    chunks.clear();
}

int32_t VoxelWorld::get_active_job_count() const {
    if (thread_pool.is_valid()) {
        return thread_pool->get_active_job_count();
    }
    return 0;
}

int32_t VoxelWorld::get_pending_job_count() const {
    if (thread_pool.is_valid()) {
        return thread_pool->get_pending_job_count();
    }
    return 0;
}

} // namespace voxel
