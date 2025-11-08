#include "voxel_data.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace voxel {

void VoxelData::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_voxel", "x", "y", "z"), &VoxelData::_get_voxel);
    ClassDB::bind_method(D_METHOD("set_voxel", "x", "y", "z", "type"), &VoxelData::_set_voxel);
    ClassDB::bind_method(D_METHOD("fill", "type"), &VoxelData::_fill);
    ClassDB::bind_method(D_METHOD("is_uniform"), &VoxelData::_is_uniform);
}

VoxelData::VoxelData() : chunk_size_y(DENSE_TERRAIN_CHUNK_HEIGHT), is_uniform(true), uniform_value(AIR) {
    total_voxels = CHUNK_SIZE_XZ * CHUNK_SIZE_XZ * chunk_size_y;
}

VoxelData::VoxelData(int32_t chunk_y) : chunk_size_y(chunk_y), is_uniform(true), uniform_value(AIR) {
    total_voxels = CHUNK_SIZE_XZ * CHUNK_SIZE_XZ * chunk_size_y;
}

VoxelData::~VoxelData() {
    // unique_ptr handles cleanup automatically
}

void VoxelData::initialize(int32_t chunk_y) {
    chunk_size_y = chunk_y;
    total_voxels = CHUNK_SIZE_XZ * CHUNK_SIZE_XZ * chunk_size_y;
    is_uniform = true;
    uniform_value = AIR;
    data.reset(); // Release any existing data
}

void VoxelData::clear() {
    is_uniform = true;
    uniform_value = AIR;
    data.reset();
}

void VoxelData::set_voxel(int32_t x, int32_t y, int32_t z, VoxelTypeID type) {
    // Bounds check
    if (x < 0 || x >= CHUNK_SIZE_XZ || y < 0 || y >= chunk_size_y || z < 0 || z >= CHUNK_SIZE_XZ) {
        return;
    }

    // If uniform and trying to set to same value, do nothing
    if (is_uniform && type == uniform_value) {
        return;
    }

    // If uniform but setting different value, need to expand
    if (is_uniform) {
        VoxelTypeID old_value = uniform_value;
        data = std::make_unique<VoxelTypeID[]>(total_voxels);

        // Fill with old uniform value
        std::memset(data.get(), old_value, total_voxels);

        is_uniform = false;
    }

    // Set the voxel
    int32_t idx = get_index(x, y, z);
    data[idx] = type;
}

void VoxelData::fill(VoxelTypeID type) {
    is_uniform = true;
    uniform_value = type;
    data.reset(); // Free memory
}

bool VoxelData::check_and_optimize_uniform() {
    if (is_uniform) {
        return true; // Already optimized
    }

    if (!data) {
        is_uniform = true;
        uniform_value = AIR;
        return true;
    }

    // Check if all voxels are the same
    VoxelTypeID first_value = data[0];
    for (int32_t i = 1; i < total_voxels; i++) {
        if (data[i] != first_value) {
            return false; // Not uniform
        }
    }

    // All values are the same - optimize!
    uniform_value = first_value;
    is_uniform = true;
    data.reset(); // Free memory
    return true;
}

size_t VoxelData::get_memory_usage() const {
    if (is_uniform) {
        return sizeof(VoxelTypeID); // Just the uniform value
    }
    return total_voxels * sizeof(VoxelTypeID);
}

// Godot-exposed methods
int VoxelData::_get_voxel(int x, int y, int z) const {
    if (x < 0 || x >= CHUNK_SIZE_XZ || y < 0 || y >= chunk_size_y || z < 0 || z >= CHUNK_SIZE_XZ) {
        return AIR;
    }
    return static_cast<int>(get_voxel(x, y, z));
}

void VoxelData::_set_voxel(int x, int y, int z, int type) {
    if (type >= 0 && type < MAX_BLOCK_TYPES) {
        set_voxel(x, y, z, static_cast<VoxelTypeID>(type));
    }
}

void VoxelData::_fill(int type) {
    if (type >= 0 && type < MAX_BLOCK_TYPES) {
        fill(static_cast<VoxelTypeID>(type));
    }
}

bool VoxelData::_is_uniform() const {
    return is_uniform;
}

} // namespace voxel
