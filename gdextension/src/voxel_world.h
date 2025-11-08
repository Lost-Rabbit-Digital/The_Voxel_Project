#ifndef VOXEL_WORLD_H
#define VOXEL_WORLD_H

#include "core/chunk.h"
#include "core/voxel_types.h"
#include "systems/terrain_generator.h"
#include "systems/chunk_mesh_builder.h"
#include "util/thread_pool.h"

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector3i.hpp>
#include <unordered_map>
#include <vector>
#include <memory>

namespace voxel {

// Hash function for Vector3i (for unordered_map)
struct Vector3iHash {
    size_t operator()(const godot::Vector3i& v) const {
        size_t h1 = std::hash<int32_t>()(v.x);
        size_t h2 = std::hash<int32_t>()(v.y);
        size_t h3 = std::hash<int32_t>()(v.z);
        return h1 ^ (h2 << 1) ^ (h3 << 2);
    }
};

class VoxelWorld : public godot::Node3D {
    GDCLASS(VoxelWorld, godot::Node3D)

private:
    // Core systems
    godot::Ref<VoxelTypeRegistry> type_registry;
    godot::Ref<TerrainGenerator> terrain_generator;
    godot::Ref<ChunkMeshBuilder> mesh_builder;
    godot::Ref<ThreadPool> thread_pool;

    // Chunk storage
    std::unordered_map<godot::Vector3i, godot::Ref<Chunk>, Vector3iHash> chunks;
    std::unordered_map<godot::Vector3i, godot::MeshInstance3D*, Vector3iHash> chunk_mesh_instances;

    // Player tracking
    godot::NodePath player_path;
    godot::Vector3 last_player_position;
    godot::Vector3i last_player_chunk;

    // Configuration
    int32_t render_distance;
    int32_t vertical_render_distance;
    int32_t world_seed;
    int32_t num_worker_threads;
    int32_t max_chunks_per_frame;

    bool use_threading;
    bool initialized;

    // Performance tracking
    int32_t chunks_generated_this_frame;
    int32_t meshes_created_this_frame;

    // Internal functions
    void initialize_systems();
    void update_player_position();
    void load_chunks_around_player();
    void unload_distant_chunks();
    void create_chunk_mesh_instance(const godot::Vector3i& pos, const godot::Ref<godot::ArrayMesh>& mesh);
    void remove_chunk_mesh_instance(const godot::Vector3i& pos);

    godot::Vector3i world_to_chunk_pos(const godot::Vector3& world_pos) const;
    bool is_chunk_in_range(const godot::Vector3i& chunk_pos, const godot::Vector3i& center, int32_t h_range, int32_t v_range) const;

    // Async chunk generation
    void generate_chunk_async(const godot::Vector3i& pos);
    void on_chunk_generated(const godot::Vector3i& pos);

protected:
    static void _bind_methods();

public:
    VoxelWorld();
    ~VoxelWorld();

    void _ready() override;
    void _process(double delta) override;

    // Configuration setters/getters
    void set_render_distance(int32_t distance);
    int32_t get_render_distance() const { return render_distance; }

    void set_vertical_render_distance(int32_t distance);
    int32_t get_vertical_render_distance() const { return vertical_render_distance; }

    void set_world_seed(int32_t seed);
    int32_t get_world_seed() const { return world_seed; }

    void set_player_path(const godot::NodePath& path);
    godot::NodePath get_player_path() const { return player_path; }

    void set_use_threading(bool enabled);
    bool get_use_threading() const { return use_threading; }

    void set_num_worker_threads(int32_t threads);
    int32_t get_num_worker_threads() const { return num_worker_threads; }

    // Chunk access
    godot::Ref<Chunk> get_chunk_at(const godot::Vector3i& pos) const;
    VoxelTypeID get_voxel_at(const godot::Vector3& world_pos) const;
    void set_voxel_at(const godot::Vector3& world_pos, VoxelTypeID type);

    // World management
    void regenerate_world();
    void clear_world();

    // Stats
    int32_t get_loaded_chunk_count() const { return chunks.size(); }
    int32_t get_active_job_count() const;
    int32_t get_pending_job_count() const;

    // Godot-exposed methods
    void _set_render_distance(int distance) { set_render_distance(distance); }
    int _get_render_distance() const { return get_render_distance(); }

    void _set_world_seed(int seed) { set_world_seed(seed); }
    int _get_world_seed() const { return get_world_seed(); }

    void _regenerate_world() { regenerate_world(); }
    void _clear_world() { clear_world(); }

    int _get_loaded_chunk_count() const { return get_loaded_chunk_count(); }
};

} // namespace voxel

#endif // VOXEL_WORLD_H
