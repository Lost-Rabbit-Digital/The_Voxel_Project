# Steel and Cube - Project Tasks (Voxel Engine Rebuild)

> **Project Vision:** A multiplayer voxel RPG that fuses Minecraft's sandbox building, Daggerfall's deep RPG mechanics, and Stardew Valley's farming & ranching. Explore an infinite living world with dynamic seasons, weather, scattered dungeons, villages, and farms. Build together, farm together, adventure together.
>
> **Engine:** Godot 4.5 | **Platform:** Steam (Early Access → Full Release) | **Multiplayer:** Terraria-style (Host or Join, Multiple Characters/Worlds)
>
> **STATUS:** 🚧 **COMPLETE VOXEL ENGINE REBUILD IN PROGRESS** 🚧
>
> **See:** `VOXEL_ENGINE_PLAN.md` for detailed architecture and implementation plan

**Legend:**
- ✅ Complete
- 🚧 In Progress
- ⏳ Planned
- 🔄 Needs Refactoring
- 🐛 Bug/Issue
- 🔥 Critical Priority
- 💎 High Value Feature

---

## 🎯 Current Sprint: Voxel Engine Rebuild

**Goal:** Build a high-performance, multiplayer-ready voxel engine from scratch using modern best practices

**Reference:** See `VOXEL_ENGINE_PLAN.md` for complete technical architecture

---

## Phase 1: Core Voxel Engine (Foundation) - REBUILD

### 1.1 Core Data Structures
- [ ] 🔥 Create `VoxelData` class with `PackedByteArray` storage
- [ ] 🔥 Implement efficient voxel get/set with index formula
- [ ] 🔥 Create `VoxelTypes` enum and block registry
- [ ] 🔥 Create `Chunk` class with pooling support
- [ ] ⏳ Create `ChunkCoordinate` utility class for position handling
- [ ] ⏳ Unit tests for voxel data storage

**Goal:** Efficient, memory-optimized voxel storage (4KB per 16x16x16 chunk)

---

### 1.2 ChunkManager (Spatial Organization)
- [ ] 🔥 Create `ChunkManager` class
- [ ] 🔥 Implement chunk pooling system (reuse objects, avoid GC)
- [ ] 🔥 Distance-based chunk loading/unloading
- [ ] 🔥 Priority queue for chunk loading (closer chunks first)
- [ ] ⏳ Chunk neighbor caching for fast cross-chunk queries
- [ ] ⏳ Configurable render distance
- [ ] ⏳ Chunk boundary visualization (debug mode)

**Goal:** Smooth chunk streaming with minimal performance impact

---

### 1.3 Basic Meshing System (Naive First)
- [ ] 🔥 Create `ChunkMeshBuilder` class
- [ ] 🔥 Implement basic face culling (no greedy meshing yet)
- [ ] 🔥 Proper cross-chunk face culling
- [ ] 🔥 Generate vertex normals
- [ ] 🔥 Generate UV coordinates (prepare for texture atlas)
- [ ] ⏳ Debug visualization modes (wireframe, face normals, chunk boundaries)
- [ ] ⏳ Mesh validation and error checking

**Goal:** Working terrain rendering with correct face culling

**Note:** We'll implement greedy meshing in Phase 2 after basic system works

---

### 1.4 TerrainGenerator (Simple First Pass)
- [ ] 🔥 Create `TerrainGenerator` class
- [ ] 🔥 Multi-layer noise system (continent, terrain, detail)
- [ ] 🔥 Height-based block type selection (grass, dirt, stone)
- [ ] ⏳ Configurable world seed
- [ ] ⏳ Noise parameter tuning for interesting terrain
- [ ] ⏳ Height caching for performance

**Goal:** Generate interesting, varied terrain quickly

---

### 1.5 VoxelWorld (Main Controller)
- [ ] 🔥 Create `VoxelWorld` main node
- [ ] 🔥 Integrate ChunkManager, MeshBuilder, TerrainGenerator
- [ ] 🔥 Player position tracking for chunk loading
- [ ] 🔥 Basic camera controller for testing
- [ ] ⏳ Configuration export variables
- [ ] ⏳ Performance monitoring (FPS, chunk count, memory)

**Goal:** Integrated system that generates and renders terrain

---

### 1.6 Basic Collision System
- [ ] ⏳ Generate collision meshes for chunks
- [ ] ⏳ Use `ConcavePolygonShape3D` for terrain collision
- [ ] ⏳ Collision shape optimization (simplified vs precise)
- [ ] ⏳ Player can walk on terrain
- [ ] ⏳ Basic physics response

**Goal:** Walkable, physical terrain

---

### 🎯 Milestone 1: Walkable Terrain
**Success Criteria:**
- ✅ Can walk on generated voxel terrain
- ✅ Chunks load/unload smoothly based on player position
- ✅ 60 FPS at render distance 8
- ✅ No face rendering bugs
- ✅ Memory usage <100MB for active chunks

---

## Phase 2: Greedy Meshing & Optimization

### 2.1 Greedy Meshing Algorithm
- [ ] 💎 Research greedy meshing algorithm (0fps.net, Voxel-Core)
- [ ] 💎 Implement greedy meshing for Y-axis (top/bottom faces)
- [ ] 💎 Implement greedy meshing for X-axis (east/west faces)
- [ ] 💎 Implement greedy meshing for Z-axis (north/south faces)
- [ ] 💎 Generate optimized quad meshes
- [ ] ⏳ Performance comparison: naive vs greedy (target: 50-90% reduction)
- [ ] ⏳ Unit tests for greedy meshing correctness

**Goal:** Massively reduce triangle count (1200 → 200-400 per chunk)

---

### 2.2 Texture Atlas System
- [ ] 💎 Create 256x256 texture atlas (16x16 textures, Minecraft Beta style)
- [ ] 💎 Implement UV coordinate generation for atlas
- [ ] 💎 Create `TextureAtlas` resource class
- [ ] 💎 Block face → texture mapping system
- [ ] ⏳ Support different textures per face (grass: top/side/bottom)
- [ ] ⏳ Create default block textures (grass, dirt, stone, wood, etc.)
- [ ] ⏳ Animated texture support (water, lava)

**Goal:** Beautiful textured terrain with single material (minimize draw calls)

---

### 2.3 Material System
- [ ] 💎 Create single `StandardMaterial3D` with atlas texture
- [ ] 💎 Configure material properties (roughness, metallic, etc.)
- [ ] ⏳ Support for transparent blocks (glass, water)
- [ ] ⏳ Material variants for different biomes
- [ ] ⏳ Resource pack system (load custom atlases)

**Goal:** Efficient rendering with minimal material switches

---

### 2.4 Advanced Cross-Chunk Culling
- [ ] 💎 Improve neighbor chunk queries
- [ ] 💎 Handle chunk loading/unloading edge cases
- [ ] ⏳ Chunk modification triggers neighbor remesh
- [ ] ⏳ Optimize queries with chunk boundary flags

**Goal:** Perfect face culling across all chunk boundaries

---

### 🎯 Milestone 2: Optimized Rendering
**Success Criteria:**
- ✅ Greedy meshing working (50%+ triangle reduction)
- ✅ Textured terrain with atlas system
- ✅ No visual artifacts at chunk boundaries
- ✅ 60 FPS at render distance 12
- ✅ Single material for all terrain (minimal draw calls)

---

## Phase 3: Threading & Performance

### 3.1 Worker Thread System
- [ ] 💎 Create `ChunkWorkerThread` class
- [ ] 💎 Implement thread pool (4 worker threads)
- [ ] 💎 Work queue with mutex protection
- [ ] 💎 Thread-safe chunk data generation
- [ ] ⏳ Thread-safe mesh generation
- [ ] ⏳ Result callback system
- [ ] ⏳ Thread shutdown and cleanup

**Goal:** Keep main thread responsive (60 FPS always)

---

### 3.2 Async Chunk Generation
- [ ] 💎 Move terrain generation to worker threads
- [ ] 💎 Queue system for chunk gen requests
- [ ] 💎 Priority system (closer chunks first)
- [ ] ⏳ Thread pool management
- [ ] ⏳ Error handling for failed generation

**Goal:** Zero stuttering during chunk loading

---

### 3.3 Async Mesh Building
- [ ] 💎 Move mesh building to worker threads
- [ ] 💎 Use `call_deferred()` for adding meshes to scene
- [ ] ⏳ Mesh instance pooling
- [ ] ⏳ Batch mesh updates

**Goal:** Smooth meshing without frame drops

---

### 3.4 Memory Management
- [ ] 💎 Implement chunk data pooling (reuse allocations)
- [ ] 💎 Implement mesh pooling
- [ ] ⏳ Memory profiling and leak detection
- [ ] ⏳ Configurable memory limits
- [ ] ⏳ Automatic chunk unloading when memory constrained

**Goal:** Minimal garbage collection, stable memory usage

---

### 🎯 Milestone 3: Threaded Performance
**Success Criteria:**
- ✅ Chunk gen/meshing happens off main thread
- ✅ Consistent 60 FPS even during heavy chunk loading
- ✅ Memory usage stable (no leaks)
- ✅ Can handle render distance 16
- ✅ <50MB GC pressure per minute

---

## Phase 4: World Generation Features

### 4.1 Biome System
- [ ] 💎 Temperature noise map
- [ ] 💎 Moisture noise map
- [ ] 💎 Biome selection algorithm
- [ ] ⏳ Plains biome (grass, flowers)
- [ ] ⏳ Forest biome (trees, bushes)
- [ ] ⏳ Desert biome (sand, cacti)
- [ ] ⏳ Mountain biome (stone, snow peaks)
- [ ] ⏳ Biome blending at borders
- [ ] ⏳ Biome-specific block palettes

**Goal:** Diverse, interesting world regions

---

### 4.2 Cave Generation
- [ ] 💎 3D Perlin worm caves
- [ ] ⏳ Cave system connectivity
- [ ] ⏳ Cave entrance placement
- [ ] ⏳ Underground lakes
- [ ] ⏳ Stalactites and stalagmites

**Goal:** Explorable underground cave networks

---

### 4.3 Ore & Resource Generation
- [ ] 💎 Ore vein generation (iron, gold, coal, etc.)
- [ ] ⏳ Vein size and rarity configuration
- [ ] ⏳ Height-based ore distribution
- [ ] ⏳ Cluster generation for common ores

**Goal:** Incentivize mining and exploration

---

### 4.4 Vegetation & Structures
- [ ] 💎 Tree generation (multiple types: oak, pine, birch)
- [ ] ⏳ Grass and flower placement
- [ ] ⏳ Boulder placement
- [ ] ⏳ Ensure structures don't break chunk borders

**Goal:** Living, organic-feeling world

---

### 4.5 Water & Liquid System
- [ ] ⏳ Water block type
- [ ] ⏳ Lava block type
- [ ] ⏳ Transparent rendering for water
- [ ] ⏳ Water surface detection
- [ ] ⏳ Simple fluid simulation (Phase 2 feature)

**Goal:** Lakes, rivers, oceans

---

### 🎯 Milestone 4: Rich World Generation
**Success Criteria:**
- ✅ Multiple distinct biomes
- ✅ Underground caves
- ✅ Ores scattered throughout
- ✅ Trees and vegetation
- ✅ Water bodies
- ✅ Interesting, explorable world

---

## Phase 5: Block Interaction System

### 5.1 Voxel Raycasting
- [ ] 💎 Implement DDA raycasting algorithm
- [ ] 💎 Ray-voxel intersection detection
- [ ] 💎 Return hit block position and face
- [ ] ⏳ Configurable max ray distance
- [ ] ⏳ Highlight targeted block (visual feedback)

**Goal:** Accurate block targeting for interaction

---

### 5.2 Block Breaking
- [ ] 💎 Remove voxel at raycast hit position
- [ ] 💎 Trigger chunk remesh on block change
- [ ] 💎 Block break animation/particles
- [ ] ⏳ Block hardness property
- [ ] ⏳ Tool effectiveness (pickaxe for stone, etc.)
- [ ] ⏳ Mining skill affects break speed
- [ ] ⏳ Drop item on break

**Goal:** Satisfying block destruction

---

### 5.3 Block Placement
- [ ] 💎 Place voxel adjacent to raycast hit face
- [ ] 💎 Trigger chunk remesh on placement
- [ ] 💎 Collision check (can't place in player)
- [ ] ⏳ Block rotation for directional blocks
- [ ] ⏳ Placement validation rules
- [ ] ⏳ Building skill affects placement speed

**Goal:** Satisfying block building

---

### 5.4 Inventory Integration
- [ ] ⏳ Blocks added to inventory on break
- [ ] ⏳ Blocks consumed from inventory on place
- [ ] ⏳ Hotbar for quick block selection
- [ ] ⏳ Creative mode (infinite blocks)
- [ ] ⏳ Survival mode (limited blocks)

**Goal:** Complete build/destroy gameplay loop

---

### 🎯 Milestone 5: Minecraft-Style Building
**Success Criteria:**
- ✅ Can break blocks
- ✅ Can place blocks
- ✅ Chunks remesh instantly on change
- ✅ Inventory integration works
- ✅ Feels responsive and satisfying

---

## Phase 6: Save & Load System

### 6.1 Chunk Serialization
- [ ] 💎 Serialize chunk voxel data to bytes
- [ ] 💎 Compress chunk data (GZip or similar)
- [ ] ⏳ Delta encoding for mostly-air chunks
- [ ] ⏳ Chunk metadata (modified flag, timestamp)

**Goal:** Efficient chunk storage format

---

### 6.2 World Save System
- [ ] 💎 Region file format (group chunks into regions)
- [ ] 💎 Save modified chunks to disk
- [ ] 💎 World metadata (seed, time, player pos)
- [ ] ⏳ Incremental saves (auto-save every N minutes)
- [ ] ⏳ Save on exit

**Goal:** Persistent world state

---

### 6.3 World Load System
- [ ] 💎 Load chunks from disk on demand
- [ ] 💎 Fall back to generation if chunk not saved
- [ ] 💎 Load world metadata
- [ ] ⏳ Background loading (threaded)
- [ ] ⏳ Load progress UI

**Goal:** Resume from saved worlds

---

### 6.4 Multiple World Support
- [ ] ⏳ World selection screen
- [ ] ⏳ Create new world
- [ ] ⏳ Delete world
- [ ] ⏳ World preview/metadata display

**Goal:** Manage multiple save files

---

### 🎯 Milestone 6: Persistent Worlds
**Success Criteria:**
- ✅ Modified chunks save to disk
- ✅ World loads from disk on restart
- ✅ Seed-based generation consistent
- ✅ Multiple worlds supported
- ✅ Compression keeps file sizes small

---

## Phase 7: Multiplayer Foundation

### 7.1 Network Architecture
- [ ] 💎 Client-server architecture (Godot ENet)
- [ ] 💎 Server-authoritative voxel modifications
- [ ] 💎 Client prediction for block changes
- [ ] ⏳ Host & Play mode (peer acts as server)
- [ ] ⏳ Dedicated server option
- [ ] ⏳ LAN discovery

**Goal:** Solid multiplayer foundation

---

### 7.2 Chunk Synchronization
- [ ] 💎 Server sends chunk data to clients
- [ ] 💎 Compress chunk data for network transfer
- [ ] 💎 Stream chunks on player join
- [ ] ⏳ Delta updates (only send changes)
- [ ] ⏳ Chunk request prioritization

**Goal:** Smooth chunk streaming to clients

---

### 7.3 Block Modification Sync
- [ ] 💎 Client sends block change request to server
- [ ] 💎 Server validates and applies change
- [ ] 💎 Server broadcasts change to all clients
- [ ] ⏳ Client-side prediction with rollback
- [ ] ⏳ Conflict resolution

**Goal:** Synchronized building/mining

---

### 7.4 Player Synchronization
- [ ] 💎 Player position/rotation sync
- [ ] 💎 Player animation sync
- [ ] ⏳ Interpolation for smooth movement
- [ ] ⏳ Lag compensation
- [ ] ⏳ Player name tags

**Goal:** See other players in world

---

### 7.5 Server Administration
- [ ] ⏳ Server config file
- [ ] ⏳ Whitelist/blacklist
- [ ] ⏳ Operator permissions
- [ ] ⏳ Kick/ban commands
- [ ] ⏳ Server logging

**Goal:** Manageable multiplayer servers

---

### 🎯 Milestone 7: Multiplayer Works
**Success Criteria:**
- ✅ 2-4 players can join same world
- ✅ Chunks stream to clients
- ✅ Block changes sync across clients
- ✅ Players see each other
- ✅ Stable, no desyncs
- ✅ <100ms latency feels good

---

## Phase 8: Lighting System

### 8.1 Sunlight Propagation
- [ ] ⏳ Top-down sunlight flood fill
- [ ] ⏳ Sunlight attenuation through transparent blocks
- [ ] ⏳ Cave darkness
- [ ] ⏳ Store light values per voxel

**Goal:** Natural outdoor lighting

---

### 8.2 Block Light Sources
- [ ] ⏳ Light-emitting blocks (torch, lava, glowstone)
- [ ] ⏳ Light propagation algorithm (BFS/flood fill)
- [ ] ⏳ Colored lighting support
- [ ] ⏳ Light values affect rendering

**Goal:** Torches and dynamic lighting

---

### 8.3 Smooth Lighting
- [ ] ⏳ Ambient occlusion (AO) calculation
- [ ] ⏳ Vertex lighting (interpolate between voxels)
- [ ] ⏳ Smooth transitions between light levels

**Goal:** Beautiful, smooth lighting

---

### 8.4 Day/Night Cycle Integration
- [ ] ⏳ Sunlight intensity varies by time of day
- [ ] ⏳ Re-light chunks when time changes
- [ ] ⏳ Moon provides dim light at night

**Goal:** Dynamic lighting from day/night cycle

---

### 🎯 Milestone 8: Advanced Lighting
**Success Criteria:**
- ✅ Sunlight propagates naturally
- ✅ Torches provide light
- ✅ Smooth, beautiful lighting
- ✅ Caves are dark (need torches)
- ✅ Day/night affects world lighting

---

## Phase 9: LOD & Advanced Optimization

### 9.1 Level of Detail (LOD)
- [ ] ⏳ Generate lower-poly meshes for distant chunks
- [ ] ⏳ LOD switching based on distance
- [ ] ⏳ Smooth LOD transitions (avoid popping)
- [ ] ⏳ Configurable LOD levels

**Goal:** Render distance 32+ without FPS drop

---

### 9.2 Occlusion Culling
- [ ] ⏳ Detect fully-occluded chunks (surrounded by solid chunks)
- [ ] ⏳ Skip rendering occluded chunks
- [ ] ⏳ Dynamic occlusion based on camera

**Goal:** Don't render what player can't see

---

### 9.3 Mesh Streaming
- [ ] ⏳ Progressive mesh loading (low detail → high detail)
- [ ] ⏳ Async mesh uploads to GPU
- [ ] ⏳ Mesh caching

**Goal:** Instant chunk appearance, detail loads in

---

### 🎯 Milestone 9: Maximum Performance
**Success Criteria:**
- ✅ Render distance 32 at 60 FPS
- ✅ LOD system working smoothly
- ✅ Occlusion culling saves GPU time
- ✅ Can handle massive worlds

---

## Phase 10: Polish & Quality of Life

### 10.1 Visual Polish
- [ ] ⏳ Block break animations
- [ ] ⏳ Block place animations
- [ ] ⏳ Particle effects (dust, sparks)
- [ ] ⏳ Water shader (transparency, reflections)
- [ ] ⏳ Grass/foliage waving animation

**Goal:** Visually appealing, polished look

---

### 10.2 Audio
- [ ] ⏳ Block break sounds (varies by type)
- [ ] ⏳ Block place sounds
- [ ] ⏳ Footstep sounds (varies by surface)
- [ ] ⏳ Ambient cave sounds

**Goal:** Audio feedback for actions

---

### 10.3 Debug Tools
- [ ] ⏳ Chunk boundary visualization
- [ ] ⏳ Performance overlay (FPS, chunk count, memory)
- [ ] ⏳ Wireframe mode
- [ ] ⏳ Lighting debug view
- [ ] ⏳ Console commands

**Goal:** Easy debugging and profiling

---

### 🎯 Milestone 10: Production Ready
**Success Criteria:**
- ✅ Visually polished
- ✅ Audio feedback
- ✅ Debug tools available
- ✅ No known bugs
- ✅ Ready for game integration

---

## Integration with Game Systems

### RPG Systems (After Voxel Engine Complete)
- [ ] ⏳ Block hardness → mining skill interaction
- [ ] ⏳ Tool effectiveness system
- [ ] ⏳ Block drops (stone → cobblestone + XP)
- [ ] ⏳ Mining skill progression

### Farming Systems
- [ ] ⏳ Tilled soil block type
- [ ] ⏳ Crop blocks (growth stages)
- [ ] ⏳ Irrigation detection (water nearby)
- [ ] ⏳ Season-based crop behavior

### Combat Systems
- [ ] ⏳ Voxel destruction from explosions
- [ ] ⏳ Line-of-sight raycasting through voxels
- [ ] ⏳ Cover detection (AI uses voxel data)

### Building Systems
- [ ] ⏳ Multiblock structures (doors, beds, chests)
- [ ] ⏳ Furniture blocks
- [ ] ⏳ Rotation for directional blocks
- [ ] ⏳ Building templates

---

## Known Issues & Risks

### Current Known Issues
- [ ] 🐛 None yet - fresh start!

### Technical Risks
- ⚠️ **Greedy meshing complexity** - Algorithm is complex, may take multiple attempts
- ⚠️ **Threading bugs** - Race conditions, deadlocks possible
- ⚠️ **Network synchronization** - Multiplayer is hard, expect challenges
- ⚠️ **Performance on low-end hardware** - May need additional optimization

### Mitigation Strategies
- ✅ Implement features incrementally (naive first, optimize later)
- ✅ Comprehensive testing at each milestone
- ✅ Reference proven implementations (Voxel-Core, godot_voxel)
- ✅ Profile early and often

---

## Performance Targets

### Minimum Specs (Target)
- **CPU:** Dual-core 2.5 GHz
- **RAM:** 4 GB
- **GPU:** Integrated graphics
- **Target:** 30 FPS at render distance 6

### Recommended Specs (Target)
- **CPU:** Quad-core 3.0 GHz
- **RAM:** 8 GB
- **GPU:** Dedicated (2GB VRAM)
- **Target:** 60 FPS at render distance 12

### High-End Specs (Target)
- **CPU:** 6+ cores 3.5 GHz
- **RAM:** 16 GB
- **GPU:** Modern (4GB+ VRAM)
- **Target:** 60 FPS at render distance 24+

---

## Resources & References

### Documentation
- `VOXEL_ENGINE_PLAN.md` - Detailed architecture plan
- `project_management/game_design_document.md` - Overall game design

### External References
- **Zylann/godot_voxel** - Professional C++ voxel module
- **ClarkThyLord/Voxel-Core** - GDScript voxel plugin with greedy meshing
- **0fps.net** - Greedy meshing article (classic reference)
- **Godot Docs** - Threading, networking, optimization guides

### Tools
- Godot Profiler (CPU, memory)
- RenderDoc (GPU profiling)
- Git (version control)

---

## Current Sprint Tasks (Next 1-2 Weeks)

### Week 1: Core Foundation
1. 🔥 Create VoxelData class (PackedByteArray storage)
2. 🔥 Create Chunk class with pooling
3. 🔥 Create VoxelTypes registry
4. 🔥 Create ChunkManager skeleton
5. 🔥 Create basic ChunkMeshBuilder (naive culling)
6. 🔥 Create TerrainGenerator (simple height-based)
7. 🔥 Create VoxelWorld main controller
8. 🔥 **Test:** Can generate and render basic terrain

### Week 2: Refinement
1. 🔥 Implement chunk pooling
2. 🔥 Implement cross-chunk face culling
3. 🔥 Add collision meshes
4. 🔥 Add texture atlas support (prepare UVs)
5. 🔥 Performance profiling and optimization
6. 🔥 **Test:** 60 FPS at render distance 8

### Success Criteria for Sprint
- ✅ Can walk on generated voxel terrain
- ✅ Chunks load/unload based on player position
- ✅ No face rendering bugs
- ✅ 60 FPS target hit
- ✅ Clean, documented code

---

## Notes & Lessons Learned

### Design Decisions
- **Chunk Size:** 16x16x16 (industry standard, good balance)
- **Storage:** PackedByteArray (minimal memory, fast access)
- **Meshing:** Naive first, greedy second (incremental complexity)
- **Threading:** Worker pool (avoid thread creation overhead)
- **Materials:** Single atlas (minimize draw calls)

### Best Practices
- ✅ Profile early and often
- ✅ Unit test core algorithms
- ✅ Document complex code
- ✅ Commit working code frequently
- ✅ Test on lower-end hardware

---

**Last Updated:** 2025-11-07
**Current Phase:** Phase 1 - Core Voxel Engine (Foundation)
**Next Milestone:** Walkable Terrain
**Status:** 🚀 Ready to start implementation!
