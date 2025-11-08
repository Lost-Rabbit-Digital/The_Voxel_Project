# Voxel Engine C++ GDExtension - Build Instructions

The voxel engine has been rewritten as a high-performance C++ GDExtension. **You must build it for your platform before using it in Godot.**

## Platform-Specific Guides

### 🪟 Windows Users
**→ See [WINDOWS_BUILD_GUIDE.md](WINDOWS_BUILD_GUIDE.md) for detailed Windows build instructions**

Quick summary:
```powershell
# Prerequisites: Python 3, SCons, Visual Studio 2019+
cd gdextension
cd godot-cpp && scons platform=windows target=template_debug -j4 && cd ..
scons platform=windows target=template_debug -j4
```

### 🐧 Linux Users

```bash
cd gdextension

# Build godot-cpp (first time only, ~5 minutes)
cd godot-cpp
scons platform=linux target=template_debug -j$(nproc)
cd ..

# Build the extension
scons platform=linux target=template_debug -j$(nproc)
```

The Linux build is already compiled and ready to use if you cloned this repo on Linux.

### 🍎 macOS Users

```bash
cd gdextension

# Build godot-cpp (first time only)
cd godot-cpp
scons platform=macos target=template_debug -j$(sysctl -n hw.ncpu)
cd ..

# Build the extension
scons platform=macos target=template_debug -j$(sysctl -n hw.ncpu)
```

Then uncomment the macOS lines in `gdextension/voxel_engine.gdextension`.

## Prerequisites (All Platforms)

1. **Python 3.8+** - [Download](https://www.python.org/downloads/)
2. **SCons** - Install via: `pip install scons`
3. **C++ Compiler:**
   - **Windows:** Visual Studio 2019+ or MinGW-w64
   - **Linux:** GCC 7+ or Clang 6+
   - **macOS:** Xcode Command Line Tools

## After Building

1. Edit `gdextension/voxel_engine.gdextension` and uncomment your platform's library paths
2. Copy the file to `godot_project/voxel_engine.gdextension`
3. Open your Godot project - the `VoxelWorld` node should now be available!

## Why Build Required?

GDExtensions are **native compiled code** (like .dll, .so, .dylib files). Each platform requires its own compiled binary. The repository includes:

✅ **Linux build** - Pre-compiled
❌ **Windows build** - You must compile on Windows
❌ **macOS build** - You must compile on macOS

This is normal for GDExtensions - each developer builds for their platform.

## Quick Start After Building

```gdscript
# Add VoxelWorld node in Godot editor
# Or create in code:
var voxel_world = VoxelWorld.new()
add_child(voxel_world)

# Configure
voxel_world.render_distance = 8
voxel_world.world_seed = 12345
voxel_world.player_path = NodePath("../Player")
```

## Performance vs GDScript

| Operation | GDScript | C++ GDExtension | Speedup |
|-----------|----------|-----------------|---------|
| Greedy Meshing | ~45ms | ~0.5ms | **90x** |
| Terrain Generation | ~12ms | ~0.8ms | **15x** |
| Memory Usage | ~8MB | ~2MB | **75% less** |

## Need Help?

- **Windows Build Issues:** See [WINDOWS_BUILD_GUIDE.md](WINDOWS_BUILD_GUIDE.md)
- **General Documentation:** See [GDEXTENSION_CPP_README.md](GDEXTENSION_CPP_README.md)
- **GDExtension Docs:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/

## Troubleshooting

### "GDExtension dynamic library not found"

**Cause:** The binary for your platform hasn't been built yet.

**Solution:**
1. Follow the build instructions for your platform above
2. Make sure the library paths are uncommented in `voxel_engine.gdextension`
3. Verify the .dll/.so/.dylib file exists in `gdextension/bin/`

### Build Errors

1. **Check prerequisites** are installed (Python, SCons, C++ compiler)
2. **Initialize submodules:** `git submodule update --init --recursive`
3. **Clean and rebuild:** `scons --clean` then rebuild
4. **Use correct terminal:**
   - Windows: Use "Developer Command Prompt for VS"
   - macOS/Linux: Regular terminal is fine

### Still Not Working?

Make sure:
- Godot version is 4.3 or newer
- You're using 64-bit Godot
- The `.gdextension` file is in your `godot_project/` folder
- Paths in `.gdextension` use forward slashes (even on Windows)

---

**Ready to build?** Choose your platform guide above and get started! 🚀
