# Voxel Engine Rebuild Plan
## Steel and Cube - Modern Voxel Engine Architecture

**Date:** 2025-11-07
**Goal:** Build a high-performance, multiplayer-ready voxel engine from scratch using modern Godot 4.5 best practices

---

## 🎯 Design Principles

1. **Performance First** - Optimize early, not later
2. **Multiplayer Ready** - All systems designed for networking from day one
3. **Modular Architecture** - Easy to extend and maintain
4. **Data-Oriented Design** - Minimize object creation, maximize data reuse
5. **Thread-Safe** - Chunk generation and meshing off main thread

---

## 📐 Core Architecture

### **System Overview**

```
VoxelWorld (Main Node)
├── ChunkManager (Spatial organization)
│   ├── ChunkPool (Object pooling)
│   ├── ChunkLoader (Async loading)
│   └── ChunkCache (Save/load to disk)
├── MeshingSystem (Mesh generation)
│   ├── GreedyMesher (Optimized meshing)
│   ├── MeshPool (Mesh reuse)
│   └── MaterialAtlas (Texture management)
├── TerrainGenerator (World generation)
│   ├── BiomeSystem (Multiple biomes)
│   ├── NoiseGenerator (Layered noise)
│   └── StructureGenerator (Trees, caves, ores)
└── PhysicsManager (Collision)
    ├── VoxelRaycaster (Block interaction)
    └── CollisionMeshGenerator (Precise collision)
```

---

## 🧱 Core Components

### **1. VoxelWorld** (Main Controller)
**Responsibility:** Orchestrates all voxel systems
- Manages player position tracking
- Triggers chunk loading/unloading
- Coordinates between systems
- Handles world save/load

```gdscript
class_name VoxelWorld extends Node3D

var chunk_manager: ChunkManager
var meshing_system: MeshingSystem
var terrain_generator: TerrainGenerator
var physics_manager: PhysicsManager

@export var render_distance: int = 8
@export var chunk_size: int = 16
@export var world_seed: int = 0
@export var enable_threading: bool = true
```

---

### **2. ChunkManager** (Spatial Organization)
**Responsibility:** Manages chunk lifecycle and spatial queries

**Key Features:**
- **Chunk Pooling**: Reuse chunk objects (avoid GC pressure)
- **Distance-Based Loading**: Load/unload based on player position
- **Priority Queue**: Load closer chunks first
- **Cross-Chunk Queries**: Check neighboring chunks for face culling

**Data Structure:**
```gdscript
class_name ChunkManager extends Node

# Active chunks in the world (Vector3i -> Chunk)
var active_chunks: Dictionary = {}

# Pool of inactive chunks ready for reuse
var chunk_pool: Array[Chunk] = []

# Chunks queued for loading (priority queue)
var load_queue: Array[ChunkLoadRequest] = []

# Chunk size (16x16x16 recommended)
const CHUNK_SIZE := 16
```

**Chunk Object:**
```gdscript
class_name Chunk extends RefCounted

var position: Vector3i  # Chunk coordinates (not world coordinates)
var voxel_data: PackedByteArray  # 16x16x16 = 4096 bytes (1 byte per voxel)
var mesh_instance: MeshInstance3D
var is_dirty: bool = false
var is_loaded: bool = false
var neighbor_refs: Dictionary = {}  # Cached references to neighbors
```

---

### **3. VoxelData Storage** (Efficient Data Layout)

**Memory Layout:**
- Use `PackedByteArray` for voxel storage (not Dictionary!)
- 1 byte per voxel = 256 possible block types
- 16x16x16 chunk = 4096 bytes per chunk
- Index formula: `index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE`

```gdscript
class_name VoxelData

var data: PackedByteArray

func _init():
    data.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
    data.fill(0)  # Air by default

func get_voxel(x: int, y: int, z: int) -> int:
    var index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
    return data[index]

func set_voxel(x: int, y: int, z: int, type: int) -> void:
    var index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
    data[index] = type
```

---

### **4. GreedyMesher** (Optimized Mesh Generation)

**Greedy Meshing Algorithm:**
1. For each axis (X, Y, Z)
2. For each slice perpendicular to that axis
3. Find rectangular regions of same voxel type
4. Combine into single quad
5. Result: 50-90% fewer triangles!

**Benefits:**
- Massively reduced triangle count
- Better GPU performance
- Faster rendering

**Implementation Approach:**
```gdscript
class_name GreedyMesher

# Process one axis at a time
func generate_mesh_for_axis(chunk: Chunk, axis: int) -> void:
    # For each slice perpendicular to axis
    for d in range(CHUNK_SIZE):
        # Create a 2D mask of the slice
        var mask = create_slice_mask(chunk, axis, d)

        # Greedily merge quads in the mask
        merge_quads_in_mask(mask)

        # Generate geometry for merged quads
        generate_quads(mask, axis, d)
```

**Reference Implementation:**
- Study Voxel-Core's greedy meshing code
- Study 0fps.net greedy meshing article (classic reference)

---

### **5. TerrainGenerator** (World Generation)

**Multi-Layer Noise System:**
```gdscript
class_name TerrainGenerator

var continent_noise: FastNoiseLite  # Large-scale (0.001 frequency)
var terrain_noise: FastNoiseLite    # Medium-scale (0.02 frequency)
var detail_noise: FastNoiseLite     # Small-scale (0.1 frequency)
var biome_noise: FastNoiseLite      # Biome selection

func generate_chunk(chunk_pos: Vector3i) -> VoxelData:
    var voxel_data = VoxelData.new()

    for x in CHUNK_SIZE:
        for z in CHUNK_SIZE:
            var world_x = chunk_pos.x * CHUNK_SIZE + x
            var world_z = chunk_pos.z * CHUNK_SIZE + z

            # Calculate height
            var height = calculate_terrain_height(world_x, world_z)

            # Fill voxels
            for y in CHUNK_SIZE:
                var world_y = chunk_pos.y * CHUNK_SIZE + y
                var voxel_type = get_voxel_type(world_x, world_y, world_z, height)
                voxel_data.set_voxel(x, y, z, voxel_type)

    return voxel_data
```

**Biome System:**
- Temperature map (noise)
- Moisture map (noise)
- Combine for biome selection
- Biomes affect: block types, height ranges, vegetation

---

### **6. Threading System** (Performance)

**Worker Thread Pool:**
```gdscript
class_name ChunkWorkerThread extends Thread

var work_queue: Array[ChunkWorkItem] = []
var work_mutex: Mutex
var work_semaphore: Semaphore
var should_exit: bool = false

func _thread_function():
    while not should_exit:
        work_semaphore.wait()

        work_mutex.lock()
        if work_queue.is_empty():
            work_mutex.unlock()
            continue
        var item = work_queue.pop_front()
        work_mutex.unlock()

        # Do the work
        match item.type:
            WorkType.GENERATE:
                item.result = generate_chunk_data(item.chunk_pos)
            WorkType.MESH:
                item.result = generate_chunk_mesh(item.chunk_data)

        # Signal completion
        item.completed.emit(item.result)
```

**Thread Safety Rules:**
1. **NEVER** access scene tree from worker threads
2. **NEVER** modify shared data without mutex
3. Use `call_deferred()` to add meshes to scene
4. Keep chunk data separate from scene objects

---

### **7. Material & Texture System**

**Single Texture Atlas (Minecraft Beta 1.7 Style):**
- 256x256 atlas (16x16 pixel textures)
- Support 16x16 = 256 unique textures
- Use UV coordinates for texture selection
- Single material for all chunks (reduce draw calls!)

```gdscript
class_name TextureAtlas

var atlas_texture: Texture2D
var atlas_size: int = 256
var tile_size: int = 16
var tiles_per_row: int = 16

func get_uv_for_block(block_type: int, face: int) -> Rect2:
    var tile_pos = get_tile_position(block_type, face)
    var uv_size = float(tile_size) / float(atlas_size)

    return Rect2(
        tile_pos.x * uv_size,
        tile_pos.y * uv_size,
        uv_size,
        uv_size
    )
```

---

### **8. Collision System**

**Precise Voxel Collision:**
- Generate collision mesh per chunk (optional optimization: simplified)
- Use `ConcavePolygonShape3D` for static terrain
- Raycasting for block interaction (place/break)

**Voxel Raycaster:**
```gdscript
class_name VoxelRaycaster

# DDA algorithm for voxel ray traversal
func raycast(from: Vector3, direction: Vector3, max_distance: float) -> RaycastResult:
    var current = from.floor()
    var step = direction.sign()

    # DDA stepping
    while current.distance_to(from) < max_distance:
        # Check voxel at current position
        var voxel = get_voxel_at_world_pos(current)
        if voxel != VoxelType.AIR:
            return RaycastResult.new(current, voxel)

        # Step to next voxel boundary
        current += calculate_next_step(current, direction, step)

    return null
```

---

## 🚀 Performance Targets

### **Minimum Viable Performance**
- 60 FPS at 8 chunk render distance (single player)
- Chunk generation: <16ms per chunk
- Chunk meshing: <8ms per chunk (greedy meshing)
- Memory: <100MB for active chunks

### **Optimizations to Implement**
1. ✅ Greedy meshing (50-90% triangle reduction)
2. ✅ Chunk pooling (eliminate GC)
3. ✅ Single material/texture atlas (reduce draw calls)
4. ✅ Threading (keep main thread responsive)
5. ✅ Frustum culling (automatic with Godot)
6. ⏳ LOD system (Phase 2 - distant chunks lower detail)
7. ⏳ Occlusion culling (Phase 2)

---

## 🎯 Modern Minecraft-Inspired Improvements (2025-11-08)

Based on analysis comparing our implementation to modern Minecraft (1.18+) and the Sodium mod, these three improvements offer the highest performance gains:

### **1. Region-Based Mesh Batching (Priority 1 - Highest Impact)**

**Problem:** Currently rendering 1 chunk = 1 draw call. With 100 visible chunks = 100 draw calls.

**Solution:** Combine multiple chunks into region batches (Sodium's approach).

**Implementation:**
- Group chunks into 8x8x8 regions (512 chunks per region)
- Combine meshes within same region into single ArrayMesh
- Dramatically reduce draw calls: 100 chunks = ~2-5 draw calls

**Expected Performance Gain:**
- 60-90% reduction in draw calls
- 20-40% FPS boost
- Better GPU batching efficiency

**Code Architecture:**
```gdscript
class_name ChunkRegion extends Node3D

const REGION_SIZE := 8  # 8x8x8 chunks per region

var region_position: Vector3i
var chunks_in_region: Array[Chunk] = []
var combined_mesh: ArrayMesh = null
var mesh_instance: MeshInstance3D = null
var is_dirty: bool = false

func rebuild_combined_mesh() -> void:
    # Combine all chunk meshes in this region
    # Uses ArrayMesh.add_surface_from_arrays()
    # All chunks share same material (texture atlas)
    pass
```

**Technical Details:**
- Rebuild region mesh when any child chunk changes
- Use same material for all chunks (texture atlas required)
- Region frustum culling (cull entire region at once)
- Smart invalidation (only rebuild dirty regions)

---

### **2. Occlusion Culling (Priority 2 - Medium-High Impact)**

**Problem:** Rendering chunks underground or behind terrain that can't be seen.

**Solution:** Implement graph-based occlusion culling similar to Sodium.

**Approaches:**

**Approach A: Simple Raycast Occlusion (Easier)**
- Raycast from camera to chunk center
- If ray hits another chunk first, skip rendering
- Fast but not perfect accuracy

**Approach B: Graph-Based Occlusion (Sodium's Method)**
- Build chunk visibility graph
- Flood-fill from camera position
- Mark reachable chunks as visible
- Only render visible chunks

**Expected Performance Gain:**
- 15-30% fewer chunks rendered (especially underground)
- Biggest gains in caves and dense terrain
- Minimal CPU overhead with smart caching

**Code Architecture:**
```gdscript
class_name OcclusionCuller

var visibility_graph: Dictionary = {}  # Vector3i -> Array[Vector3i]
var visible_chunks: Array[Vector3i] = []

func update_visibility(camera_chunk: Vector3i, all_chunks: Array[Vector3i]) -> void:
    visible_chunks.clear()

    # Flood-fill from camera position
    var open_set: Array[Vector3i] = [camera_chunk]
    var closed_set: Dictionary = {}

    while not open_set.is_empty():
        var current = open_set.pop_front()
        if current in closed_set:
            continue

        closed_set[current] = true
        visible_chunks.append(current)

        # Check neighbors for visibility openings
        for neighbor in get_neighbors(current):
            if can_see_through(current, neighbor):
                open_set.append(neighbor)

func can_see_through(from: Vector3i, to: Vector3i) -> bool:
    # Check if there's a visible path between chunks
    # Air chunks or chunks with exposed faces = true
    pass
```

**Implementation Steps:**
1. Build chunk connectivity graph (which chunks can "see" each other)
2. Implement flood-fill visibility algorithm
3. Cache visibility data (invalidate on chunk changes)
4. Integrate with rendering pipeline

---

### **3. Increased Chunk Height (Priority 3 - Architectural Improvement)**

**Problem:** 16x16x16 chunks are too small vertically. Minecraft uses full-height chunks (256-384 blocks).

**Current:** Many vertical chunks for tall worlds (16 blocks height each)
**Proposed:** Fewer, taller chunks (64-128 blocks height each)

**Benefits:**
- Fewer total chunks to manage
- Better vertical coherence (caves, mountains in same chunk)
- More similar to Minecraft's architecture
- Better cache locality for vertical structures

**Tradeoffs:**
- Larger memory per chunk (16x16x64 = 16,384 bytes vs 4,096)
- Slower meshing per chunk (but fewer total chunks)
- Can subdivide meshing into 16-block vertical sections

**Implementation:**
```gdscript
# Old approach:
const CHUNK_SIZE = 16  # All dimensions

# New approach:
const CHUNK_SIZE_XZ = 16  # Horizontal (X, Z)
const CHUNK_SIZE_Y = 64   # Vertical (Y) - or 128 for very tall worlds

# Chunk volume changes:
# Old: 16 * 16 * 16 = 4,096 voxels per chunk
# New: 16 * 16 * 64 = 16,384 voxels per chunk (4x larger)

# Total chunks for same world area:
# Old: More chunks vertically
# New: 1/4th as many chunks for same height
```

**Migration Strategy:**
- Add new constants CHUNK_SIZE_XZ and CHUNK_SIZE_Y
- Update all chunk indexing code
- Keep CHUNK_SIZE for backward compatibility (or deprecate)
- Test thoroughly before committing

**Performance Impact:**
- 25-40% fewer total chunks for typical world
- Reduced chunk management overhead
- Slightly longer per-chunk meshing (but parallelizable)

---

### **Implementation Priority Order**

**Week 1: Occlusion Culling**
- Implement simple raycast-based occlusion
- Measure performance gains
- Iterate to graph-based if needed

**Week 2: Chunk Height Increase**
- Refactor chunk dimensions
- Test and validate
- Update save/load system

**Week 3: Region-Based Batching**
- Implement ChunkRegion system
- Combine mesh generation
- Test draw call reduction

**Expected Overall Impact:**
- **FPS Gain:** +40-60% in typical scenes
- **Draw Calls:** 90% reduction (100 → 5-15)
- **Chunks Rendered:** 30-40% reduction (occlusion culling)
- **Memory Efficiency:** Better with taller chunks

---

## 📊 Comparison: Old vs New

| Feature | Old Implementation | New Implementation |
|---------|-------------------|-------------------|
| **Chunk Storage** | Dictionary | PackedByteArray |
| **Meshing** | Naive culling | Greedy meshing |
| **Threading** | Limited | Full worker pool |
| **Memory** | High GC pressure | Object pooling |
| **Triangles** | ~1200 per chunk | ~200-400 per chunk |
| **Cross-chunk culling** | Basic | Proper neighbor checking |
| **Collision** | Simple box | Precise voxel mesh |
| **Materials** | Multiple | Single atlas |

---

## 🗺️ Implementation Phases

### **Phase 1: Core Engine (Week 1-2)**
1. VoxelData storage (PackedByteArray)
2. ChunkManager with pooling
3. Basic meshing (naive, no greedy yet)
4. TerrainGenerator (simple height-based)
5. Basic collision

**Milestone:** Walking on generated terrain

---

### **Phase 2: Greedy Meshing (Week 2-3)**
1. Implement greedy meshing algorithm
2. Cross-chunk face culling
3. Texture atlas integration
4. Material system

**Milestone:** Optimized rendering, textured blocks

---

### **Phase 3: Threading (Week 3-4)**
1. Worker thread pool
2. Async chunk generation
3. Async chunk meshing
4. Main thread coordination

**Milestone:** Smooth FPS, responsive controls

---

### **Phase 4: World Features (Week 4-6)**
1. Multiple biomes
2. Cave generation
3. Ore veins
4. Tree placement
5. Water/lava

**Milestone:** Interesting, varied world

---

### **Phase 5: Block Interaction (Week 6-7)**
1. Voxel raycasting
2. Block breaking
3. Block placement
4. Inventory system
5. Chunk modification & remeshing

**Milestone:** Minecraft-style building

---

### **Phase 6: Save/Load (Week 7-8)**
1. Chunk serialization
2. Region file format
3. World metadata
4. Efficient compression

**Milestone:** Persistent worlds

---

### **Phase 7: Multiplayer Foundation (Week 8-10)**
1. Network chunk synchronization
2. Block modification sync
3. Player synchronization
4. Authority model (server authoritative)

**Milestone:** 2-4 player co-op works

---

## 🔧 Development Tools & Resources

### **Reference Implementations**
- **Voxel-Core** (GitHub: ClarkThyLord/Voxel-Core) - GDScript, greedy meshing
- **godot_voxel** (GitHub: Zylann/godot_voxel) - C++, professional quality
- **0fps.net** - Greedy meshing article (classic reference)

### **Godot Features to Use**
- `PackedByteArray` - efficient voxel storage
- `SurfaceTool` or `ArrayMesh` - mesh building
- `Thread` and `Mutex` - threading
- `FastNoiseLite` - noise generation
- `ResourceSaver/Loader` - chunk save/load

### **Testing Approach**
1. Unit tests for core algorithms (meshing, storage)
2. Performance benchmarks (chunk gen, meshing speed)
3. Visual debugging (chunk boundaries, normals)
4. Memory profiling (leak detection)

---

## 🎮 Integration with Game Systems

### **RPG Systems**
- Block types have properties (hardness, required tool)
- Mining skill affects mining speed
- Blocks drop resources (stone -> cobblestone)
- Tools have durability

### **Combat Systems**
- Terrain destruction from explosions
- Line-of-sight through voxel raycasting
- Cover system (AI uses voxel data)

### **Farming Systems**
- Tilled soil voxel type
- Crop growth on specific blocks
- Irrigation simulation

---

## 📝 Next Steps

1. ✅ Review current implementation
2. ✅ Research best practices
3. ✅ Create rebuild plan (this document)
4. ⏳ Reset project_tasks.md
5. ⏳ Create new voxel engine skeleton
6. ⏳ Implement Phase 1 (Core Engine)

---

## 🤝 Collaboration Notes

**Code Style:**
- Use typed GDScript (`var x: int` not `var x`)
- Class names in PascalCase
- Functions in snake_case
- Constants in UPPER_SNAKE_CASE
- Comprehensive comments for complex algorithms

**Git Workflow:**
- Feature branches for major systems
- Commit after each working subsystem
- Detailed commit messages
- Don't commit broken code

**Documentation:**
- Update this plan as we learn
- Document performance metrics
- Track optimization wins/losses

---

**End of Voxel Engine Plan**
**Ready to build something amazing! 🚀**
