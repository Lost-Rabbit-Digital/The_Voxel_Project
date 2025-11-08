#ifndef CHUNK_H
#define CHUNK_H

#include "voxel_data.h"
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector3i.hpp>
#include <memory>
#include <atomic>

namespace voxel {

// Chunk lifecycle states
enum class ChunkState {
    INACTIVE,
    GENERATING,
    MESHING,
    ACTIVE,
    UNLOADING
};

class Chunk : public godot::RefCounted {
    GDCLASS(Chunk, godot::RefCounted)

private:
    godot::Vector3i position; // Chunk coordinates
    godot::Vector3 world_position; // World position
    std::unique_ptr<VoxelData> voxel_data;
    std::atomic<ChunkState> state;

    // Mesh data
    godot::Ref<godot::ArrayMesh> mesh;
    bool mesh_dirty;

    // Cached mesh arrays for region batching
    godot::Array cached_mesh_arrays;
    int32_t cached_vertex_count;
    bool has_cached_mesh;

    // Neighbor references for cross-chunk face culling
    Chunk* neighbors[6]; // -X, +X, -Y, +Y, -Z, +Z

    // Memory tracking
    size_t memory_usage;

protected:
    static void _bind_methods();

public:
    Chunk();
    ~Chunk();

    // Initialization
    void initialize(const godot::Vector3i& pos, int32_t chunk_height);
    void reset(); // For object pooling

    // Voxel access
    VoxelTypeID get_voxel(int32_t x, int32_t y, int32_t z) const;
    void set_voxel(int32_t x, int32_t y, int32_t z, VoxelTypeID type);
    void fill(VoxelTypeID type);

    // State management
    ChunkState get_state() const { return state.load(std::memory_order_acquire); }
    void set_state(ChunkState new_state) { state.store(new_state, std::memory_order_release); }
    bool is_active() const { return get_state() == ChunkState::ACTIVE; }

    // Position
    const godot::Vector3i& get_position() const { return position; }
    const godot::Vector3& get_world_position() const { return world_position; }
    void set_position(const godot::Vector3i& pos);

    // Mesh
    void set_mesh(const godot::Ref<godot::ArrayMesh>& new_mesh);
    godot::Ref<godot::ArrayMesh> get_mesh() const { return mesh; }
    bool is_mesh_dirty() const { return mesh_dirty; }
    void mark_mesh_dirty() { mesh_dirty = true; }

    // Cached mesh arrays (for region batching)
    void set_cached_mesh_arrays(const godot::Array& arrays, int32_t vertex_count);
    const godot::Array& get_cached_mesh_arrays() const { return cached_mesh_arrays; }
    int32_t get_cached_vertex_count() const { return cached_vertex_count; }
    bool has_cached_mesh_data() const { return has_cached_mesh; }
    void clear_cached_mesh();

    // Neighbors
    void set_neighbor(int32_t direction, Chunk* neighbor);
    Chunk* get_neighbor(int32_t direction) const;
    void clear_neighbors();

    // VoxelData access
    VoxelData* get_voxel_data() const { return voxel_data.get(); }

    // Memory
    size_t get_memory_usage() const;
    void update_memory_usage();

    // Godot-exposed methods
    godot::Vector3i _get_position() const { return position; }
    int _get_voxel(int x, int y, int z) const;
    void _set_voxel(int x, int y, int z, int type);
};

// Direction indices for neighbor array
enum NeighborDirection {
    DIR_NEG_X = 0,
    DIR_POS_X = 1,
    DIR_NEG_Y = 2,
    DIR_POS_Y = 3,
    DIR_NEG_Z = 4,
    DIR_POS_Z = 5
};

} // namespace voxel

#endif // CHUNK_H
