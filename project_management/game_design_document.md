# Steel and Cube - Game Design Document

## High-Level Vision

**Steel and Cube** is a first-person voxel RPG that combines the sandbox building and exploration of **Alpha Minecraft** with the deep RPG mechanics and interface design of **The Elder Scrolls II: Daggerfall**. Players will explore procedurally generated dungeons, engage in classic RPG combat, develop their character through a robust skill system, and shape the voxel world around them.

### Core Pillars

1. **Classic RPG Depth** - Character stats, skills, leveling, and meaningful progression
2. **Voxel Freedom** - Mine, build, and modify the world with block-based construction
3. **Dungeon Crawling** - Procedurally generated dungeons filled with enemies, traps, and loot
4. **Immersive First-Person Interface** - Daggerfall-inspired HUD and UI design

---

## Game Overview

### Genre
First-Person Voxel RPG / Dungeon Crawler

### Target Audience
- Fans of classic dungeon crawlers (Daggerfall, Arena, Ultima Underworld)
- Minecraft players seeking deeper RPG mechanics
- Players who enjoy character progression and skill-based gameplay

### Platform
PC (Windows/Linux/Mac via Godot Engine)

### Art Style
- Low-poly voxel aesthetic (similar to Alpha Minecraft)
- Daggerfall-inspired UI elements and color palette
- Atmospheric lighting with dynamic shadows
- Retro-modern hybrid visual approach

---

## Gameplay Systems

### 1. Core Gameplay Loop

```
Enter Dungeon → Explore → Combat Enemies → Collect Loot → Mine Resources →
→ Return to Surface → Craft/Build → Upgrade Character → Enter Deeper Dungeon
```

### 2. Character System (Daggerfall-Inspired)

#### Primary Attributes
- **Strength** - Melee damage, carrying capacity
- **Intelligence** - Spell effectiveness, mana pool
- **Willpower** - Mana regeneration, spell resistance
- **Agility** - Attack speed, dodge chance
- **Endurance** - Health points, stamina
- **Personality** - NPC reactions, merchant prices
- **Speed** - Movement speed, attack speed
- **Luck** - Critical hits, loot quality

#### Skills (18 Skills)
**Combat Skills:**
- Blade - One-handed swords
- Axe - One and two-handed axes
- Blunt Weapon - Maces, hammers
- Archery - Bows and crossbows
- Block - Shield defense

**Magic Skills:**
- Destruction - Offensive magic
- Restoration - Healing magic
- Alteration - Utility magic
- Illusion - Stealth and mind magic

**Stealth Skills:**
- Stealth - Sneaking, pickpocketing
- Lockpicking - Open locked chests/doors
- Pickpocket - Steal from NPCs

**Crafting Skills:**
- Mining - Harvest voxel resources faster
- Building - Construct structures efficiently
- Smithing - Craft weapons and armor
- Alchemy - Create potions

**General Skills:**
- Athletics - Running, jumping, swimming
- Acrobatics - Climbing, dodging

#### Skill Progression
- Skills improve through use (Morrowind/Daggerfall style)
- Each skill level grants minor bonuses
- Major skill increases contribute to character level-ups

### 3. Voxel Building System (Minecraft-Inspired)

#### Block Types
**Natural Blocks:**
- Stone, Dirt, Grass, Sand, Gravel
- Ore blocks (Iron, Gold, Silver, Mithril)
- Wood (Oak, Pine, Birch)
- Water, Lava

**Crafted Blocks:**
- Planks, Bricks, Stone Bricks
- Glass, Torches, Ladders
- Furniture (Tables, Chairs, Beds)
- Crafting stations (Forge, Enchanting Table, Alchemy Lab)

#### Mining & Building
- Left-click to mine/attack
- Right-click to place blocks
- Hotbar with 9 quick-access slots
- Mining skill affects mining speed
- Different tools required for different materials (pickaxe, axe, shovel)

### 4. Combat System

#### Combat Mechanics
- **First-person melee combat** - Directional attacks (slash, thrust, overhead)
- **Stamina-based** - Attacks consume stamina
- **Block and parry** - Timed blocking reduces/negates damage
- **Archery** - Draw and release for variable power
- **Magic casting** - Select spell, aim, cast (mana cost)

#### Attack Directions (Daggerfall-style)
- **Thrust** - Forward mouse movement while clicking
- **Slash** - Horizontal mouse movement
- **Overhead** - Downward mouse movement
- Weapon type determines effective attack directions

#### Damage Calculation
```
Base Damage = Weapon Damage × Skill Modifier × Strength Modifier
Final Damage = Base Damage - (Armor Rating × Block Modifier)
Critical Hit = Luck-based chance for 2x damage
```

### 5. Magic System

#### Spell Schools
1. **Destruction** - Fireball, Lightning Bolt, Ice Spike
2. **Restoration** - Heal, Cure Disease, Fortify Attribute
3. **Alteration** - Light, Levitate, Open Lock
4. **Illusion** - Invisibility, Calm, Fear

#### Spell Casting
- Spells learned from spell tomes or trainers
- Hotkey spells to quick-access slots
- Mana regenerates slowly over time
- Higher Intelligence = larger mana pool
- Spell effectiveness scales with skill level

#### Spell Creation (Future Feature)
- Combine effects to create custom spells
- Cost scales with power and duration

### 6. Inventory System

#### Inventory Interface
- Grid-based inventory (Daggerfall-style)
- Weight-based carrying capacity
- Equipment paper doll showing worn items
- Categorized tabs: Weapons, Armor, Potions, Miscellaneous

#### Equipment Slots
- Head, Chest, Legs, Feet, Hands
- Main Hand, Off Hand (weapon/shield)
- Amulet, Ring (x2)

#### Item Types
- **Weapons** - Swords, axes, maces, bows, staves
- **Armor** - Light (leather), Medium (chainmail), Heavy (plate)
- **Consumables** - Health potions, mana potions, food
- **Materials** - Ores, wood, stone, gems
- **Quest Items** - Keys, artifacts, special objects

### 7. Dungeon Generation

#### Dungeon Structure
- Procedurally generated multi-level dungeons
- Increasing difficulty with depth
- Room-based layout with corridors
- Secret rooms and hidden passages

#### Dungeon Features
- **Enemy encounters** - Spawned based on dungeon level
- **Traps** - Pressure plates, arrow traps, spike pits
- **Treasure rooms** - Locked chests with valuable loot
- **Boss rooms** - Powerful enemies guarding rare items
- **Environmental hazards** - Lava pools, collapsing floors, poison gas

#### Dungeon Types
1. **Crypts** - Undead enemies, dark atmosphere
2. **Caves** - Natural formations, wildlife
3. **Ruins** - Ancient structures, magical enemies
4. **Mines** - Rich in ore, industrial hazards

### 8. Enemy System

#### Enemy Types
**Tier 1 (Surface/Early Dungeons):**
- Rats, Bats, Wolves
- Goblins, Bandits
- Skeletons, Zombies

**Tier 2 (Mid-level Dungeons):**
- Orcs, Trolls
- Ghosts, Wraiths
- Giant Spiders, Giant Scorpions

**Tier 3 (Deep Dungeons):**
- Dark Knights, Vampire Lords
- Demons, Daedra
- Ancient Liches
- Dragons (Boss enemies)

#### Enemy AI
- Pathfinding through voxel terrain
- Aggression based on player level and visibility
- Group behaviors for humanoid enemies
- Special abilities for magic-using enemies

### 9. Crafting System

#### Crafting Stations
- **Forge** - Craft weapons and armor from ore/ingots
- **Alchemy Lab** - Mix potions from ingredients
- **Enchanting Table** - Enchant equipment with magical effects
- **Crafting Table** - General crafting (tools, blocks, furniture)

#### Recipe System
- Recipes discovered through gameplay
- Material requirements clearly displayed
- Skill requirements for advanced recipes
- Quality varies based on crafting skill

---

## User Interface (Daggerfall-Inspired)

### HUD Elements

#### Main HUD (In-Game View)
```
┌─────────────────────────────────────────────┐
│                                             │
│                  GAMEPLAY                   │
│                    VIEW                     │
│                                             │
├─────────────────────────────────────────────┤
│ ❤️ Health: ████████░░                      │
│ 💧 Mana:   ██████░░░░                      │
│ ⚡ Stamina: ███████░░░       🧭 [COMPASS]   │
│ [1][2][3][4][5][6][7][8][9]                │
└─────────────────────────────────────────────┘
```

#### Compass
- Always visible at top-center of screen
- Shows cardinal directions (N, S, E, W)
- Quest markers appear on compass
- Dungeon entrance/exit markers

#### Status Bars
- **Health** - Red bar, depletes from damage
- **Mana** - Blue bar, depletes from spell casting
- **Stamina** - Yellow bar, depletes from sprinting/attacking

#### Hotbar
- 9 slots for quick item/spell access
- Numbered 1-9 for keyboard shortcuts
- Shows item/spell icons and quantity

### Menu Interfaces

#### Character Sheet
- Papyrus/parchment background aesthetic
- Portrait of character
- Attribute values with modifiers
- Skill list with progress bars
- Current level and XP to next level

#### Inventory Screen
- Paper doll showing equipped items
- Grid-based item storage
- Item tooltips showing stats
- Weight limit indicator

#### Map Screen
- Auto-mapping of explored dungeon areas
- Fog of war for unexplored regions
- Player position marker
- Points of interest (treasure, stairs, etc.)

#### Spell Book
- List of known spells by school
- Spell descriptions and costs
- Drag-and-drop to hotbar

---

## Progression Systems

### Character Leveling
- Gain XP from combat, quests, exploration
- Level up when XP threshold reached
- On level up:
  - Increase health, mana, stamina
  - Gain attribute points to distribute
  - Select new perks/abilities

### Equipment Progression
**Material Tiers:**
1. Wood/Leather (Level 1-5)
2. Iron/Chainmail (Level 5-10)
3. Steel/Scale (Level 10-15)
4. Silver/Elven (Level 15-20)
5. Mithril/Dwarven (Level 20-25)
6. Daedric/Dragonbone (Level 25+)

**Enchantments:**
- Magical effects added to equipment
- Fire damage, frost resistance, fortify strength, etc.
- Found on loot or crafted at enchanting tables

### Skill Mastery
- **Novice** (0-25) - Basic usage
- **Apprentice** (25-50) - Improved efficiency
- **Journeyman** (50-75) - Special abilities unlocked
- **Expert** (75-100) - Mastery bonuses

---

## World Design

### Surface World
- Procedurally generated voxel terrain
- Biomes: Plains, Forests, Mountains, Deserts
- Villages and towns with NPCs
- Dungeon entrances scattered throughout
- Player can build structures anywhere

### Underground/Dungeons
- Separate instances from surface world
- Finite size but very large
- No building allowed (or very limited)
- Designed for exploration and combat

### Fast Travel
- Unlock fast travel points at towns/landmarks
- Cannot fast travel from within dungeons
- Daggerfall-style travel map

---

## Audio Design

### Music
- Atmospheric, orchestral tracks (Daggerfall-inspired)
- Different themes for:
  - Surface exploration
  - Towns/villages
  - Dungeon exploration
  - Combat encounters
  - Boss battles

### Sound Effects
- Voxel mining sounds (similar to Minecraft)
- Weapon swings and impacts
- Magic casting effects
- Ambient dungeon sounds (drips, echoes, distant growls)
- UI interaction sounds

---

## Technical Specifications

### Engine
Godot 4.x

### Key Technical Features
- **Voxel terrain system** - Chunk-based world generation
- **Multithreaded chunk generation** - Performance optimization
- **Greedy meshing** - Efficient mesh generation
- **Dynamic lighting** - Real-time shadows and light sources
- **Procedural generation** - Infinite terrain and dungeons
- **Save system** - World persistence, character saves

### Performance Targets
- 60 FPS on recommended hardware
- Render distance: 8-16 chunks (configurable)
- Smooth chunk loading without stuttering

---

## Development Priorities

### Phase 1: Core Voxel Mechanics ✓ (Mostly Complete)
- Voxel terrain rendering
- Chunk management system
- Basic world generation
- Player movement and camera

### Phase 2: Daggerfall-Style RPG Foundation (Current Focus)
- Character attribute and skill system
- Inventory and equipment system
- Daggerfall-inspired HUD
- Basic combat mechanics

### Phase 3: Building & Crafting
- Mining blocks
- Placing blocks
- Crafting system
- Building tools

### Phase 4: Combat & Magic
- Melee combat with directional attacks
- Blocking and parrying
- Magic casting system
- Basic enemy AI

### Phase 5: Dungeons & Enemies
- Dungeon generation system
- Enemy spawning
- Loot system
- Traps and hazards

### Phase 6: Polish & Content
- More enemy types
- More spells and equipment
- Quest system
- NPC dialogue
- Sound and music

---

## Unique Selling Points

1. **Daggerfall meets Minecraft** - First game to truly merge these two classics
2. **Deep RPG in a voxel world** - Stats and skills that matter
3. **Build your base, delve into dungeons** - Satisfying gameplay loop
4. **Classic interface, modern engine** - Nostalgia with modern performance
5. **Procedural generation** - Infinite replayability

---

## Future Expansion Ideas

- **Multiplayer co-op** - Explore dungeons with friends
- **Mod support** - Custom dungeons, items, spells
- **Expanded magic system** - Spell creation and combination
- **Guild systems** - Join Mages Guild, Fighters Guild, Thieves Guild
- **Housing system** - Player homes with storage and decoration
- **Advanced NPCs** - Schedule systems, relationships, reputation
- **Overworld quests** - Bounties, fetch quests, storylines

---

## Conclusion

**Steel and Cube** aims to deliver a unique experience by blending two beloved gaming philosophies: the freedom and creativity of voxel building games with the depth and immersion of classic first-person RPGs. By combining Alpha Minecraft's sandbox appeal with Daggerfall's rich character systems and atmospheric dungeon crawling, we're creating something truly special for fans of both genres.
