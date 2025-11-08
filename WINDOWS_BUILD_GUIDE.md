# Building the Voxel Engine GDExtension on Windows

This guide explains how to build the C++ GDExtension for Windows.

## Prerequisites

### 1. Install Python 3

Download and install Python 3.8 or later from https://www.python.org/downloads/

**Important:** Check "Add Python to PATH" during installation.

### 2. Install SCons

Open Command Prompt or PowerShell and run:

```powershell
pip install scons
```

### 3. Install a C++ Compiler

You have two options:

#### Option A: Visual Studio (Recommended)

Download and install **Visual Studio 2019** or **Visual Studio 2022** Community Edition:
https://visualstudio.microsoft.com/downloads/

During installation, select:
- **Desktop development with C++** workload
- Windows 10/11 SDK

#### Option B: MinGW-w64

Download MinGW-w64 from: https://www.mingw-w64.org/

1. Use the installer and select:
   - Architecture: `x86_64`
   - Threads: `win32` or `posix`
   - Exception: `seh`
2. Add MinGW `bin` folder to your PATH (e.g., `C:\mingw64\bin`)

## Build Steps

### 1. Open Command Prompt

Navigate to your project directory:

```powershell
cd path\to\The_Voxel_Project\gdextension
```

### 2. Initialize Submodules (First Time Only)

```powershell
git submodule update --init --recursive
```

### 3. Build godot-cpp

This takes 5-10 minutes the first time:

```powershell
cd godot-cpp
scons platform=windows target=template_debug -j4
scons platform=windows target=template_release -j4
cd ..
```

**Note:** `-j4` means use 4 CPU cores. Adjust based on your CPU (e.g., `-j8` for 8 cores).

### 4. Build the Voxel Extension

```powershell
scons platform=windows target=template_debug -j4
scons platform=windows target=template_release -j4
```

### 5. Verify Build

Check that the DLL was created:

```powershell
dir bin\*.dll
```

You should see:
- `libvoxelengine.windows.template_debug.x86_64.dll`
- `libvoxelengine.windows.template_release.x86_64.dll`

### 6. Enable in .gdextension File

Edit `gdextension/voxel_engine.gdextension` and uncomment the Windows lines:

```ini
[libraries]
windows.debug.x86_64 = "res://../gdextension/bin/libvoxelengine.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://../gdextension/bin/libvoxelengine.windows.template_release.x86_64.dll"
```

Also update `godot_project/voxel_engine.gdextension` with the same changes.

### 7. Test in Godot

1. Open your Godot project
2. The errors should be gone
3. You should see `VoxelWorld` available in "Add Node"

## Troubleshooting

### "scons: command not found"

Make sure Python is in your PATH and you ran `pip install scons`.

Try:
```powershell
python -m pip install scons
```

Then use:
```powershell
python -m SCons platform=windows target=template_debug
```

### Compiler Not Found

#### For Visual Studio:

Make sure you're using the **Developer Command Prompt** or **Developer PowerShell** that comes with Visual Studio. Find it in:

Start Menu → Visual Studio 2022 → Developer Command Prompt for VS 2022

OR set up the environment manually:
```powershell
"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
```

#### For MinGW:

Make sure MinGW's `bin` folder is in your PATH:

```powershell
$env:Path += ";C:\mingw64\bin"
```

Then specify the compiler explicitly:
```powershell
scons platform=windows use_mingw=yes
```

### Build Errors

1. **Clean and rebuild:**
   ```powershell
   scons --clean
   scons platform=windows target=template_debug -j4
   ```

2. **Check godot-cpp was built:**
   ```powershell
   dir godot-cpp\bin\*.lib
   ```
   You should see `libgodot-cpp.windows.template_debug.x86_64.lib`

3. **Update godot-cpp:**
   ```powershell
   cd godot-cpp
   git pull origin 4.3
   cd ..
   ```

### DLL Not Loading in Godot

1. **Check paths in .gdextension file:**
   - Paths should use forward slashes: `res://../gdextension/bin/...`
   - Make sure the DLL actually exists at that location

2. **Missing dependencies:**
   - Run `where cl` (Visual Studio) or `where g++` (MinGW) to verify compiler
   - The DLL might need Visual C++ Redistributables: https://aka.ms/vs/17/release/vc_redist.x64.exe

3. **Architecture mismatch:**
   - Make sure you built for x86_64 (64-bit)
   - Godot must also be 64-bit

## Quick Reference

### Full Build (Debug + Release)

```powershell
# From gdextension/ folder
cd godot-cpp && scons platform=windows target=template_debug -j4 && scons platform=windows target=template_release -j4 && cd ..
scons platform=windows target=template_debug -j4
scons platform=windows target=template_release -j4
```

### Clean Build

```powershell
scons --clean
cd godot-cpp && scons --clean && cd ..
```

### Rebuild After Code Changes

```powershell
# Only rebuild the extension (godot-cpp doesn't need rebuilding)
scons platform=windows target=template_debug -j4
```

## Performance Tips

1. **Use Release Build for Production:**
   - Debug builds are 5-10x slower
   - Release builds have full optimizations enabled

2. **Check Build Type in Godot:**
   - Debug: `template_debug` DLL is loaded
   - Release: `template_release` DLL is loaded

3. **Parallel Compilation:**
   - Use `-j` flag with number of CPU cores
   - Example: `-j8` for 8-core CPU
   - Speeds up compilation significantly

## Next Steps

After building successfully:

1. Open your Godot project
2. Add a `VoxelWorld` node to your scene
3. Configure its properties:
   - `render_distance`: 8
   - `world_seed`: 12345
   - `player_path`: Path to your player/camera node

4. Run the scene and enjoy 10-100x performance improvement!

## Additional Resources

- [GDExtension Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)
- [godot-cpp GitHub](https://github.com/godotengine/godot-cpp)
- [SCons Documentation](https://scons.org/documentation.html)

## Support

If you encounter issues:

1. Check the error message carefully
2. Verify all prerequisites are installed
3. Try the troubleshooting steps above
4. Check Godot version compatibility (4.3+)
