# Occlusion Culling - Testing & Verification Guide

**Date:** 2025-11-08
**Feature:** Graph-based occlusion culling system

## What Was Implemented

Occlusion culling reduces the number of chunks rendered by hiding chunks that are blocked by terrain. This is especially effective when:
- Underground in caves
- Behind mountains/hills
- In dense terrain

### Two Modes Available

1. **RAYCAST Mode** (Simple)
   - Fast raycast from camera to each chunk
   - Good for initial testing
   - Less accurate but minimal overhead

2. **FLOOD_FILL Mode** (Sodium-style) ⭐ **DEFAULT**
   - Graph-based visibility culling
   - More accurate
   - Uses caching for performance
   - Only rebuilds graph when chunks load/unload

## How to Test

### 1. Launch the Test Scene

Run the voxel test scene:
```
godot_project/scenes/voxel_test_scene.tscn
```

### 2. Check Debug UI

The debug overlay (top-left) now shows:
```
Occlusion: FLOOD_FILL
Visible: 45 | Hidden: 23
Culled: 33.8%
```

**What to look for:**
- **Occlusion mode** should show `FLOOD_FILL` (default)
- **Visible/Hidden** shows chunk counts
- **Culled %** shows what percentage of chunks are hidden by occlusion

### 3. Test Scenarios

#### Scenario A: Surface Testing (Low Occlusion)
1. Stay on the surface
2. Look at open terrain
3. **Expected:** Low occlusion rate (0-10%)
4. **Why:** Most chunks are visible from above

#### Scenario B: Underground/Cave Testing (High Occlusion)
1. Dig underground or find a cave
2. Look around while underground
3. **Expected:** High occlusion rate (30-60%)
4. **Why:** Solid terrain blocks chunks behind walls

#### Scenario C: Behind Mountains (Medium Occlusion)
1. Stand near a mountain
2. Face the mountain directly
3. **Expected:** Medium occlusion rate (15-30%)
4. **Why:** Mountain blocks distant chunks

### 4. Performance Comparison

#### Disable Occlusion Culling
Edit `chunk_manager.gd` line 102:
```gdscript
# Before (occlusion enabled):
occlusion_culler.mode = OcclusionCuller.Mode.FLOOD_FILL

# After (occlusion disabled):
occlusion_culler.mode = OcclusionCuller.Mode.DISABLED
```

#### Compare Performance
- **With FLOOD_FILL:** Should see 15-30% fewer chunks rendered
- **With DISABLED:** All frustum-visible chunks are rendered
- **FPS Impact:** Should see +5-15% FPS improvement underground

### 5. Advanced Testing: Toggle Modes at Runtime

Add this script to test different modes:

```gdscript
# Add to voxel_world.gd or create a debug controller

func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F1:
            _toggle_occlusion_mode()

func _toggle_occlusion_mode():
    if not chunk_manager or not chunk_manager.occlusion_culler:
        return

    var culler = chunk_manager.occlusion_culler
    var modes = [
        OcclusionCuller.Mode.DISABLED,
        OcclusionCuller.Mode.RAYCAST,
        OcclusionCuller.Mode.FLOOD_FILL
    ]

    var current_index = modes.find(culler.mode)
    var next_index = (current_index + 1) % modes.size()
    culler.set_mode(modes[next_index])

    print("[VoxelWorld] Occlusion mode: %s" % OcclusionCuller.Mode.keys()[culler.mode])
```

Then press **F1** to cycle through modes while playing.

## Expected Results

### Performance Metrics

| Scenario | Chunks Active | Chunks Visible | Chunks Occluded | Occlusion Rate | FPS Gain |
|----------|--------------|----------------|-----------------|----------------|----------|
| Surface (open) | 100 | 95 | 5 | 5% | +2% |
| Underground (cave) | 100 | 55 | 45 | 45% | +15% |
| Behind mountain | 100 | 75 | 25 | 25% | +8% |

### Graph Rebuild Behavior

Watch console output for:
```
[OcclusionCuller] Mode changed to: FLOOD_FILL
```

Graph rebuilds happen:
- When player moves to a new chunk
- Every 30 frames if dirty
- When chunks load/unload

## Troubleshooting

### Issue: Occlusion shows 0%
**Cause:** All chunks may be visible (open terrain)
**Solution:** Move underground or behind terrain

### Issue: Occlusion shows 100%
**Cause:** Possible bug in visibility graph
**Solution:** Check console for errors, verify chunk.is_empty() logic

### Issue: FPS drops when enabled
**Cause:** Graph rebuilding too frequently
**Solution:** Increase `rebuild_graph_interval` in occlusion_culler.gd (line 32)

### Issue: Chunks disappear incorrectly
**Cause:** False positives in occlusion detection
**Solution:**
1. Switch to RAYCAST mode temporarily
2. Check visibility graph logic
3. Verify `_get_visible_neighbors()` is working correctly

## Debug Commands

Add these to VoxelWorld for debugging:

```gdscript
# Print detailed occlusion stats
func debug_print_occlusion_stats():
    if chunk_manager and chunk_manager.occlusion_culler:
        chunk_manager.occlusion_culler.print_stats()

# Disable occlusion temporarily
func debug_disable_occlusion():
    if chunk_manager and chunk_manager.occlusion_culler:
        chunk_manager.occlusion_culler.set_mode(OcclusionCuller.Mode.DISABLED)

# Re-enable occlusion
func debug_enable_occlusion():
    if chunk_manager and chunk_manager.occlusion_culler:
        chunk_manager.occlusion_culler.set_mode(OcclusionCuller.Mode.FLOOD_FILL)
```

Call from console:
```gdscript
get_node("/root/VoxelWorld").debug_print_occlusion_stats()
```

## Performance Optimization Tips

### Already Optimized ✅
- Caching of visibility graph
- Only rebuilds when chunks change
- Manhattan distance limiting
- Frame-rate independent graph updates

### Future Optimizations
1. **Hierarchical culling**: Group chunks into regions for faster tests
2. **Portal-based culling**: Detect cave openings and tunnel connections
3. **Shadow volume optimization**: Pre-compute occlusion shadows
4. **Async graph building**: Move graph rebuild to worker thread

## Integration with Other Systems

### Frustum Culling
Occlusion culling works **in addition to** frustum culling:
```
Final Visibility = Frustum Visible AND Not Occluded
```

### Future: Region Batching
When region batching is implemented:
- Occlusion will work at region level
- Even better performance (fewer visibility tests)
- Current chunk-level occlusion is compatible

### Future: LOD System
Occlusion culling will complement LOD:
- Occluded chunks skip LOD entirely
- Visible chunks use appropriate LOD level
- Maximum performance gain

## Success Criteria

✅ **Implementation Complete** if:
1. Debug UI shows occlusion stats
2. Chunks are hidden when behind terrain
3. Graph rebuilds when chunks change
4. No visual artifacts (incorrect culling)
5. FPS improves by 5-15% underground

✅ **Performance Target Met** if:
- 20-40% of chunks occluded in caves
- <1ms overhead for visibility updates
- Graph rebuild completes in <5ms

## Next Steps

After verifying occlusion culling works:

1. **Week 2:** Implement increased chunk height (16x16x64)
2. **Week 3:** Implement region-based mesh batching (Priority 1)
3. **Optimize:** Profile and tune occlusion parameters
4. **Polish:** Add visualization mode to show occluded chunks

---

**Status:** Implementation complete, ready for testing
**Expected Impact:** +15-30% fewer chunks rendered, +5-15% FPS gain
**Recommended Mode:** FLOOD_FILL (default)
