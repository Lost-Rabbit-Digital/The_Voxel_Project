#include "register_types.h"

#include "core/voxel_types.h"
#include "core/voxel_data.h"
#include "core/chunk.h"
#include "systems/chunk_mesh_builder.h"
#include "systems/terrain_generator.h"
#include "util/thread_pool.h"
#include "voxel_world.h"

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;
using namespace voxel;

void initialize_voxel_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    // Register core classes
    ClassDB::register_class<VoxelTypeRegistry>();
    ClassDB::register_class<VoxelData>();
    ClassDB::register_class<Chunk>();

    // Register system classes
    ClassDB::register_class<ChunkMeshBuilder>();
    ClassDB::register_class<TerrainGenerator>();
    ClassDB::register_class<ThreadPool>();

    // Register main node
    ClassDB::register_class<VoxelWorld>();

    // Print initialization message
    print_line("Voxel Engine GDExtension initialized");
}

void uninitialize_voxel_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    print_line("Voxel Engine GDExtension uninitialized");
}

extern "C" {
    // Initialization
    GDExtensionBool GDE_EXPORT voxel_engine_library_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization
    ) {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

        init_obj.register_initializer(initialize_voxel_module);
        init_obj.register_terminator(uninitialize_voxel_module);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}
