#include "chunk.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace voxel {

void Chunk::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_position"), &Chunk::_get_position);
    ClassDB::bind_method(D_METHOD("get_voxel", "x", "y", "z"), &Chunk::_get_voxel);
    ClassDB::bind_method(D_METHOD("set_voxel", "x", "y", "z", "type"), &Chunk::_set_voxel);
}

Chunk::Chunk() :
    position(Vector3i(0, 0, 0)),
    world_position(Vector3(0, 0, 0)),
    state(ChunkState::INACTIVE),
    mesh_dirty(true),
    cached_vertex_count(0),
    has_cached_mesh(false),
    memory_usage(0) {

    for (int i = 0; i < 6; i++) {
        neighbors[i] = nullptr;
    }
}

Chunk::~Chunk() {
    clear_neighbors();
}

void Chunk::initialize(const Vector3i& pos, int32_t chunk_height) {
    position = pos;
    world_position = Vector3(
        pos.x * CHUNK_SIZE_XZ,
        pos.y * chunk_height,
        pos.z * CHUNK_SIZE_XZ
    );

    voxel_data = std::make_unique<VoxelData>(chunk_height);
    state.store(ChunkState::INACTIVE, std::memory_order_release);
    mesh_dirty = true;
    has_cached_mesh = false;
    cached_vertex_count = 0;

    update_memory_usage();
}

void Chunk::reset() {
    // For object pooling - reset to initial state
    if (voxel_data) {
        voxel_data->clear();
    }

    mesh.unref();
    cached_mesh_arrays.clear();
    has_cached_mesh = false;
    cached_vertex_count = 0;

    state.store(ChunkState::INACTIVE, std::memory_order_release);
    mesh_dirty = true;

    clear_neighbors();
    update_memory_usage();
}

VoxelTypeID Chunk::get_voxel(int32_t x, int32_t y, int32_t z) const {
    if (!voxel_data) {
        return AIR;
    }
    return voxel_data->get_voxel(x, y, z);
}

void Chunk::set_voxel(int32_t x, int32_t y, int32_t z, VoxelTypeID type) {
    if (voxel_data) {
        voxel_data->set_voxel(x, y, z, type);
        mesh_dirty = true;
    }
}

void Chunk::fill(VoxelTypeID type) {
    if (voxel_data) {
        voxel_data->fill(type);
        mesh_dirty = true;
    }
}

void Chunk::set_position(const Vector3i& pos) {
    position = pos;
    if (voxel_data) {
        world_position = Vector3(
            pos.x * CHUNK_SIZE_XZ,
            pos.y * voxel_data->get_chunk_size_y(),
            pos.z * CHUNK_SIZE_XZ
        );
    }
}

void Chunk::set_mesh(const Ref<ArrayMesh>& new_mesh) {
    mesh = new_mesh;
    mesh_dirty = false;
    update_memory_usage();
}

void Chunk::set_cached_mesh_arrays(const Array& arrays, int32_t vertex_count) {
    cached_mesh_arrays = arrays;
    cached_vertex_count = vertex_count;
    has_cached_mesh = true;
    update_memory_usage();
}

void Chunk::clear_cached_mesh() {
    cached_mesh_arrays.clear();
    cached_vertex_count = 0;
    has_cached_mesh = false;
}

void Chunk::set_neighbor(int32_t direction, Chunk* neighbor) {
    if (direction >= 0 && direction < 6) {
        neighbors[direction] = neighbor;
    }
}

Chunk* Chunk::get_neighbor(int32_t direction) const {
    if (direction >= 0 && direction < 6) {
        return neighbors[direction];
    }
    return nullptr;
}

void Chunk::clear_neighbors() {
    for (int i = 0; i < 6; i++) {
        neighbors[i] = nullptr;
    }
}

size_t Chunk::get_memory_usage() const {
    return memory_usage;
}

void Chunk::update_memory_usage() {
    memory_usage = sizeof(Chunk);

    if (voxel_data) {
        memory_usage += voxel_data->get_memory_usage();
    }

    // Rough estimate for mesh data
    if (mesh.is_valid()) {
        memory_usage += cached_vertex_count * 32; // Approx 32 bytes per vertex
    }
}

// Godot-exposed methods
int Chunk::_get_voxel(int x, int y, int z) const {
    return static_cast<int>(get_voxel(x, y, z));
}

void Chunk::_set_voxel(int x, int y, int z, int type) {
    if (type >= 0 && type < MAX_BLOCK_TYPES) {
        set_voxel(x, y, z, static_cast<VoxelTypeID>(type));
    }
}

} // namespace voxel
