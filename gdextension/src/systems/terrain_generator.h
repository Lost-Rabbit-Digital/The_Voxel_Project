#ifndef TERRAIN_GENERATOR_H
#define TERRAIN_GENERATOR_H

#include "../core/chunk.h"
#include "../core/voxel_types.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/fast_noise_lite.hpp>
#include <godot_cpp/classes/mutex.hpp>
#include <unordered_map>
#include <cstdint>

namespace voxel {

// Terrain generation parameters
struct TerrainParams {
    int32_t base_height = 64;
    int32_t max_height_variation = 24;
    float noise_frequency = 0.01f;
    int32_t seed = 12345;

    // Biome thresholds
    float mountain_threshold = 0.6f;
    float beach_threshold = -0.3f;
    float water_level = 64;
};

class TerrainGenerator : public godot::RefCounted {
    GDCLASS(TerrainGenerator, godot::RefCounted)

private:
    godot::Ref<godot::FastNoiseLite> noise;
    TerrainParams params;

    // Height cache (thread-safe)
    godot::Ref<godot::Mutex> cache_mutex;
    std::unordered_map<uint64_t, float> height_cache;

    // Cache key from world coordinates
    inline uint64_t make_cache_key(int32_t wx, int32_t wz) const {
        return (static_cast<uint64_t>(wx) << 32) | static_cast<uint64_t>(wz);
    }

    // Get or calculate height at world position
    float get_height_at(int32_t world_x, int32_t world_z);

    // Get biome at world position
    VoxelTypeID get_surface_block(float height, float noise_value) const;

protected:
    static void _bind_methods();

public:
    TerrainGenerator();
    ~TerrainGenerator();

    void initialize(int32_t seed);
    void set_params(const TerrainParams& p);
    const TerrainParams& get_params() const { return params; }

    // Generate terrain for a chunk
    void generate_chunk(Chunk* chunk);

    // Clear height cache
    void clear_cache();

    // Godot-exposed methods
    void _initialize(int seed);
    void _generate_chunk(const godot::Ref<Chunk>& chunk);
    void _clear_cache();
};

} // namespace voxel

#endif // TERRAIN_GENERATOR_H
