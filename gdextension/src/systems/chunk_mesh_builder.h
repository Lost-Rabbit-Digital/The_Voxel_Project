#ifndef CHUNK_MESH_BUILDER_H
#define CHUNK_MESH_BUILDER_H

#include "../core/chunk.h"
#include "../core/voxel_types.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <vector>

namespace voxel {

// Face directions for greedy meshing
enum Face {
    FACE_LEFT = 0,   // -X
    FACE_RIGHT = 1,  // +X
    FACE_DOWN = 2,   // -Y
    FACE_UP = 3,     // +Y
    FACE_BACK = 4,   // -Z
    FACE_FRONT = 5   // +Z
};

// Mesh data structure for building
struct MeshData {
    std::vector<float> vertices;    // Packed as Vector3
    std::vector<float> normals;     // Packed as Vector3
    std::vector<float> uvs;         // Packed as Vector2
    std::vector<float> colors;      // Packed as Color (RGBA)
    std::vector<int32_t> indices;

    void clear() {
        vertices.clear();
        normals.clear();
        uvs.clear();
        colors.clear();
        indices.clear();
    }

    size_t vertex_count() const {
        return vertices.size() / 3;
    }

    void reserve(size_t estimated_quads) {
        vertices.reserve(estimated_quads * 12);  // 4 vertices * 3 components
        normals.reserve(estimated_quads * 12);
        uvs.reserve(estimated_quads * 8);        // 4 vertices * 2 components
        colors.reserve(estimated_quads * 16);    // 4 vertices * 4 components
        indices.reserve(estimated_quads * 6);    // 2 triangles * 3 indices
    }
};

class ChunkMeshBuilder : public godot::RefCounted {
    GDCLASS(ChunkMeshBuilder, godot::RefCounted)

private:
    VoxelTypeRegistry* type_registry;

    // Temporary mask for greedy meshing (reused)
    std::vector<VoxelTypeID> mask;
    int32_t mask_size;

    // Build mesh for a single face direction
    void build_face(Chunk* chunk, Face face, MeshData& mesh_data);

    // Greedy meshing algorithm
    void greedy_mesh_face(
        Chunk* chunk,
        Face face,
        MeshData& mesh_data,
        int32_t chunk_size_y
    );

    // Check if voxel face should be rendered
    bool should_render_face(
        Chunk* chunk,
        int32_t x, int32_t y, int32_t z,
        int32_t nx, int32_t ny, int32_t nz,
        Face face
    ) const;

    // Add quad to mesh
    void add_quad(
        MeshData& mesh_data,
        const godot::Vector3& pos,
        const godot::Vector3& size,
        Face face,
        const godot::Color& color
    );

    // Get face normal
    godot::Vector3 get_face_normal(Face face) const;

protected:
    static void _bind_methods();

public:
    ChunkMeshBuilder();
    ~ChunkMeshBuilder();

    // Build mesh for entire chunk
    godot::Ref<godot::ArrayMesh> build_mesh(Chunk* chunk);

    // Build mesh arrays (for region batching)
    godot::Array build_mesh_arrays(Chunk* chunk);

    // Godot-exposed methods
    godot::Ref<godot::ArrayMesh> _build_mesh(const godot::Ref<Chunk>& chunk);
};

} // namespace voxel

#endif // CHUNK_MESH_BUILDER_H
