# Optimisations
- Add frustum culling for chunks
- Add LOD (Level of Detail) system for distant chunks
- Implement greedy meshing to combine adjacent faces
- Add a priority queue based on distance to player
- Use GPU instancing for mesh generation
- Implement LOD (Level of Detail) system
- Use vertex buffer pooling
- Optimize face culling algorithms

Add texture support for the different material types?
Implement smoother transitions between materials?
Add additional terrain features like caves or overhangs?

### Memory Management
- Implement more aggressive chunk unloading
- Add memory usage tracking
- Create configurable memory limits

### Procedural Generation Enhancements
- Add biome variation
- Implement cave systems
- Create more diverse terrain features

# Todo
- Setup project structure in Godot similar to how the [README](../README.md/#project-structure) has it

# Completed Tasks
These are the tasks which have already been completed

## Version 1.0.0
- Implement chunk loading/unloading based on distance
- Implement chunk caching/serialization
- Use multi-threading for chunk generation