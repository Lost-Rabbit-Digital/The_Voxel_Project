# Sodium MC Performance Research & Implementation Plan

## Research Summary

### What Makes Sodium Fast

Sodium is a Minecraft optimization mod that achieves **up to 300% FPS improvements** through several key techniques:

#### 1. **Modern OpenGL Rendering Pipeline** (~90% CPU overhead reduction)
- Uses **multi-draw indirect** rendering to batch draw calls
- Region-based rendering (8×4×8 chunk sections per region)
- Reduces draw calls dramatically by combining geometry

#### 2. **Vertex Data Compression** (~40% memory reduction)
- Compact vertex formats reduce VRAM usage
- Lower bandwidth requirements = faster rendering
- Optimized vertex attribute packing

#### 3. **Advanced Culling System**
- **Frustum culling**: Early rejection of off-screen geometry
- **Occlusion culling**: Hides geometry behind solid blocks
- **Face culling**: Removes faces between solid blocks (greedy meshing)
- **Chunk face culling**: Culls entire chunk faces when hidden

#### 4. **Intelligent Task Scheduling**
- Frame-rate independent scheduling prevents stutter
- Priority-based chunk loading (distance + direction)
- Adaptive performance tuning based on frame time
- ML-based effort estimation for balanced frame times

#### 5. **Per-Region Caching**
- Caches rendered chunk data to avoid rebuilds
- Fast cache hits for unchanged regions
- Invalidates only affected regions when chunks change

#### 6. **Multi-threading Optimizations**
- Nearby block updates use multiple threads
- Async chunk generation and meshing
- Worker thread pool with job prioritization

---

## Current Implementation Analysis

### ✅ What's Already Implemented (Good!)

1. **Greedy Meshing** (`chunk_mesh_builder.gd:283-349`)
   - Merges adjacent faces of same block type
   - Reduces quad count significantly
   - Slice-based algorithm per direction

2. **Region Batching** (`chunk_region.gd`)
   - Combines multiple chunks into single mesh
   - Reduces draw calls
   - Similar to Sodium's region approach

3. **Threading** (`chunk_thread_pool.gd`)
   - Worker threads for chunk generation
   - Worker threads for mesh building
   - Job prioritization by distance

4. **Frustum Culling** (`chunk_manager.gd:449-588`)
   - Spread over 4 frames to prevent stalls (smart!)
   - Region-level culling when batching enabled
   - AABB intersection tests

5. **Occlusion Culling** (`occlusion_culler.gd`)
   - Flood-fill based visibility determination
   - Reduces overdraw

6. **Chunk Caching** (`chunk_cache.gd`)
   - LRU cache for generated chunks
   - Saves/loads voxel data
   - Reduces regeneration overhead

7. **Deferred Mesh Creation** (`chunk_manager.gd:1418-1541`)
   - Creates meshes over multiple frames
   - Prevents 4+ second stalls
   - Vertex count budgeting

### ⚠️ What Can Be Improved

1. **Vertex Data Format** 🎯 **HIGH IMPACT**
   - Current: Standard Godot vertex format with full floats
   - Problem: High memory bandwidth usage
   - **Solution: Pack vertex data more efficiently**
   - Expected: 30-40% memory reduction, 15-25% FPS improvement

2. **Mesh Array Caching** 🎯 **MEDIUM IMPACT**
   - Current: Cached but rebuilds entire region on any change
   - Problem: Expensive rebuilds even for small changes
   - **Solution: Granular chunk-level cache with smart invalidation**
   - Expected: 50% reduction in mesh rebuild time

3. **Task Priority Algorithm** 🎯 **MEDIUM IMPACT**
   - Current: Simple distance-based priority
   - Problem: Doesn't account for camera direction aggressively enough
   - **Solution: Weighted priority (distance×2 + direction×3)**
   - Expected: Faster perceived loading, better UX

4. **Vertex Buffer Reuse** 🎯 **LOW-MEDIUM IMPACT**
   - Current: Creates new meshes each rebuild
   - Problem: GC pressure from mesh allocation
   - **Solution: Reuse ArrayMesh instances, only update arrays**
   - Expected: Reduced GC pauses, smoother frame times

---

## Implementation Plan

### Phase 1: Vertex Data Compression (Highest Impact)

**Goal**: Reduce vertex data size by 30-40% to decrease memory bandwidth

**Changes**:
1. Use compressed vertex format in `ChunkMeshBuilder`
   - Pack position as Vector3i (3 bytes) instead of Vector3 (12 bytes)
   - Pack normal as single byte (6 possible normals)
   - Pack color efficiently

2. Benefits:
   - Lower VRAM usage
   - Faster GPU transfer
   - Better cache utilization
   - 15-25% FPS improvement expected

**Files to modify**:
- `chunk_mesh_builder.gd`: Add compact vertex format option
- `chunk_region.gd`: Use compact format when combining meshes

### Phase 2: Smart Mesh Cache Invalidation (Medium Impact)

**Goal**: Reduce unnecessary mesh rebuilds by 50%

**Changes**:
1. Track which specific chunks changed in a region
2. Only rebuild affected chunk meshes
3. Combine cached meshes for unchanged chunks

**Files to modify**:
- `chunk_manager.gd`: Smarter dirty tracking
- `chunk_region.gd`: Partial rebuild support
- `chunk.gd`: Fine-grained dirty flags

### Phase 3: Improved Task Scheduling (Medium Impact)

**Goal**: Prioritize visible chunks more aggressively

**Changes**:
1. Increase camera direction weight in priority calculation
2. Add frustum-aware prioritization (visible chunks first)
3. Deprioritize chunks behind player

**Files to modify**:
- `chunk_manager.gd:704-727`: Enhanced priority calculation
- `chunk_thread_pool.gd`: Priority queue improvements

### Phase 4: Vertex Buffer Reuse (Low-Medium Impact)

**Goal**: Reduce GC pressure from mesh allocation

**Changes**:
1. Reuse ArrayMesh instances instead of creating new ones
2. Update mesh arrays in-place when possible
3. Pool MeshInstance3D objects

**Files to modify**:
- `chunk_region.gd`: ArrayMesh reuse
- `chunk_manager.gd`: Mesh pooling

---

## Expected Performance Improvements

Based on Sodium's results and our analysis:

| Optimization | Memory Impact | FPS Impact | Implementation Effort |
|-------------|---------------|------------|---------------------|
| Vertex Compression | -30-40% VRAM | +15-25% FPS | Medium (2-3 hours) |
| Smart Cache Invalidation | -10% CPU | +10-15% FPS | Medium (2-3 hours) |
| Better Task Scheduling | Minimal | +5-10% perceived | Low (1 hour) |
| Vertex Buffer Reuse | -5% GC | +5% smoothness | Medium (2 hours) |
| **TOTAL** | **~40% less VRAM** | **+35-50% FPS** | **~8-9 hours** |

---

## Key Takeaways

### What Your Engine Already Does Well ✅
- Region batching (like Sodium's 8×4×8 regions)
- Greedy meshing (reduces geometry)
- Multi-threaded generation/meshing
- Frustum + occlusion culling
- Deferred mesh creation (prevents stalls)
- Smart chunk caching

### What Sodium Does Better 📚
- More aggressive vertex data compression
- Smarter cache invalidation (per-chunk, not per-region)
- Modern rendering techniques (multi-draw indirect)
- ML-based task scheduling
- Better memory pooling

### What We'll Implement 🚀
1. **Vertex data compression** (biggest win)
2. **Chunk-level cache invalidation** (reduces rebuilds)
3. **Improved task prioritization** (better UX)
4. **Mesh instance pooling** (reduces GC)

---

## References

- Sodium GitHub: https://github.com/CaffeineMC/sodium
- Sodium Performance Analysis: Search results from 2024
- Greedy Meshing: Already implemented in your engine
- Region Batching: Already implemented in your engine
