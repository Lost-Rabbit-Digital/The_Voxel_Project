#include "terrain_generator.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

using namespace godot;

namespace voxel {

void TerrainGenerator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "seed"), &TerrainGenerator::_initialize);
    ClassDB::bind_method(D_METHOD("generate_chunk", "chunk"), &TerrainGenerator::_generate_chunk);
    ClassDB::bind_method(D_METHOD("clear_cache"), &TerrainGenerator::_clear_cache);
}

TerrainGenerator::TerrainGenerator() {
    noise.instantiate();
    cache_mutex.instantiate();

    // Configure noise
    noise->set_noise_type(FastNoiseLite::TYPE_PERLIN);
    noise->set_frequency(params.noise_frequency);
    noise->set_seed(params.seed);
}

TerrainGenerator::~TerrainGenerator() {
    clear_cache();
}

void TerrainGenerator::initialize(int32_t seed) {
    params.seed = seed;
    noise->set_seed(seed);
    clear_cache();
}

void TerrainGenerator::set_params(const TerrainParams& p) {
    params = p;
    noise->set_frequency(params.noise_frequency);
    noise->set_seed(params.seed);
    clear_cache();
}

float TerrainGenerator::get_height_at(int32_t world_x, int32_t world_z) {
    uint64_t key = make_cache_key(world_x, world_z);

    // Check cache first
    cache_mutex->lock();
    auto it = height_cache.find(key);
    if (it != height_cache.end()) {
        float height = it->second;
        cache_mutex->unlock();
        return height;
    }
    cache_mutex->unlock();

    // Calculate height
    float noise_value = noise->get_noise_2d(world_x, world_z);
    float height = params.base_height + (noise_value * params.max_height_variation);

    // Cache the result
    cache_mutex->lock();
    height_cache[key] = height;
    cache_mutex->unlock();

    return height;
}

VoxelTypeID TerrainGenerator::get_surface_block(float height, float noise_value) const {
    // Mountains (high noise values)
    if (noise_value > params.mountain_threshold) {
        if (height > params.base_height + 15) {
            return STONE; // Mountain peaks
        } else {
            return GRAVEL; // Rocky terrain
        }
    }

    // Beach/Desert (low noise values)
    if (noise_value < params.beach_threshold) {
        return SAND;
    }

    // Normal terrain
    if (height > params.water_level) {
        return GRASS;
    } else {
        return SAND; // Underwater sand
    }
}

void TerrainGenerator::generate_chunk(Chunk* chunk) {
    if (!chunk || !chunk->get_voxel_data()) {
        return;
    }

    VoxelData* voxel_data = chunk->get_voxel_data();
    Vector3i chunk_pos = chunk->get_position();
    int32_t chunk_size_y = voxel_data->get_chunk_size_y();

    // Calculate world Y range for this chunk
    int32_t chunk_world_y_base = chunk_pos.y * chunk_size_y;
    int32_t chunk_world_y_max = chunk_world_y_base + chunk_size_y;

    // Quick check: if chunk is entirely above or below terrain, fill uniformly
    int32_t world_x_base = chunk_pos.x * CHUNK_SIZE_XZ;
    int32_t world_z_base = chunk_pos.z * CHUNK_SIZE_XZ;

    // Sample a few heights to check if chunk is entirely air or stone
    bool all_above_terrain = true;
    bool all_below_terrain = true;

    for (int32_t z = 0; z < CHUNK_SIZE_XZ; z += 4) {
        for (int32_t x = 0; x < CHUNK_SIZE_XZ; x += 4) {
            int32_t wx = world_x_base + x;
            int32_t wz = world_z_base + z;
            float height = get_height_at(wx, wz);

            if (chunk_world_y_base <= height) {
                all_above_terrain = false;
            }
            if (chunk_world_y_max - 1 >= height) {
                all_below_terrain = false;
            }
        }
    }

    // Optimize uniform chunks
    if (all_above_terrain) {
        voxel_data->fill(AIR);
        chunk->set_state(ChunkState::ACTIVE);
        return;
    }

    // Generate voxels
    for (int32_t z = 0; z < CHUNK_SIZE_XZ; z++) {
        for (int32_t x = 0; x < CHUNK_SIZE_XZ; x++) {
            int32_t wx = world_x_base + x;
            int32_t wz = world_z_base + z;

            float height = get_height_at(wx, wz);
            float noise_value = noise->get_noise_2d(wx, wz);

            for (int32_t y = 0; y < chunk_size_y; y++) {
                int32_t wy = chunk_world_y_base + y;

                VoxelTypeID voxel_type = AIR;

                if (wy < height) {
                    // Underground
                    if (wy < height - 4) {
                        voxel_type = STONE;
                    } else {
                        voxel_type = DIRT;
                    }
                } else if (wy == static_cast<int32_t>(height)) {
                    // Surface
                    voxel_type = get_surface_block(height, noise_value);
                } else if (wy < params.water_level) {
                    // Water
                    voxel_type = WATER;
                }

                if (voxel_type != AIR) {
                    voxel_data->set_voxel(x, y, z, voxel_type);
                }
            }
        }
    }

    // Try to optimize if chunk became uniform
    voxel_data->check_and_optimize_uniform();

    chunk->set_state(ChunkState::ACTIVE);
}

void TerrainGenerator::clear_cache() {
    cache_mutex->lock();
    height_cache.clear();
    cache_mutex->unlock();
}

// Godot-exposed methods
void TerrainGenerator::_initialize(int seed) {
    initialize(static_cast<int32_t>(seed));
}

void TerrainGenerator::_generate_chunk(const Ref<Chunk>& chunk) {
    if (chunk.is_valid()) {
        generate_chunk(chunk.ptr());
    }
}

void TerrainGenerator::_clear_cache() {
    clear_cache();
}

} // namespace voxel
