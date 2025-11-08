#include "chunk_mesh_builder.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

using namespace godot;

namespace voxel {

void ChunkMeshBuilder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("build_mesh", "chunk"), &ChunkMeshBuilder::_build_mesh);
}

ChunkMeshBuilder::ChunkMeshBuilder() : type_registry(nullptr), mask_size(0) {
    type_registry = VoxelTypeRegistry::get_singleton();

    // Pre-allocate mask for greedy meshing (maximum size)
    mask_size = SKY_CHUNK_HEIGHT * CHUNK_SIZE_XZ;
    mask.resize(mask_size, AIR);
}

ChunkMeshBuilder::~ChunkMeshBuilder() {
}

Ref<ArrayMesh> ChunkMeshBuilder::build_mesh(Chunk* chunk) {
    if (!chunk || !chunk->get_voxel_data()) {
        return Ref<ArrayMesh>();
    }

    // If chunk is uniform and empty, no mesh needed
    VoxelData* voxel_data = chunk->get_voxel_data();
    if (voxel_data->get_is_uniform() && voxel_data->get_uniform_value() == AIR) {
        return Ref<ArrayMesh>();
    }

    MeshData mesh_data;
    mesh_data.reserve(512); // Estimate

    // Build each face direction
    for (int face = 0; face < 6; face++) {
        build_face(chunk, static_cast<Face>(face), mesh_data);
    }

    // No geometry generated
    if (mesh_data.vertex_count() == 0) {
        return Ref<ArrayMesh>();
    }

    // Convert to Godot arrays
    Array arrays;
    arrays.resize(ArrayMesh::ARRAY_MAX);

    // Vertices
    PackedVector3Array vertices;
    vertices.resize(mesh_data.vertex_count());
    for (size_t i = 0; i < mesh_data.vertex_count(); i++) {
        vertices[i] = Vector3(
            mesh_data.vertices[i * 3],
            mesh_data.vertices[i * 3 + 1],
            mesh_data.vertices[i * 3 + 2]
        );
    }
    arrays[ArrayMesh::ARRAY_VERTEX] = vertices;

    // Normals
    PackedVector3Array normals;
    normals.resize(mesh_data.vertex_count());
    for (size_t i = 0; i < mesh_data.vertex_count(); i++) {
        normals[i] = Vector3(
            mesh_data.normals[i * 3],
            mesh_data.normals[i * 3 + 1],
            mesh_data.normals[i * 3 + 2]
        );
    }
    arrays[ArrayMesh::ARRAY_NORMAL] = normals;

    // UVs
    PackedVector2Array uvs;
    uvs.resize(mesh_data.vertex_count());
    for (size_t i = 0; i < mesh_data.vertex_count(); i++) {
        uvs[i] = Vector2(
            mesh_data.uvs[i * 2],
            mesh_data.uvs[i * 2 + 1]
        );
    }
    arrays[ArrayMesh::ARRAY_TEX_UV] = uvs;

    // Colors
    PackedColorArray colors;
    colors.resize(mesh_data.vertex_count());
    for (size_t i = 0; i < mesh_data.vertex_count(); i++) {
        colors[i] = Color(
            mesh_data.colors[i * 4],
            mesh_data.colors[i * 4 + 1],
            mesh_data.colors[i * 4 + 2],
            mesh_data.colors[i * 4 + 3]
        );
    }
    arrays[ArrayMesh::ARRAY_COLOR] = colors;

    // Indices
    PackedInt32Array indices;
    indices.resize(mesh_data.indices.size());
    for (size_t i = 0; i < mesh_data.indices.size(); i++) {
        indices[i] = mesh_data.indices[i];
    }
    arrays[ArrayMesh::ARRAY_INDEX] = indices;

    // Create mesh
    Ref<ArrayMesh> array_mesh;
    array_mesh.instantiate();
    array_mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays,
        Array(), Dictionary(), Mesh::ARRAY_FLAG_COMPRESS_ATTRIBUTES);

    return array_mesh;
}

Array ChunkMeshBuilder::build_mesh_arrays(Chunk* chunk) {
    Ref<ArrayMesh> mesh = build_mesh(chunk);
    if (mesh.is_null() || mesh->get_surface_count() == 0) {
        return Array();
    }
    return mesh->surface_get_arrays(0);
}

void ChunkMeshBuilder::build_face(Chunk* chunk, Face face, MeshData& mesh_data) {
    greedy_mesh_face(chunk, face, mesh_data, chunk->get_voxel_data()->get_chunk_size_y());
}

void ChunkMeshBuilder::greedy_mesh_face(
    Chunk* chunk,
    Face face,
    MeshData& mesh_data,
    int32_t chunk_size_y
) {
    VoxelData* voxel_data = chunk->get_voxel_data();

    // Determine sweep axes based on face direction
    int32_t u_axis, v_axis, w_axis;
    int32_t u_size, v_size;
    int32_t w_dir; // Direction to check neighbor

    switch (face) {
        case FACE_LEFT:
        case FACE_RIGHT:
            u_axis = 2; v_axis = 1; w_axis = 0; // Z, Y, X
            u_size = CHUNK_SIZE_XZ;
            v_size = chunk_size_y;
            w_dir = (face == FACE_RIGHT) ? 1 : -1;
            break;
        case FACE_DOWN:
        case FACE_UP:
            u_axis = 0; v_axis = 2; w_axis = 1; // X, Z, Y
            u_size = CHUNK_SIZE_XZ;
            v_size = CHUNK_SIZE_XZ;
            w_dir = (face == FACE_UP) ? 1 : -1;
            break;
        case FACE_BACK:
        case FACE_FRONT:
            u_axis = 0; v_axis = 1; w_axis = 2; // X, Y, Z
            u_size = CHUNK_SIZE_XZ;
            v_size = chunk_size_y;
            w_dir = (face == FACE_FRONT) ? 1 : -1;
            break;
        default:
            return;
    }

    // Clear mask
    int32_t current_mask_size = u_size * v_size;
    if (current_mask_size > mask_size) {
        mask.resize(current_mask_size);
        mask_size = current_mask_size;
    }

    // Sweep through each layer
    int32_t w_max = (w_axis == 0 || w_axis == 2) ? CHUNK_SIZE_XZ : chunk_size_y;
    for (int32_t w = 0; w < w_max; w++) {
        // Build mask for this layer
        std::fill(mask.begin(), mask.begin() + current_mask_size, AIR);

        for (int32_t v = 0; v < v_size; v++) {
            for (int32_t u = 0; u < u_size; u++) {
                // Convert u,v,w to x,y,z
                int32_t x, y, z;
                if (w_axis == 0) { x = w; y = v; z = u; }
                else if (w_axis == 1) { x = u; y = w; z = v; }
                else { x = u; y = v; z = w; }

                // Get neighbor position
                int32_t nx = x + (w_axis == 0 ? w_dir : 0);
                int32_t ny = y + (w_axis == 1 ? w_dir : 0);
                int32_t nz = z + (w_axis == 2 ? w_dir : 0);

                // Check if face should be rendered
                if (should_render_face(chunk, x, y, z, nx, ny, nz, face)) {
                    VoxelTypeID voxel = voxel_data->get_voxel(x, y, z);
                    mask[u + v * u_size] = voxel;
                }
            }
        }

        // Greedy meshing on the mask
        for (int32_t v = 0; v < v_size; v++) {
            for (int32_t u = 0; u < u_size; ) {
                VoxelTypeID voxel_type = mask[u + v * u_size];

                if (voxel_type == AIR) {
                    u++;
                    continue;
                }

                // Find width of quad
                int32_t width = 1;
                while (u + width < u_size && mask[u + width + v * u_size] == voxel_type) {
                    width++;
                }

                // Find height of quad
                int32_t height = 1;
                bool done = false;
                while (v + height < v_size && !done) {
                    for (int32_t k = 0; k < width; k++) {
                        if (mask[u + k + (v + height) * u_size] != voxel_type) {
                            done = true;
                            break;
                        }
                    }
                    if (!done) {
                        height++;
                    }
                }

                // Create quad
                Vector3 pos, size;
                if (w_axis == 0) {
                    float offset = (face == FACE_RIGHT) ? 1.0f : 0.0f;
                    pos = Vector3(w + offset, v, u);
                    size = Vector3(0, height, width);
                } else if (w_axis == 1) {
                    float offset = (face == FACE_UP) ? 1.0f : 0.0f;
                    pos = Vector3(u, w + offset, v);
                    size = Vector3(width, 0, height);
                } else {
                    float offset = (face == FACE_FRONT) ? 1.0f : 0.0f;
                    pos = Vector3(u, v, w + offset);
                    size = Vector3(width, height, 0);
                }

                Color color = type_registry ? type_registry->get_color(voxel_type) : Color(1, 0, 1);
                add_quad(mesh_data, pos, size, face, color);

                // Clear mask for processed area
                for (int32_t h = 0; h < height; h++) {
                    for (int32_t k = 0; k < width; k++) {
                        mask[u + k + (v + h) * u_size] = AIR;
                    }
                }

                u += width;
            }
        }
    }
}

bool ChunkMeshBuilder::should_render_face(
    Chunk* chunk,
    int32_t x, int32_t y, int32_t z,
    int32_t nx, int32_t ny, int32_t nz,
    Face face
) const {
    VoxelData* voxel_data = chunk->get_voxel_data();
    VoxelTypeID voxel = voxel_data->get_voxel(x, y, z);

    // Air doesn't render
    if (voxel == AIR) {
        return false;
    }

    // Check neighbor within chunk
    int32_t chunk_size_y = voxel_data->get_chunk_size_y();
    if (nx >= 0 && nx < CHUNK_SIZE_XZ &&
        ny >= 0 && ny < chunk_size_y &&
        nz >= 0 && nz < CHUNK_SIZE_XZ) {

        VoxelTypeID neighbor = voxel_data->get_voxel(nx, ny, nz);

        // Don't render if neighbor is solid and opaque
        if (neighbor != AIR && type_registry && !type_registry->is_transparent(neighbor)) {
            return false;
        }
    }
    // TODO: Cross-chunk face culling with neighbor chunks

    return true;
}

void ChunkMeshBuilder::add_quad(
    MeshData& mesh_data,
    const Vector3& pos,
    const Vector3& size,
    Face face,
    const Color& color
) {
    int32_t base_index = mesh_data.vertex_count();
    Vector3 normal = get_face_normal(face);

    // Define quad vertices based on face
    Vector3 v0, v1, v2, v3;

    switch (face) {
        case FACE_LEFT: // -X
            v0 = pos + Vector3(0, 0, 0);
            v1 = pos + Vector3(0, size.y, 0);
            v2 = pos + Vector3(0, size.y, size.z);
            v3 = pos + Vector3(0, 0, size.z);
            break;
        case FACE_RIGHT: // +X
            v0 = pos + Vector3(0, 0, 0);
            v1 = pos + Vector3(0, 0, size.z);
            v2 = pos + Vector3(0, size.y, size.z);
            v3 = pos + Vector3(0, size.y, 0);
            break;
        case FACE_DOWN: // -Y
            v0 = pos + Vector3(0, 0, 0);
            v1 = pos + Vector3(0, 0, size.z);
            v2 = pos + Vector3(size.x, 0, size.z);
            v3 = pos + Vector3(size.x, 0, 0);
            break;
        case FACE_UP: // +Y
            v0 = pos + Vector3(0, 0, 0);
            v1 = pos + Vector3(size.x, 0, 0);
            v2 = pos + Vector3(size.x, 0, size.z);
            v3 = pos + Vector3(0, 0, size.z);
            break;
        case FACE_BACK: // -Z
            v0 = pos + Vector3(0, 0, 0);
            v1 = pos + Vector3(size.x, 0, 0);
            v2 = pos + Vector3(size.x, size.y, 0);
            v3 = pos + Vector3(0, size.y, 0);
            break;
        case FACE_FRONT: // +Z
            v0 = pos + Vector3(0, 0, 0);
            v1 = pos + Vector3(0, size.y, 0);
            v2 = pos + Vector3(size.x, size.y, 0);
            v3 = pos + Vector3(size.x, 0, 0);
            break;
    }

    // Add vertices
    mesh_data.vertices.insert(mesh_data.vertices.end(), {v0.x, v0.y, v0.z});
    mesh_data.vertices.insert(mesh_data.vertices.end(), {v1.x, v1.y, v1.z});
    mesh_data.vertices.insert(mesh_data.vertices.end(), {v2.x, v2.y, v2.z});
    mesh_data.vertices.insert(mesh_data.vertices.end(), {v3.x, v3.y, v3.z});

    // Add normals
    for (int i = 0; i < 4; i++) {
        mesh_data.normals.insert(mesh_data.normals.end(), {normal.x, normal.y, normal.z});
    }

    // Add UVs
    mesh_data.uvs.insert(mesh_data.uvs.end(), {0, 0});
    mesh_data.uvs.insert(mesh_data.uvs.end(), {1, 0});
    mesh_data.uvs.insert(mesh_data.uvs.end(), {1, 1});
    mesh_data.uvs.insert(mesh_data.uvs.end(), {0, 1});

    // Add colors
    for (int i = 0; i < 4; i++) {
        mesh_data.colors.insert(mesh_data.colors.end(), {color.r, color.g, color.b, color.a});
    }

    // Add indices (two triangles)
    mesh_data.indices.insert(mesh_data.indices.end(), {
        base_index, base_index + 1, base_index + 2,
        base_index, base_index + 2, base_index + 3
    });
}

Vector3 ChunkMeshBuilder::get_face_normal(Face face) const {
    switch (face) {
        case FACE_LEFT: return Vector3(-1, 0, 0);
        case FACE_RIGHT: return Vector3(1, 0, 0);
        case FACE_DOWN: return Vector3(0, -1, 0);
        case FACE_UP: return Vector3(0, 1, 0);
        case FACE_BACK: return Vector3(0, 0, -1);
        case FACE_FRONT: return Vector3(0, 0, 1);
        default: return Vector3(0, 1, 0);
    }
}

Ref<ArrayMesh> ChunkMeshBuilder::_build_mesh(const Ref<Chunk>& chunk) {
    if (chunk.is_null()) {
        return Ref<ArrayMesh>();
    }
    return build_mesh(chunk.ptr());
}

} // namespace voxel
