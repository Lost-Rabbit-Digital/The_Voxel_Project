#include "voxel_types.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace voxel {

VoxelTypeRegistry* VoxelTypeRegistry::singleton = nullptr;

void VoxelTypeRegistry::_bind_methods() {
    ClassDB::bind_method(D_METHOD("register_block", "type_id", "name", "color", "hardness", "transparent", "solid"),
        &VoxelTypeRegistry::_register_block);
    ClassDB::bind_method(D_METHOD("get_color", "type_id"), &VoxelTypeRegistry::_get_color);
    ClassDB::bind_method(D_METHOD("is_transparent", "type_id"), &VoxelTypeRegistry::_is_transparent);
}

VoxelTypeRegistry::VoxelTypeRegistry() {
    singleton = this;
    initialize_default_blocks();
}

VoxelTypeRegistry::~VoxelTypeRegistry() {
    if (singleton == this) {
        singleton = nullptr;
    }
}

VoxelTypeRegistry* VoxelTypeRegistry::get_singleton() {
    return singleton;
}

void VoxelTypeRegistry::initialize_default_blocks() {
    // AIR
    register_block(AIR, BlockProperties("Air", Color(0, 0, 0, 0), 0.0f, true, false));

    // STONE
    register_block(STONE, BlockProperties("Stone", Color(0.5f, 0.5f, 0.5f), 1.5f, false, true));

    // DIRT
    register_block(DIRT, BlockProperties("Dirt", Color(0.55f, 0.35f, 0.2f), 0.5f, false, true));

    // GRASS
    register_block(GRASS, BlockProperties("Grass", Color(0.2f, 0.8f, 0.2f), 0.6f, false, true));

    // SAND
    register_block(SAND, BlockProperties("Sand", Color(0.9f, 0.85f, 0.6f), 0.5f, false, true));

    // WATER
    register_block(WATER, BlockProperties("Water", Color(0.2f, 0.4f, 0.9f, 0.6f), 100.0f, true, false));

    // GRAVEL
    register_block(GRAVEL, BlockProperties("Gravel", Color(0.6f, 0.6f, 0.65f), 0.6f, false, true));

    // WOOD
    register_block(WOOD, BlockProperties("Wood", Color(0.4f, 0.25f, 0.1f), 2.0f, false, true));

    // LEAVES
    register_block(LEAVES, BlockProperties("Leaves", Color(0.15f, 0.6f, 0.15f), 0.2f, true, true));

    // COAL_ORE
    register_block(COAL_ORE, BlockProperties("Coal Ore", Color(0.2f, 0.2f, 0.2f), 3.0f, false, true));

    // IRON_ORE
    register_block(IRON_ORE, BlockProperties("Iron Ore", Color(0.7f, 0.6f, 0.5f), 3.0f, false, true));

    // GOLD_ORE
    register_block(GOLD_ORE, BlockProperties("Gold Ore", Color(0.9f, 0.8f, 0.2f), 3.0f, false, true));

    // DIAMOND_ORE
    register_block(DIAMOND_ORE, BlockProperties("Diamond Ore", Color(0.3f, 0.8f, 0.9f), 3.0f, false, true));

    // BEDROCK
    register_block(BEDROCK, BlockProperties("Bedrock", Color(0.1f, 0.1f, 0.1f), -1.0f, false, true));

    // TORCH
    register_block(TORCH, BlockProperties("Torch", Color(1.0f, 0.9f, 0.5f), 0.0f, true, false, 14));

    // GLASS
    register_block(GLASS, BlockProperties("Glass", Color(0.8f, 0.9f, 1.0f, 0.3f), 0.3f, true, true));
}

void VoxelTypeRegistry::register_block(VoxelTypeID type_id, const BlockProperties& props) {
    properties[type_id] = props;
}

const BlockProperties& VoxelTypeRegistry::get_properties(VoxelTypeID type_id) const {
    auto it = properties.find(type_id);
    if (it != properties.end()) {
        return it->second;
    }
    static BlockProperties default_props;
    return default_props;
}

bool VoxelTypeRegistry::is_transparent(VoxelTypeID type_id) const {
    return get_properties(type_id).is_transparent;
}

bool VoxelTypeRegistry::is_solid(VoxelTypeID type_id) const {
    return get_properties(type_id).is_solid;
}

Color VoxelTypeRegistry::get_color(VoxelTypeID type_id) const {
    return get_properties(type_id).color;
}

float VoxelTypeRegistry::get_hardness(VoxelTypeID type_id) const {
    return get_properties(type_id).hardness;
}

uint8_t VoxelTypeRegistry::get_light_emission(VoxelTypeID type_id) const {
    return get_properties(type_id).light_emission;
}

String VoxelTypeRegistry::get_name(VoxelTypeID type_id) const {
    return String(get_properties(type_id).name.c_str());
}

// Godot-exposed methods
void VoxelTypeRegistry::_register_block(int type_id, String name, Color color, float hardness, bool transparent, bool solid) {
    if (type_id >= 0 && type_id < MAX_BLOCK_TYPES) {
        register_block(static_cast<VoxelTypeID>(type_id),
            BlockProperties(name.utf8().get_data(), color, hardness, transparent, solid));
    }
}

Color VoxelTypeRegistry::_get_color(int type_id) const {
    if (type_id >= 0 && type_id < MAX_BLOCK_TYPES) {
        return get_color(static_cast<VoxelTypeID>(type_id));
    }
    return Color(1, 0, 1); // Magenta for invalid
}

bool VoxelTypeRegistry::_is_transparent(int type_id) const {
    if (type_id >= 0 && type_id < MAX_BLOCK_TYPES) {
        return is_transparent(static_cast<VoxelTypeID>(type_id));
    }
    return false;
}

} // namespace voxel
