#ifndef VOXEL_DATA_H
#define VOXEL_DATA_H

#include "voxel_types.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <cstdint>
#include <cstring>
#include <memory>

namespace voxel {

// Adaptive chunk heights based on Y-level zones (Sodium-inspired)
constexpr int32_t CHUNK_SIZE_XZ = 16;
constexpr int32_t DEEP_VOID_CHUNK_HEIGHT = 32;
constexpr int32_t DENSE_TERRAIN_CHUNK_HEIGHT = 16;
constexpr int32_t SKY_CHUNK_HEIGHT = 64;

// Y-level zones
constexpr int32_t DEEP_VOID_MAX_Y = -64;
constexpr int32_t DENSE_TERRAIN_MAX_Y = 180;

class VoxelData : public godot::RefCounted {
    GDCLASS(VoxelData, godot::RefCounted)

private:
    int32_t chunk_size_y;
    int32_t total_voxels;

    // Uniform chunk optimization (Zylann technique)
    bool is_uniform;
    VoxelTypeID uniform_value;

    // Actual voxel data (only allocated if not uniform)
    std::unique_ptr<VoxelTypeID[]> data;

    inline int32_t get_index(int32_t x, int32_t y, int32_t z) const {
        return x + y * CHUNK_SIZE_XZ + z * CHUNK_SIZE_XZ * chunk_size_y;
    }

protected:
    static void _bind_methods();

public:
    VoxelData();
    VoxelData(int32_t chunk_y);
    ~VoxelData();

    void initialize(int32_t chunk_y);
    void clear();

    // Fast voxel access
    inline VoxelTypeID get_voxel(int32_t x, int32_t y, int32_t z) const {
        if (is_uniform) {
            return uniform_value;
        }
        int32_t idx = get_index(x, y, z);
        return data[idx];
    }

    void set_voxel(int32_t x, int32_t y, int32_t z, VoxelTypeID type);
    void fill(VoxelTypeID type);

    // Uniform chunk optimization
    bool check_and_optimize_uniform();
    inline bool get_is_uniform() const { return is_uniform; }
    inline VoxelTypeID get_uniform_value() const { return uniform_value; }

    // Memory stats
    size_t get_memory_usage() const;

    // Getters
    inline int32_t get_chunk_size_y() const { return chunk_size_y; }
    inline int32_t get_total_voxels() const { return total_voxels; }

    // Godot-exposed methods
    int _get_voxel(int x, int y, int z) const;
    void _set_voxel(int x, int y, int z, int type);
    void _fill(int type);
    bool _is_uniform() const;
};

// Utility: Determine chunk height based on world Y coordinate
inline int32_t get_chunk_height_for_y(int32_t world_y) {
    if (world_y < DEEP_VOID_MAX_Y) {
        return DEEP_VOID_CHUNK_HEIGHT;
    } else if (world_y < DENSE_TERRAIN_MAX_Y) {
        return DENSE_TERRAIN_CHUNK_HEIGHT;
    } else {
        return SKY_CHUNK_HEIGHT;
    }
}

// Convert world Y to chunk Y index
inline int32_t world_y_to_chunk_y(int32_t world_y) {
    int32_t chunk_height = get_chunk_height_for_y(world_y);
    return world_y / chunk_height;
}

// Convert chunk Y to world Y
inline int32_t chunk_y_to_world_y(int32_t chunk_y) {
    // This is complex due to variable heights - simplified for now
    return chunk_y * DENSE_TERRAIN_CHUNK_HEIGHT;
}

} // namespace voxel

#endif // VOXEL_DATA_H
