# Steel and Cube - Project Tasks

> **Project Vision:** A multiplayer voxel RPG that fuses Minecraft's sandbox building, Daggerfall's deep RPG mechanics, and Stardew Valley's farming & ranching. Explore an infinite living world with dynamic seasons, weather, scattered dungeons, villages, and farms. Build together, farm together, adventure together.
>
> **Engine:** Godot 4.5 | **Platform:** Steam (Early Access → Full Release) | **Multiplayer:** Terraria-style (Host or Join, Multiple Characters/Worlds)

**Legend:**
- ✅ Complete
- 🚧 In Progress
- ⏳ Planned
- 🔄 Needs Refactoring
- 🐛 Bug/Issue

---

## Phase 1: Core Voxel Engine (Foundation)

### 1.1 Voxel Rendering System
- [x] ✅ Chunk-based terrain system
- [x] ✅ Mesh generation with face culling
- [x] ✅ Texture atlas support
- [x] ✅ Multithreaded chunk generation
- [ ] 🚧 Fix face rendering issues (current bug)
- [ ] ⏳ Implement greedy meshing optimization
- [ ] ⏳ Add ambient occlusion
- [ ] ⏳ Optimize mesh generation for complex structures

### 1.2 World Generation
- [x] ✅ Basic Perlin noise terrain generation
- [x] ✅ Height-based block type selection
- [ ] ⏳ Multiple biome support (plains, forest, desert, mountain)
- [ ] ⏳ Caves and underground generation
- [ ] ⏳ Ore vein generation (iron, gold, silver, mithril)
- [ ] ⏳ Tree and vegetation placement
- [ ] ⏳ Water and lava systems

### 1.3 Chunk Management
- [x] ✅ Chunk loading/unloading based on distance
- [x] ✅ Chunk caching system
- [ ] 🔄 Implement chunk pooling (see tasks.md)
- [ ] ⏳ Configurable render distance
- [ ] ⏳ Chunk save/load from disk
- [ ] ⏳ World seed system
- [ ] ⏳ Optimize memory usage for large worlds

### 1.4 Lighting System
- [x] ✅ Basic dynamic lighting
- [x] ✅ Shadow system
- [ ] ⏳ Block light propagation (torches, lava)
- [ ] ⏳ Sunlight propagation
- [ ] ⏳ Smooth lighting transitions
- [ ] ⏳ Day/night cycle
- [ ] ⏳ Colored lighting support

---

## Phase 2: Texture Atlas System (Minecraft Beta 1.7 Style)

### 2.1 Atlas Architecture

- [ ] ⏳ Design texture atlas layout (512x512 or 256x256)
- [ ] ⏳ Create default vanilla texture atlas
- [ ] ⏳ Implement single texture binding for all terrain
- [ ] ⏳ 16x16 pixel base resolution per texture tile
- [ ] ⏳ UV coordinate mapping system
- [ ] ⏳ Support for different block faces (top, sides, bottom)
- [ ] ⏳ Animated texture support (water, lava, torches)

### 2.2 Resource Pack System

- [ ] ⏳ Create resource pack folder structure
- [ ] ⏳ Implement pack.json metadata parser
- [ ] ⏳ Implement blocks.json UV mapping parser
- [ ] ⏳ Texture atlas loader (PNG/image loading)
- [ ] ⏳ Validation system for resource packs
- [ ] ⏳ Fallback to default textures on error
- [ ] ⏳ Hot-reload texture packs without restart

### 2.3 Technical Features

- [ ] ⏳ Mipmap generation for distant textures
- [ ] ⏳ Point filtering for pixel-art aesthetic
- [ ] ⏳ Alpha channel support (glass, leaves, water)
- [ ] ⏳ Texture animation system (frame-based)
- [ ] ⏳ Item icon rendering from atlas
- [ ] ⏳ UI element textures in atlas
- [ ] ⏳ Resource pack selection menu

### 2.4 Default Content

- [ ] ⏳ Create default block textures (dirt, grass, stone, wood, etc.)
- [ ] ⏳ Create default item textures
- [ ] ⏳ Create default UI textures
- [ ] ⏳ Document texture atlas coordinates
- [ ] ⏳ Create example resource pack

---

## Phase 3: Dynamic World Systems

### 3.1 Day/Night Cycle

- [ ] ⏳ Implement time progression system
- [ ] ⏳ 24-minute day/night cycle (configurable)
- [ ] ⏳ Sun/moon position calculation
- [ ] ⏳ Celestial body rendering (sun, moon, stars)
- [ ] ⏳ Dynamic skybox color changes
- [ ] ⏳ Sunlight intensity changes throughout day
- [ ] ⏳ Time phases (dawn, day, dusk, night)
- [ ] ⏳ Sleep system (beds skip to morning)
- [ ] ⏳ Multiplayer sleep voting
- [ ] ⏳ Time display on HUD

### 3.2 Weather System

- [ ] ⏳ Create weather state machine
- [ ] ⏳ Weather types (clear, cloudy, rain, thunderstorm, snow, fog, sandstorm)
- [ ] ⏳ Weather transition system
- [ ] ⏳ Biome-specific weather rules
- [ ] ⏳ Rain particle effects
- [ ] ⏳ Snow particle effects
- [ ] ⏳ Lightning strikes (random)
- [ ] ⏳ Thunder sound effects
- [ ] ⏳ Rain/snow sound loops
- [ ] ⏳ Weather affects lighting (darker during storms)
- [ ] ⏳ Rain extinguishes open torches
- [ ] ⏳ Snow accumulation on blocks
- [ ] ⏳ Weather display on HUD

### 3.3 Seasonal System

- [ ] ⏳ Implement calendar system (days, seasons, years)
- [ ] ⏳ Four seasons: Spring, Summer, Autumn, Winter
- [ ] ⏳ Season length configuration (default: 4 in-game days each)
- [ ] ⏳ Grass color changes by season
- [ ] ⏳ Leaf color changes (green → orange/red → bare)
- [ ] ⏳ Snow coverage in winter
- [ ] ⏳ Water freezing in winter
- [ ] ⏳ Seasonal weather probabilities
- [ ] ⏳ Day length changes by season
- [ ] ⏳ Crop growth affected by season
- [ ] ⏳ Animal spawn rates by season
- [ ] ⏳ Flower/plant spawning by season
- [ ] ⏳ Season display on HUD
- [ ] ⏳ Year counter

### 3.4 Environmental Systems

- [ ] ⏳ Sunlight propagation through blocks
- [ ] ⏳ Block light sources (torches, lava, glowstone)
- [ ] ⏳ Smooth lighting between blocks
- [ ] ⏳ Shadow rendering from sun/moon
- [ ] ⏳ Night vision effect (potions/spells)
- [ ] ⏳ Fog rendering for atmosphere
- [ ] ⏳ Temperature system (optional hardcore feature)
- [ ] ⏳ Biome temperature mapping
- [ ] ⏳ Temperature affects player (cold/heat damage)

---

## Phase 4: Multiplayer System

### 4.1 Networking Architecture (Terraria-Style)

- [ ] ⏳ Godot 4.5 built-in networking (ENet/WebRTC)
- [ ] ⏳ Host & Play mode (peer-to-peer, host acts as server)
- [ ] ⏳ Join Game mode (LAN discovery and direct IP)
- [ ] ⏳ Dedicated server option (headless, advanced)
- [ ] ⏳ Character selection screen (multiple characters per player)
- [ ] ⏳ World selection screen (multiple worlds, show metadata)
- [ ] ⏳ Character save/load system (separate from world)
- [ ] ⏳ World save/load system (separate from character)
- [ ] ⏳ LAN game discovery
- [ ] ⏳ Direct connect by IP interface

### 4.2 Player Synchronization

- [ ] ⏳ Player position and rotation sync
- [ ] ⏳ Player animation sync
- [ ] ⏳ Player inventory sync
- [ ] ⏳ Player stats sync
- [ ] ⏳ Equipment sync (visible armor/weapons on other players)
- [ ] ⏳ Player username display above head
- [ ] ⏳ Player list UI (Tab key)
- [ ] ⏳ Lag compensation and prediction

### 4.3 World Synchronization

- [ ] ⏳ Block place/break synchronization
- [ ] ⏳ Chunk streaming to new players
- [ ] ⏳ Entity spawn synchronization
- [ ] ⏳ Time/weather/season synchronization
- [ ] ⏳ Server-authoritative validation
- [ ] ⏳ Anti-cheat measures
- [ ] ⏳ World save system for server

### 4.4 Multiplayer Features

- [ ] ⏳ Text chat system (global, local, party)
- [ ] ⏳ Chat UI (slide-out, message history)
- [ ] ⏳ Party system (form groups)
- [ ] ⏳ Party UI (member list, health bars)
- [ ] ⏳ Player markers (see friends through walls)
- [ ] ⏳ Waypoint markers for party
- [ ] ⏳ Trading system between players
- [ ] ⏳ PvP toggle (server configurable)
- [ ] ⏳ Emote system

### 4.5 Server Administration

- [ ] ⏳ Whitelist/blacklist system
- [ ] ⏳ Operator permissions (admin commands)
- [ ] ⏳ Kick/ban players
- [ ] ⏳ Server backup system
- [ ] ⏳ Server log files
- [ ] ⏳ Admin panel UI
- [ ] ⏳ Server performance monitoring
- [ ] ⏳ Player count limits

---

## Phase 5: Overworld Expansion

### 5.1 Biome System

- [ ] ⏳ Temperature map generation
- [ ] ⏳ Humidity/rainfall map generation
- [ ] ⏳ Elevation-based biome selection
- [ ] ⏳ Biome blending at borders
- [ ] ⏳ Plains biome
- [ ] ⏳ Forest biome (oak, birch trees)
- [ ] ⏳ Hills biome
- [ ] ⏳ Taiga biome (pine trees, snow patches)
- [ ] ⏳ Tundra biome (snow, ice)
- [ ] ⏳ Mountain biome (high elevation, stone, snow peaks)
- [ ] ⏳ Desert biome (sand, cacti, sandstorms)
- [ ] ⏳ Savanna biome (dry grass, acacia)
- [ ] ⏳ Biome-specific block types
- [ ] ⏳ Biome-specific vegetation

### 5.2 Structure Generation

#### Villages
- [ ] ⏳ Village location algorithm (plains, forests)
- [ ] ⏳ Village building templates (houses, blacksmith, inn, temple, town hall)
- [ ] ⏳ Procedural village layout
- [ ] ⏳ Village paths and roads
- [ ] ⏳ NPC population spawning (10-20 NPCs)
- [ ] ⏳ Village safe zones (no enemy spawns)
- [ ] ⏳ Village guards
- [ ] ⏳ Village farms and fields

#### Towns
- [ ] ⏳ Town generation (larger, rarer than villages)
- [ ] ⏳ District system (merchant, noble, mage, thieves)
- [ ] ⏳ Guild hall structures
- [ ] ⏳ Town walls and gates
- [ ] ⏳ Town NPC population (100+)
- [ ] ⏳ Town market squares

#### Dungeons
- [ ] ⏳ Dungeon entrance placement algorithm
- [ ] ⏳ Entrance types (cave mouths, ruins, mine shafts, crypts, towers)
- [ ] ⏳ Visible entrance structures in overworld
- [ ] ⏳ Entrance difficulty indicators
- [ ] ⏳ Link overworld entrances to instanced dungeons

#### Natural Structures
- [ ] ⏳ Cave system generation (underground)
- [ ] ⏳ Ravine generation (surface cracks)
- [ ] ⏳ Ancient ruins (scattered structures)
- [ ] ⏳ Abandoned mines
- [ ] ⏳ Ore vein placement
- [ ] ⏳ Underground lakes and lava pools

### 5.3 World Persistence

- [ ] ⏳ Infinite world generation (seed-based)
- [ ] ⏳ Chunk save/load system
- [ ] ⏳ Block modification persistence
- [ ] ⏳ Structure state persistence
- [ ] ⏳ NPC state persistence
- [ ] ⏳ Time/weather/season persistence
- [ ] ⏳ Player claim system (anti-griefing)
- [ ] ⏳ Claim visualization

---

## Phase 6: Daggerfall-Style RPG Systems

### 6.1 Character System

#### Attributes
- [ ] ⏳ Create `CharacterStats` class
- [ ] ⏳ Implement 8 core attributes (STR, INT, WIL, AGI, END, PER, SPD, LCK)
- [ ] ⏳ Attribute point allocation on level up
- [ ] ⏳ Derived stats calculation (health, mana, stamina from attributes)
- [ ] ⏳ Attribute modifiers from equipment
- [ ] ⏳ Temporary attribute buffs/debuffs

#### Skills System
- [ ] ⏳ Create `SkillManager` class
- [ ] ⏳ Implement 18 skills with progress tracking
- [ ] ⏳ Skill improvement through use
- [ ] ⏳ Skill level multipliers for actions
- [ ] ⏳ Major/minor skill designation
- [ ] ⏳ Skill books for instant skill gains
- [ ] ⏳ Trainer NPCs for skill training

#### Leveling System
- [ ] ⏳ Experience point system
- [ ] ⏳ Level-up trigger and UI
- [ ] ⏳ Skill-based leveling (major skills contribute to level)
- [ ] ⏳ Perk/ability selection on level up
- [ ] ⏳ Level scaling for enemies and loot

#### Character Creation
- [ ] ⏳ Character creation screen
- [ ] ⏳ Race selection (human, elf, orc, etc.)
- [ ] ⏳ Class selection or custom class builder
- [ ] ⏳ Starting attribute allocation
- [ ] ⏳ Birth sign/zodiac selection (passive bonuses)
- [ ] ⏳ Appearance customization (if desired)

### 6.2 Inventory System

- [ ] ⏳ Create `InventoryManager` class
- [ ] ⏳ Grid-based inventory data structure
- [ ] ⏳ Weight-based carrying capacity
- [ ] ⏳ Item pickup and drop functionality
- [ ] ⏳ Item stacking for stackable items
- [ ] ⏳ Equipment slots (head, chest, legs, feet, hands, weapon, shield, rings, amulet)
- [ ] ⏳ Paper doll visualization
- [ ] ⏳ Inventory UI with Daggerfall aesthetic
- [ ] ⏳ Item tooltip system
- [ ] ⏳ Inventory sorting and filtering
- [ ] ⏳ Quick-access hotbar (9 slots)

### 6.3 Item System

#### Core Item Framework
- [ ] ⏳ Create `Item` base class
- [ ] ⏳ Item types (weapon, armor, consumable, material, misc)
- [ ] ⏳ Item rarity system (common, uncommon, rare, epic, legendary)
- [ ] ⏳ Item durability system
- [ ] ⏳ Item repair mechanics

#### Weapons
- [ ] ⏳ Weapon base class with damage, speed, range
- [ ] ⏳ Weapon types: swords, axes, maces, daggers, bows, staves
- [ ] ⏳ Material tiers (wood, iron, steel, silver, mithril, daedric)
- [ ] ⏳ Weapon skill requirements
- [ ] ⏳ Attack type modifiers (slash, thrust, overhead)

#### Armor
- [ ] ⏳ Armor base class with defense rating
- [ ] ⏳ Armor types: light (leather), medium (chainmail), heavy (plate)
- [ ] ⏳ Material tiers matching weapon tiers
- [ ] ⏳ Armor weight affects speed and stamina
- [ ] ⏳ Set bonuses for matching armor pieces

#### Consumables
- [ ] ⏳ Potion system (health, mana, stamina, buff potions)
- [ ] ⏳ Food system (hunger mechanic - optional)
- [ ] ⏳ Scrolls (single-use spell casting)
- [ ] ⏳ Potion effects and duration

### 6.4 Daggerfall-Style HUD

- [ ] ⏳ Design HUD layout mockup
- [ ] ⏳ Implement compass at top center
- [ ] ⏳ Health bar (red) at bottom left
- [ ] ⏳ Mana bar (blue) at bottom left
- [ ] ⏳ Stamina bar (yellow) at bottom left
- [ ] ⏳ Hotbar with 9 slots at bottom center
- [ ] ⏳ Mini-map or dungeon map indicator
- [ ] ⏳ Quest objective tracker
- [ ] ⏳ Active effects/buffs display
- [ ] ⏳ Current weapon/spell display
- [ ] ⏳ Cursor/crosshair for interaction

### 6.5 Menu Interfaces

- [ ] ⏳ Main menu (continue, new game, load, settings, quit)
- [ ] ⏳ Pause menu (resume, character, inventory, map, settings, quit)
- [ ] ⏳ Character sheet UI (stats, skills, effects)
- [ ] ⏳ Inventory UI with paper doll
- [ ] ⏳ Map/automap UI
- [ ] ⏳ Spell book UI
- [ ] ⏳ Settings/options menu
- [ ] ⏳ Dialogue interface
- [ ] ⏳ Merchant/trading interface
- [ ] ⏳ Daggerfall-style parchment/paper aesthetic

---

## Phase 7: Mining ## Phase 19: Mining & Building Building (Minecraft-Inspired)

### 7.1 Mining System

- [ ] ⏳ Implement block breaking mechanic
- [ ] ⏳ Block break animation and particles
- [ ] ⏳ Block hardness values
- [ ] ⏳ Tool effectiveness (pickaxe for stone, axe for wood, shovel for dirt)
- [ ] ⏳ Mining skill affects mining speed
- [ ] ⏳ Add blocks to inventory when mined
- [ ] ⏳ Drop items when breaking certain blocks (ore → ore items)
- [ ] ⏳ Fortune/efficiency tool enchantments

### 7.2 Building System

- [ ] ⏳ Implement block placement mechanic
- [ ] ⏳ Block placement preview
- [ ] ⏳ Collision detection for placement
- [ ] ⏳ Building skill affects placement speed/accuracy
- [ ] ⏳ Rotation for directional blocks
- [ ] ⏳ Multi-block structures (doors, beds, tables)
- [ ] ⏳ Scaffolding or temporary blocks

### 7.3 Block Types

#### Natural Blocks
- [ ] ⏳ Stone, Cobblestone, Smooth Stone
- [ ] ⏳ Dirt, Grass, Sand, Gravel
- [ ] ⏳ Wood logs (oak, pine, birch)
- [ ] ⏳ Ore blocks (iron, gold, silver, mithril, gems)
- [ ] ⏳ Water and lava blocks
- [ ] ⏳ Clay, ice, snow

#### Crafted Blocks
- [ ] ⏳ Wooden planks, stone bricks, brick blocks
- [ ] ⏳ Glass, stained glass
- [ ] ⏳ Torches, lanterns, candles
- [ ] ⏳ Ladders, stairs, slabs
- [ ] ⏳ Doors (wood, iron, steel)
- [ ] ⏳ Chests and storage containers
- [ ] ⏳ Crafting tables, forges, enchanting tables
- [ ] ⏳ Furniture blocks (decorative)

### 7.4 Tools

- [ ] ⏳ Implement tool system
- [ ] ⏳ Tool types: pickaxe, axe, shovel, hoe
- [ ] ⏳ Tool material tiers (wood, stone, iron, steel, mithril)
- [ ] ⏳ Tool durability and breakage
- [ ] ⏳ Tool enchantments
- [ ] ⏳ Tool crafting recipes

---

## Phase 8: Farming System (Stardew Valley-Inspired)

### 8.1 Crop System

- [ ] ⏳ Implement tilling mechanic (hoe tool)
- [ ] ⏳ Tilled soil block type
- [ ] ⏳ Seed item types (spring, summer, autumn)
- [ ] ⏳ Plant seeds on tilled soil
- [ ] ⏳ Crop growth stages (visual progression)
- [ ] ⏳ Crop growth timer system
- [ ] ⏳ Season-appropriate planting requirements
- [ ] ⏳ Crop death on season change
- [ ] ⏳ Harvest mechanic (break mature crop)
- [ ] ⏳ Crop yield and quality system
- [ ] ⏳ Multi-harvest crops (tomatoes, berries, corn)
- [ ] ⏳ Giant crops (3x3 rare spawns)

### 8.2 Watering & Soil

- [ ] ⏳ Watering can tool
- [ ] ⏳ Soil moisture system (dry → wet)
- [ ] ⏳ Daily moisture decay (crops need water)
- [ ] ⏳ Rain auto-waters crops
- [ ] ⏳ Fertilizer system (speed, quality)
- [ ] ⏳ Soil quality levels
- [ ] ⏳ Fertilizer crafting recipes

### 8.3 Sprinklers & Automation

- [ ] ⏳ Basic sprinkler (4 tiles, + pattern)
- [ ] ⏳ Quality sprinkler (8 tiles, 3x3)
- [ ] ⏳ Iridium sprinkler (24 tiles, 5x5)
- [ ] ⏳ Automatic daily watering
- [ ] ⏳ Sprinkler crafting recipes
- [ ] ⏳ Scarecrow (prevents crow damage)

### 8.4 Animals & Ranching

- [ ] ⏳ Chicken coop structure (buildable)
- [ ] ⏳ Barn structure (buildable)
- [ ] ⏳ Animal spawning system
- [ ] ⏳ Chickens (eggs daily)
- [ ] ⏳ Cows (milk daily)
- [ ] ⏳ Sheep (wool every 3 days)
- [ ] ⏳ Pigs (truffles when outside)
- [ ] ⏳ Animal feeding system (hay, grass)
- [ ] ⏳ Animal happiness/friendship system
- [ ] ⏳ Pet interaction (increases happiness)
- [ ] ⏳ Product quality based on happiness
- [ ] ⏳ Silo structure (hay storage)
- [ ] ⏳ Hay cutting from grass

### 8.5 Artisan Processing

- [ ] ⏳ Keg (crops → wine, beer, juice)
- [ ] ⏳ Preserves jar (crops → jams, pickles)
- [ ] ⏳ Cheese press (milk → cheese)
- [ ] ⏳ Mayonnaise machine (eggs → mayo)
- [ ] ⏳ Loom (wool → cloth)
- [ ] ⏳ Oil maker (sunflowers, corn → oil)
- [ ] ⏳ Processing time system
- [ ] ⏳ Quality preservation in processing
- [ ] ⏳ Artisan goods value multipliers

### 8.6 Greenhouse

- [ ] ⏳ Greenhouse structure (buildable or quest reward)
- [ ] ⏳ Year-round crop growth inside
- [ ] ⏳ No seasonal death for greenhouse crops
- [ ] ⏳ Slightly faster growth rate
- [ ] ⏳ Limited interior space

### 8.7 Farming Skills

- [ ] ⏳ Farming skill XP system
- [ ] ⏳ Gain XP from harvesting crops and animal products
- [ ] ⏳ Farming level perks (0-100)
  - [ ] ⏳ Level 10: Crops sell for 5% more
  - [ ] ⏳ Level 20: Quality sprinkler recipe
  - [ ] ⏳ Level 30: 10% faster growth
  - [ ] ⏳ Level 40: Iridium sprinkler recipe
  - [ ] ⏳ Level 50: Higher quality chance
  - [ ] ⏳ Level 60: Crops sell for 10% more
  - [ ] ⏳ Level 70: Animal products worth more
  - [ ] ⏳ Level 80: Deluxe barn/coop recipes
  - [ ] ⏳ Level 90: Greenhouse blueprint
  - [ ] ⏳ Level 100: Chance for double harvest

### 8.8 Farming Integration

- [ ] ⏳ Seed merchants in villages/towns
- [ ] ⏳ Sell crops to merchants
- [ ] ⏳ Crop prices fluctuate by season
- [ ] ⏳ Cooking recipes use crops
- [ ] ⏳ Alchemy recipes use crops/flowers
- [ ] ⏳ "Deliver crops" quests
- [ ] ⏳ Festival crop competitions
- [ ] ⏳ Multiplayer shared farm space
- [ ] ⏳ Gifting crops to players/NPCs

### 8.9 Advanced Farming

- [ ] ⏳ Seed maker (crop → seeds)
- [ ] ⏳ Crop mutations (rare hybrids)
- [ ] ⏳ Ancient fruit (rare, year-round, high value)
- [ ] ⏳ Sweet gem berry (most valuable)
- [ ] ⏳ Community center crop bundles
- [ ] ⏳ Seasonal festivals with farming events
- [ ] ⏳ Farm animals can breed
- [ ] ⏳ Animal variants (brown chicken, white cow, etc.)

---

## Phase 9: Combat & Magic Systems

### 9.1 Melee Combat

- [ ] ⏳ First-person melee attack system
- [ ] ⏳ Directional attacks (slash, thrust, overhead) based on mouse movement
- [ ] ⏳ Stamina consumption for attacks
- [ ] ⏳ Weapon swing animations
- [ ] ⏳ Hit detection and damage application
- [ ] ⏳ Weapon reach/range
- [ ] ⏳ Attack speed based on weapon and agility
- [ ] ⏳ Critical hit system (luck-based)
- [ ] ⏳ Weapon skill affects damage and accuracy
- [ ] ⏳ Dual-wielding support

### 8.2 Blocking ### 16.2 Blocking & Defense Defense

- [ ] ⏳ Shield blocking mechanic (hold right-click)
- [ ] ⏳ Block effectiveness based on shield type and skill
- [ ] ⏳ Stamina drain while blocking
- [ ] ⏳ Timed parry system (perfect block)
- [ ] ⏳ Block animations
- [ ] ⏳ Shield bash ability

### 9.3 Ranged Combat

- [ ] ⏳ Bow and arrow system
- [ ] ⏳ Draw and release mechanic (hold to charge)
- [ ] ⏳ Arrow trajectory and physics
- [ ] ⏳ Crossbow variant (faster reload, no charge)
- [ ] ⏳ Ammunition system (arrows in inventory)
- [ ] ⏳ Archery skill affects accuracy and damage
- [ ] ⏳ Different arrow types (fire, poison, etc.)

### 9.4 Magic System

#### Spell Framework
- [ ] ⏳ Create `Spell` base class
- [ ] ⏳ Spell schools (Destruction, Restoration, Alteration, Illusion)
- [ ] ⏳ Mana cost calculation
- [ ] ⏳ Spell casting animation
- [ ] ⏳ Spell projectile system
- [ ] ⏳ Spell effect application
- [ ] ⏳ Magic skill affects spell power and cost

#### Destruction Spells
- [ ] ⏳ Fireball (explosive projectile)
- [ ] ⏳ Lightning Bolt (instant hit)
- [ ] ⏳ Ice Spike (slowing projectile)
- [ ] ⏳ Fire Stream (continuous damage)
- [ ] ⏳ Area-of-effect spells

#### Restoration Spells
- [ ] ⏳ Heal Self
- [ ] ⏳ Heal Other
- [ ] ⏳ Cure Disease/Poison
- [ ] ⏳ Fortify Attribute (temporary buffs)
- [ ] ⏳ Regeneration over time

#### Alteration Spells
- [ ] ⏳ Light (create light source)
- [ ] ⏳ Levitate (flight/hovering)
- [ ] ⏳ Open Lock (unlock chests/doors)
- [ ] ⏳ Water Walking
- [ ] ⏳ Shield (damage absorption)

#### Illusion Spells
- [ ] ⏳ Invisibility
- [ ] ⏳ Calm (reduce enemy aggression)
- [ ] ⏳ Fear (make enemies flee)
- [ ] ⏳ Charm (improve NPC disposition)
- [ ] ⏳ Detect Life

#### Spell Management
- [ ] ⏳ Spell book UI
- [ ] ⏳ Spell learning from tomes
- [ ] ⏳ Spell hotkeys
- [ ] ⏳ Spell crafting system (advanced feature)

### 9.5 Combat Effects

- [ ] ⏳ Damage numbers display
- [ ] ⏳ Blood/hit particle effects
- [ ] ⏳ Screen shake on hit
- [ ] ⏳ Hit sounds and feedback
- [ ] ⏳ Knockback system
- [ ] ⏳ Status effects (poison, fire, frost, bleeding)
- [ ] ⏳ Death animations
- [ ] ⏳ Ragdoll physics (optional)

---

## Phase 10: Enemy System

### 10.1 Enemy AI Framework

- [ ] ⏳ Create `Enemy` base class
- [ ] ⏳ Enemy stats (health, damage, speed, armor)
- [ ] ⏳ AI state machine (idle, patrol, chase, attack, flee)
- [ ] ⏳ Pathfinding through voxel terrain
- [ ] ⏳ Line-of-sight detection
- [ ] ⏳ Hearing system (detect player noise)
- [ ] ⏳ Group AI (enemies coordinate attacks)
- [ ] ⏳ Enemy level scaling

### 10.2 Enemy Types

#### Tier 1 Enemies (Level 1-5)
- [ ] ⏳ Rat (weak, fast)
- [ ] ⏳ Bat (flying, weak)
- [ ] ⏳ Wolf (moderate, pack behavior)
- [ ] ⏳ Goblin (humanoid, basic weapons)
- [ ] ⏳ Bandit (humanoid, various weapons)
- [ ] ⏳ Skeleton (undead, melee)
- [ ] ⏳ Zombie (undead, slow, high health)

#### Tier 2 Enemies (Level 6-15)
- [ ] ⏳ Orc (strong melee)
- [ ] ⏳ Troll (high health, regeneration)
- [ ] ⏳ Ghost (incorporeal, magic attacks)
- [ ] ⏳ Wraith (undead, life drain)
- [ ] ⏳ Giant Spider (poison attacks)
- [ ] ⏳ Giant Scorpion (armored, poison)
- [ ] ⏳ Dark Cultist (magic user)

#### Tier 3 Enemies (Level 16-25)
- [ ] ⏳ Vampire (lifesteal, fast)
- [ ] ⏳ Dark Knight (heavy armor, strong attacks)
- [ ] ⏳ Demon (fire attacks, high damage)
- [ ] ⏳ Lich (powerful magic, undead)
- [ ] ⏳ Gargoyle (flying, stone skin)
- [ ] ⏳ Daedra (varied abilities)

#### Boss Enemies
- [ ] ⏳ Dragon (flying boss, breath attacks)
- [ ] ⏳ Ancient Lich (magic boss)
- [ ] ⏳ Demon Lord (melee boss)
- [ ] ⏳ Vampire Lord (hybrid boss)

### 10.3 Enemy Features

- [ ] ⏳ Enemy animations (idle, walk, attack, death)
- [ ] ⏳ Enemy sounds (growls, attacks, death)
- [ ] ⏳ Loot drops on death
- [ ] ⏳ Experience points on kill
- [ ] ⏳ Rare enemy variants (elites with better loot)
- [ ] ⏳ Enemy spawn system
- [ ] ⏳ Enemy respawn timers

---

## Phase 11: Dungeon Generation System

### 11.1 Dungeon Architecture

- [ ] ⏳ Create `DungeonGenerator` class
- [ ] ⏳ Room-based generation algorithm
- [ ] ⏳ Corridor connection system
- [ ] ⏳ Multi-level dungeons (stairs up/down)
- [ ] ⏳ Room templates (varied layouts)
- [ ] ⏳ Ensure all rooms are accessible
- [ ] ⏳ Dead-end rooms with rewards
- [ ] ⏳ Secret room generation

### 11.2 Dungeon Features

- [ ] ⏳ Entrance/exit markers
- [ ] ⏳ Treasure chests (locked and unlocked)
- [ ] ⏳ Locked doors (require keys or lockpicking)
- [ ] ⏳ Pressure plate traps
- [ ] ⏳ Arrow traps
- [ ] ⏳ Spike pits
- [ ] ⏳ Lava/water hazards
- [ ] ⏳ Collapsing floors
- [ ] ⏳ Boss rooms (larger, special design)
- [ ] ⏳ Lore objects (books, tablets)

### 11.3 Dungeon Types

- [ ] ⏳ Crypts (undead theme, dark)
- [ ] ⏳ Caves (natural formations, wildlife)
- [ ] ⏳ Ancient Ruins (stone architecture, magic enemies)
- [ ] ⏳ Abandoned Mines (ore veins, industrial hazards)
- [ ] ⏳ Sewers (water, rats, bandits)
- [ ] ⏳ Towers (vertical layout, multiple floors)

### 11.4 Dungeon Difficulty

- [ ] ⏳ Difficulty scaling based on depth
- [ ] ⏳ Higher-tier enemies in deeper levels
- [ ] ⏳ Better loot in harder dungeons
- [ ] ⏳ Environmental difficulty (less light, more traps)
- [ ] ⏳ Dungeon level indicator

---

## Phase 12: Loot & Economy

### 12.1 Loot System

- [ ] ⏳ Create `LootTable` system
- [ ] ⏳ Randomized loot generation
- [ ] ⏳ Rarity-based drop rates
- [ ] ⏳ Level-appropriate loot
- [ ] ⏳ Chest loot tables
- [ ] ⏳ Enemy-specific loot tables
- [ ] ⏳ Boss guaranteed rare loot
- [ ] ⏳ Gold/currency drops

### 12.2 Currency System

- [ ] ⏳ Gold currency
- [ ] ⏳ Currency display in UI
- [ ] ⏳ Pick up gold from enemies/chests
- [ ] ⏳ Store gold value on items

### 12.3 Merchant System

- [ ] ⏳ Create `Merchant` NPC type
- [ ] ⏳ Merchant inventory system
- [ ] ⏳ Buy interface
- [ ] ⏳ Sell interface
- [ ] ⏳ Merchant gold limits
- [ ] ⏳ Personality affects prices
- [ ] ⏳ Merchant inventory refresh
- [ ] ⏳ Specialized merchants (blacksmith, alchemist, general goods)

---

## Phase 13: Crafting System

### 13.1 Crafting Framework

- [ ] ⏳ Create `CraftingSystem` class
- [ ] ⏳ Recipe data structure
- [ ] ⏳ Crafting UI interface
- [ ] ⏳ Material checking and consumption
- [ ] ⏳ Crafting skill requirements
- [ ] ⏳ Success/failure system (skill-based)
- [ ] ⏳ Recipe discovery system

### 13.2 Crafting Stations

- [ ] ⏳ Crafting Table (general crafting)
- [ ] ⏳ Forge (weapons, armor, ingots)
- [ ] ⏳ Alchemy Lab (potions)
- [ ] ⏳ Enchanting Table (enchantments)
- [ ] ⏳ Tanning Rack (leather processing)

### 13.3 Recipes

#### Smithing Recipes
- [ ] ⏳ Weapons (by material tier)
- [ ] ⏳ Armor pieces (by material tier)
- [ ] ⏳ Tools (pickaxe, axe, shovel)
- [ ] ⏳ Ingot smelting from ore

#### Alchemy Recipes
- [ ] ⏳ Health potions (minor, normal, major)
- [ ] ⏳ Mana potions
- [ ] ⏳ Stamina potions
- [ ] ⏳ Buff potions (strength, speed, etc.)
- [ ] ⏳ Resistance potions (fire, frost, poison)
- [ ] ⏳ Poisons (for weapon coating)

#### General Crafting
- [ ] ⏳ Torches
- [ ] ⏳ Arrows
- [ ] ⏳ Building blocks
- [ ] ⏳ Furniture
- [ ] ⏳ Doors, chests, containers

#### Enchanting
- [ ] ⏳ Weapon enchantments
- [ ] ⏳ Armor enchantments
- [ ] ⏳ Soul gems as reagents
- [ ] ⏳ Enchantment strength levels

---

## Phase 14: NPC & Dialogue System

### 14.1 NPC Framework

- [ ] ⏳ Create `NPC` base class
- [ ] ⏳ NPC pathfinding and movement
- [ ] ⏳ NPC daily schedules (optional)
- [ ] ⏳ NPC dialogue trees
- [ ] ⏳ NPC relationship/disposition system
- [ ] ⏳ Named vs. generic NPCs

### 14.2 NPC Types

- [ ] ⏳ Merchants
- [ ] ⏳ Trainers (skill training)
- [ ] ⏳ Quest givers
- [ ] ⏳ Guards
- [ ] ⏳ Innkeepers
- [ ] ⏳ Commoners

### 14.3 Dialogue System

- [ ] ⏳ Dialogue UI (Daggerfall-style)
- [ ] ⏳ Branching dialogue options
- [ ] ⏳ Personality-based responses
- [ ] ⏳ Quest dialogue triggers
- [ ] ⏳ Rumors and lore
- [ ] ⏳ Persuasion mini-game (optional)

### 13.4 Towns ### 17.4 Towns & Villages Villages

- [ ] ⏳ Procedural village generation
- [ ] ⏳ Pre-built town structures
- [ ] ⏳ Inns (rest, buy food)
- [ ] ⏳ Shops (merchants)
- [ ] ⏳ Guild halls
- [ ] ⏳ Town guards
- [ ] ⏳ Safe zones (no combat)

---

## Phase 15: Quest System

### 15.1 Quest Framework

- [ ] ⏳ Create `Quest` class
- [ ] ⏳ Quest objective tracking
- [ ] ⏳ Quest log UI
- [ ] ⏳ Quest givers and turn-in
- [ ] ⏳ Quest rewards (XP, gold, items)
- [ ] ⏳ Quest stages and progression

### 15.2 Quest Types

- [ ] ⏳ Kill quests (defeat X enemies)
- [ ] ⏳ Fetch quests (retrieve item from dungeon)
- [ ] ⏳ Delivery quests (take item to NPC)
- [ ] ⏳ Escort quests (protect NPC)
- [ ] ⏳ Exploration quests (discover location)
- [ ] ⏳ Bounty quests (hunt specific enemy)

### 15.3 Main Quest Line (Optional)

- [ ] ⏳ Overarching storyline
- [ ] ⏳ Unique quest rewards
- [ ] ⏳ Story dungeons
- [ ] ⏳ Climactic boss fights

### 15.4 Guild Quests (Future)

- [ ] ⏳ Fighters Guild questline
- [ ] ⏳ Mages Guild questline
- [ ] ⏳ Thieves Guild questline
- [ ] ⏳ Guild ranks and progression

---

## Phase 16: Saving & Persistence

### 16.1 Save System

- [ ] ⏳ Create save file format
- [ ] ⏳ Save player character data
- [ ] ⏳ Save inventory and equipment
- [ ] ⏳ Save world/chunk modifications
- [ ] ⏳ Save quest progress
- [ ] ⏳ Save NPC states
- [ ] ⏳ Multiple save slots
- [ ] ⏳ Auto-save functionality
- [ ] ⏳ Save on exit

### 16.2 Load System

- [ ] ⏳ Load character data
- [ ] ⏳ Load world state
- [ ] ⏳ Load quest progress
- [ ] ⏳ Continue from last save
- [ ] ⏳ Load game menu

---

## Phase 17: Audio & Music

### 17.1 Sound Effects

- [ ] ⏳ Footstep sounds (varied by surface)
- [ ] ⏳ Weapon swing and impact sounds
- [ ] ⏳ Magic casting sounds
- [ ] ⏳ Enemy sounds (attacks, deaths, idle)
- [ ] ⏳ Mining/breaking block sounds
- [ ] ⏳ Placing block sounds
- [ ] ⏳ Ambient dungeon sounds
- [ ] ⏳ UI interaction sounds
- [ ] ⏳ Door opening/closing
- [ ] ⏳ Chest opening

### 17.2 Music

- [ ] ⏳ Main menu theme
- [ ] ⏳ Surface exploration music
- [ ] ⏳ Town/village music
- [ ] ⏳ Dungeon exploration tracks (by type)
- [ ] ⏳ Combat music
- [ ] ⏳ Boss battle music
- [ ] ⏳ Victory/level up fanfare
- [ ] ⏳ Ambient tracks for different biomes

### 17.3 Audio Systems

- [ ] ⏳ 3D positional audio
- [ ] ⏳ Volume controls (master, music, SFX, ambient)
- [ ] ⏳ Audio occlusion (muffle through walls)
- [ ] ⏳ Music transitions and layering

---

## Phase 18: Polish & Optimization

### 18.1 Performance Optimization

- [ ] ⏳ Profile and optimize chunk generation
- [ ] ⏳ Optimize mesh building (greedy meshing)
- [ ] ⏳ LOD (Level of Detail) for distant chunks
- [ ] ⏳ Frustum culling
- [ ] ⏳ Occlusion culling
- [ ] ⏳ Optimize lighting calculations
- [ ] ⏳ Memory profiling and leak fixes
- [ ] ⏳ Reduce draw calls
- [ ] ⏳ Optimize AI pathfinding
- [ ] ⏳ Thread pool management

### 18.2 Graphics Polish

- [ ] ⏳ Particle effects (magic, impacts, weather)
- [ ] ⏳ Weather system (rain, snow, fog)
- [ ] ⏳ Water shader improvements
- [ ] ⏳ Skybox variations
- [ ] ⏳ Post-processing effects (bloom, ambient occlusion)
- [ ] ⏳ Animation polish
- [ ] ⏳ Visual feedback improvements

### 18.3 UI/UX Polish

- [ ] ⏳ Consistent UI aesthetic
- [ ] ⏳ Tooltips everywhere
- [ ] ⏳ Keybinding customization
- [ ] ⏳ Accessibility options (colorblind modes, text size)
- [ ] ⏳ Tutorial/help system
- [ ] ⏳ Loading screens with tips
- [ ] ⏳ Smooth transitions between menus

### 18.4 Bug Fixes

- [ ] 🐛 Fix current face rendering bug
- [ ] ⏳ Collision detection edge cases
- [ ] ⏳ Save/load edge cases
- [ ] ⏳ AI pathfinding edge cases
- [ ] ⏳ Multiplayer sync issues (if applicable)
- [ ] ⏳ Item duplication exploits
- [ ] ⏳ Terrain generation artifacts

---

## Phase 19: Content Expansion

### 19.1 More Items

- [ ] ⏳ 50+ unique weapons
- [ ] ⏳ 50+ armor pieces
- [ ] ⏳ 30+ spells
- [ ] ⏳ 20+ potions
- [ ] ⏳ Unique/legendary items
- [ ] ⏳ Artifact items (special powers)

### 19.2 More Enemies

- [ ] ⏳ 30+ enemy types total
- [ ] ⏳ 10+ boss variations
- [ ] ⏳ Rare enemy spawns

### 19.3 More Dungeons

- [ ] ⏳ Unique hand-crafted dungeons
- [ ] ⏳ Mega-dungeons (large, multi-level)
- [ ] ⏳ Themed dungeon sets

### 19.4 More Biomes

- [ ] ⏳ Jungle biome
- [ ] ⏳ Swamp biome
- [ ] ⏳ Tundra/snow biome
- [ ] ⏳ Volcanic biome
- [ ] ⏳ Mushroom biome
- [ ] ⏳ Floating islands

---

## Phase 20: Advanced Features (Post-Launch)

### 20.1 Modding Support

- [ ] ⏳ Mod loading system
- [ ] ⏳ Server-side mod support
- [ ] ⏳ Custom item support
- [ ] ⏳ Custom enemy support
- [ ] ⏳ Custom spell support
- [ ] ⏳ Custom dungeon support
- [ ] ⏳ Custom biome support
- [ ] ⏳ Modding API documentation
- [ ] ⏳ Modding tools

### 20.2 Advanced Magic

- [ ] ⏳ Spell crafting system
- [ ] ⏳ Combine spell effects
- [ ] ⏳ Custom spell naming
- [ ] ⏳ Spell research mechanic
- [ ] ⏳ Spell experimentation (risk/reward)

### 20.3 Player Housing

- [ ] ⏳ Purchasable houses in towns
- [ ] ⏳ House customization (furniture, decorations)
- [ ] ⏳ Expanded storage chests
- [ ] ⏳ Decoration placement system
- [ ] ⏳ Trophy displays (boss kills, achievements)
- [ ] ⏳ House upgrades

### 20.4 Advanced NPCs

- [ ] ⏳ Companion system (follower NPCs)
- [ ] ⏳ Faction reputation system
- [ ] ⏳ NPC relationships and friendships
- [ ] ⏳ Marriage system (optional)
- [ ] ⏳ NPC complex daily schedules
- [ ] ⏳ Dynamic NPC reactions to world events

### 20.5 Additional Gameplay Features

- [ ] ⏳ Farming system (crops influenced by seasons)
- [ ] ⏳ Animal husbandry (breeding, raising livestock)
- [ ] ⏳ Fishing system
- [ ] ⏳ Cooking system
- [ ] ⏳ Ocean/underwater content (boats, diving, sea creatures)
- [ ] ⏳ Boss raid instances (multiplayer)
- [ ] ⏳ PvP arenas (server configurable)
- [ ] ⏳ World events (festivals, invasions, meteor showers)
- [ ] ⏳ Proximity voice chat

---

## Current Priority Tasks (Next Sprint)

### Immediate Priorities (Phase 1 & 2)
1. **Fix face rendering issues** - High priority bug (Phase 1)
2. **Implement texture atlas system** - Foundation for swappable textures (Phase 2)
3. **Create default texture atlas** - Vanilla textures (Phase 2)
4. **Resource pack loader** - JSON-based UV mapping (Phase 2)

### Early Gameplay (Phase 3 & 6)
5. **Day/night cycle** - Time progression system (Phase 3)
6. **Basic weather** - Rain and clear weather (Phase 3)
7. **Design and implement Daggerfall-style HUD** - With time/season/weather display (Phase 6)
8. **Character stats system** - Foundation for RPG mechanics (Phase 6)

### Core Loop (Phase 7)
9. **Implement basic mining and block placement** - Core gameplay loop
10. **Create inventory system** - Essential for item management
11. **Simple crafting** - Basic recipes

### Multiplayer Foundation (Phase 4)
12. **Basic networking** - Client-server architecture
13. **Player synchronization** - Position and block changes
14. **Text chat** - Communication system

---

## Milestone Goals

### Milestone 1: Living World Foundation
- ✅ Voxel terrain working
- ⏳ Texture atlas system (swappable textures)
- ⏳ Day/night cycle functional
- ⏳ Weather system (rain, snow, clear)
- ⏳ Seasonal system working
- ⏳ Basic biome generation (plains, forest, desert, mountain)
- ⏳ Time/season/weather display on HUD

**Target:** Establish living, breathing world with dynamic systems

### Milestone 2: Multiplayer Core
- ⏳ Client-server networking functional
- ⏳ Player synchronization working
- ⏳ Block place/break synced across players
- ⏳ Text chat system
- ⏳ Server browser
- ⏳ 2-4 players stable
- ⏳ Time/weather synced across clients

**Target:** Stable multiplayer foundation for co-op play

### Milestone 3: Overworld Exploration
- ⏳ Multiple biomes generating
- ⏳ Village generation working
- ⏳ Dungeon entrances scattered in world
- ⏳ Natural structures (caves, ravines, ruins)
- ⏳ World persistence (save/load)
- ⏳ Fast travel system

**Target:** Rich explorable overworld with points of interest

### Milestone 4: RPG Systems & Building
- ⏳ Character stats and skills
- ⏳ Inventory and equipment
- ⏳ Mining and building functional
- ⏳ Crafting system (basic recipes)
- ⏳ Daggerfall-style HUD with all displays
- ⏳ Menu interfaces (character, inventory, crafting)

**Target:** Core RPG mechanics and building gameplay

### Milestone 5: Combat & Dungeons
- ⏳ Melee, ranged, and magic combat
- ⏳ 10+ enemy types with AI
- ⏳ Dungeon generation (instanced)
- ⏳ 3+ dungeon types
- ⏳ Boss enemies
- ⏳ Loot system
- ⏳ Multiplayer dungeon raiding

**Target:** Engaging combat and dungeon crawling

### Milestone 6: NPCs & Content
- ⏳ NPC system with dialogue
- ⏳ Merchants and trading
- ⏳ Quest system
- ⏳ Towns with NPCs
- ⏳ Guild halls
- ⏳ 30+ enemies, 50+ items, 20+ spells

**Target:** Populated world with RPG depth

### Milestone 7: Polish & Launch
- ⏳ Performance optimized (60 FPS target)
- ⏳ Audio and music complete
- ⏳ UI polished
- ⏳ Tutorial system
- ⏳ Server administration tools
- ⏳ Resource pack support complete

**Target:** Polished 1.0 release ready for players

---

## Notes

- **Multiplayer First:** Design all systems with multiplayer in mind from the start
- **Living World:** Prioritize dynamic systems (seasons, weather, time) for immersive experience
- **Texture Atlas Early:** Get resource pack system working early for modding community
- **Iterate on Feel:** Combat, mining, and building should feel satisfying before moving to complex systems
- **Daggerfall Aesthetic:** Keep the UI design true to Daggerfall's look and feel
- **Performance First:** Don't add features at the cost of performance, especially for multiplayer
- **Test Frequently:** Playtest each system thoroughly, both solo and multiplayer
- **Community Feedback:** Once alpha is playable, gather feedback to guide priorities
- **Server Stability:** Network code must be robust and cheat-resistant

---

## Resources & References

- **Daggerfall Unity:** For UI/UX inspiration and RPG mechanics
- **Minecraft Beta 1.7:** For texture atlas system reference
- **Minecraft:** For voxel mechanics, world generation, and feel
- **Godot 4.x Networking:** Built-in multiplayer support
- **Godot Voxel Tools:** Community resources for voxel rendering
- **Game Design Document:** See `project_management/game_design_document.md` for detailed design
- **ENet/WebRTC:** Potential networking libraries for multiplayer

---

**Last Updated:** 2025-11-07
**Project Scope:** Multiplayer voxel RPG (Minecraft + Daggerfall + Dynamic World)
**Current Phase:** Phase 1 Complete → Phase 2 (Texture Atlas) & Phase 3 (Dynamic Systems) Next
**Next Review:** After Milestone 1 completion (Living World Foundation)
