#ifndef VOXEL_TYPES_H
#define VOXEL_TYPES_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <cstdint>
#include <unordered_map>
#include <string>

namespace voxel {

// Voxel type ID (8-bit, supports 256 block types)
using VoxelTypeID = uint8_t;

// Core block types
enum BlockType : VoxelTypeID {
    AIR = 0,
    STONE = 1,
    DIRT = 2,
    GRASS = 3,
    SAND = 4,
    WATER = 5,
    GRAVEL = 6,
    WOOD = 7,
    LEAVES = 8,
    COAL_ORE = 9,
    IRON_ORE = 10,
    GOLD_ORE = 11,
    DIAMOND_ORE = 12,
    BEDROCK = 13,
    TORCH = 14,
    GLASS = 15
    // Add more types as needed
};

// Maximum number of block types (256 for uint8_t)
constexpr int MAX_BLOCK_TYPES = 256;

// Block properties
struct BlockProperties {
    std::string name;
    godot::Color color;
    float hardness;
    bool is_transparent;
    bool is_solid;
    uint8_t light_emission;

    BlockProperties() :
        name("unknown"),
        color(godot::Color(1, 0, 1)), // Magenta for unknown
        hardness(1.0f),
        is_transparent(false),
        is_solid(true),
        light_emission(0) {}

    BlockProperties(const std::string& n, const godot::Color& c, float h, bool trans, bool solid, uint8_t light = 0) :
        name(n), color(c), hardness(h), is_transparent(trans), is_solid(solid), light_emission(light) {}
};

class VoxelTypeRegistry : public godot::RefCounted {
    GDCLASS(VoxelTypeRegistry, godot::RefCounted)

private:
    static VoxelTypeRegistry* singleton;
    std::unordered_map<VoxelTypeID, BlockProperties> properties;

    void initialize_default_blocks();

protected:
    static void _bind_methods();

public:
    VoxelTypeRegistry();
    ~VoxelTypeRegistry();

    static VoxelTypeRegistry* get_singleton();

    void register_block(VoxelTypeID type_id, const BlockProperties& props);
    const BlockProperties& get_properties(VoxelTypeID type_id) const;

    bool is_transparent(VoxelTypeID type_id) const;
    bool is_solid(VoxelTypeID type_id) const;
    godot::Color get_color(VoxelTypeID type_id) const;
    float get_hardness(VoxelTypeID type_id) const;
    uint8_t get_light_emission(VoxelTypeID type_id) const;
    godot::String get_name(VoxelTypeID type_id) const;

    // Godot-exposed methods
    void _register_block(int type_id, godot::String name, godot::Color color, float hardness, bool transparent, bool solid);
    godot::Color _get_color(int type_id) const;
    bool _is_transparent(int type_id) const;
};

} // namespace voxel

#endif // VOXEL_TYPES_H
