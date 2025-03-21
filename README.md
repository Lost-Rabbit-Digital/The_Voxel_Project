# Steel and Cube

A voxel-based dungeon crawler that combines the immersive first-person RPG elements of Daggerfall with modern voxel-based terrain and construction mechanics. Delve into procedurally generated dungeons, fight enemies, collect loot, and shape the world around you - all while experiencing a classic RPG interface reimagined for the modern era.

![Game Screenshot](github_screenshots/screenshot_2.png)

## Features

- Dynamic lighting and shadow system
- Voxel-based terrain

## Getting Started

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Lost-Rabbit-Digital/steel_and_cube.git
```

2. Open Godot 4.0 Engine

3. Click "Import" and navigate to the cloned project directory

4. Select the `project.godot` file

5. Click "Import & Edit"

### Running the Game

1. Open the project in Godot 4.0
2. Press F5 or click the "Play" button in the top-right corner
3. Alternatively, export the game for your platform using Godot's export system

### System Requirements

| Specification | Minimum | Recommended |
|---------------|---------|-------------|
| OS            | Windows XP 64-bit | Windows 10 64-bit |
| Processor     | Intel Pentium 4 / AMD Athlon 64 | Intel Core i7-8700K / AMD Ryzen 7 3700X |
| Memory        | 2 GB RAM | 16 GB RAM |
| Graphics      | Nvidia GeForce 6800 GT / ATI Radeon X800 XT | Nvidia RTX 2070 Super / AMD RX 5700 XT |
| DirectX       | Version 9.0c | Version 12 |
| Storage       | 1 GB HDD | 250 GB SSD |

## Development Setup

### Project Structure

```
res://
├── addons/
│   ├── debug_menu/
├── assets/
│   ├── textures/
├── scenes/
└── scripts/
    ├── environment/
    └── systems/
    		├── interaction_system/
    		└── voxel_system/
```

### Coding Standards

- Follow GDScript style guide
- Use PascalCase for classes and node names
- Use snake_case for functions and variables
- Comment complex algorithms and systems
- Keep functions focused and single-purpose
- Use Godot's built-in signals for communication between nodes

## Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Guidelines for Contributions

- Ensure code follows project style guide
- Add comments for complex logic
- Update documentation if needed
- Test your changes thoroughly
- Keep pull requests focused on single features/fixes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by The Elder Scrolls II: Daggerfall
- Older project Voxel Engine Alpaca: https://github.com/Lost-Rabbit-Digital/VoxelEngineAlpaca
- Built with Godot Engine
- Community contributions and feedback

## Contact

- Discord Server: [Join our community](https://discord.gg/Y7caBf7gBj)

## Roadmap

- [ ] Dungeons
- [ ] Enemies
- [ ] Crafting
- [ ] Multiplayer
- [ ] Mods
- [ ] Biomes