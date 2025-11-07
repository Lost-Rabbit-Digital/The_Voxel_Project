# Steel and Cube - Game Design Document

## High-Level Vision

**Steel and Cube** is a multiplayer first-person voxel RPG that combines the sandbox building and exploration of **Alpha Minecraft** with the deep RPG mechanics and interface design of **The Elder Scrolls II: Daggerfall**. Players will explore a vast procedurally generated overworld filled with biomes, scattered dungeons, villages, and NPCs. Together with friends, they will mine resources, build settlements, engage in classic RPG combat, develop their characters through a robust skill system, and experience a living world with dynamic seasons, weather, and the passage of time.

### Core Pillars

1. **Multiplayer Adventure** - Play solo or with friends in a shared persistent world
2. **Classic RPG Depth** - Character stats, skills, leveling, and meaningful progression
3. **Living Voxel World** - Minecraft-like overworld with building, seasons, weather, and day/night cycles
4. **Dungeon Crawling** - Discover scattered dungeons filled with enemies, traps, and loot
5. **Immersive First-Person Interface** - Daggerfall-inspired HUD and UI design
6. **Community & Lore** - Villages, towns, and NPCs that bring the world to life

---

## Game Overview

### Genre
Multiplayer First-Person Voxel RPG / Sandbox Builder / Dungeon Crawler

### Target Audience
- Fans of classic dungeon crawlers (Daggerfall, Arena, Ultima Underworld)
- Minecraft players seeking deeper RPG mechanics and multiplayer adventure
- Players who enjoy character progression and skill-based gameplay
- Groups of friends looking for co-op survival/building/RPG experiences

### Platform
- **Engine:** Godot 4.5
- **Distribution:** Steam (PC: Windows/Linux/Mac)
- **Release Target:** Steam Early Access → Full Release

### Player Count
- **Single Player** - Full experience solo with NPC companions
- **Cooperative Multiplayer** - 2-8 players per session
- **Multiplayer Model:** Terraria-style (Host or Join from main menu)
  - **Host:** Select character and world, others join your session
  - **Join:** Enter IP/browse LAN, select character to join host's world
  - **Multiple Characters:** Each player can create and manage multiple characters
  - **Multiple Worlds:** Each player can create and manage multiple worlds

### Art Style
- Low-poly voxel aesthetic (similar to Alpha Minecraft)
- Daggerfall-inspired UI elements and color palette
- Atmospheric lighting with dynamic shadows
- Retro-modern hybrid visual approach

---

## Gameplay Systems

### 1. Core Gameplay Loop

**Single Player / Multiplayer Loop:**
```
Explore Overworld → Mine Resources → Build Base/Settlement → Craft Equipment →
→ Discover Dungeon/Village → Combat/Trade → Collect Loot/Quests →
→ Return to Base → Upgrade Character/Base → Explore Further
```

**Seasonal/Time Progression:**
```
Spring (Planting) → Summer (Exploration) → Autumn (Harvest) → Winter (Dungeons) →
→ Year Passes → World Evolves → New Challenges Emerge
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

### 10. Multiplayer System (Terraria-Style)

#### Host/Join Model
- **Main Menu Options:**
  - **Single Player** - Play alone offline
  - **Host & Play** - Host a world and play while others join
  - **Join Game** - Join someone else's hosted world

#### Character & World Selection
- **Multiple Characters:**
  - Each player maintains separate character saves
  - Character select screen before starting/joining
  - Characters persist across worlds (Terraria-style)
  - Character data: Stats, inventory, equipment, skills, XP

- **Multiple Worlds:**
  - Host selects which world to load when hosting
  - World select screen shows world name, seed, playtime, last played
  - Create new world or load existing
  - World data: Terrain, structures, time/season, NPC states, block changes

#### Host & Play Mode
- **Host Player** acts as server
- Select character → Select world → Start hosting
- Other players can join via LAN discovery or direct IP
- Host has admin privileges (kick players, etc.)
- World saves when host quits
- Session ends when host quits (all players disconnect)

#### Join Game Mode
- Select character → Browse available games or enter IP
- **LAN Discovery** - Auto-detect games on local network
- **Direct IP** - Enter host's IP address and port
- Join host's world with your character
- Character saves separately when you quit
- Can rejoin same world later if host resumes

#### Server Architecture
- **Peer-to-Peer** - Host acts as server (default)
- **Dedicated Server** - Optional headless server for 24/7 worlds (advanced)

#### Multiplayer Features
- **Shared World** - All players exist in the same persistent overworld
- **Collaborative Building** - Build settlements together
- **Party System** - Form groups for dungeon raids
- **Shared Quests** - Complete objectives together
- **PvP Zones** - Optional combat areas (server configurable)
- **Trading** - Exchange items between players
- **Server-Side Saving** - World persists when players log off

#### Synchronization
- **Player Positions** - Real-time position sync
- **Block Changes** - Instant building/mining sync across all clients
- **Combat** - Server-authoritative combat to prevent cheating
- **Inventory** - Server-side inventory management
- **World State** - Time, weather, and season sync across all players
- **Entity Spawning** - Server controls enemy/NPC spawns

#### Communication
- **Text Chat** - Global, local, and party channels
- **Voice Chat** - Optional proximity-based voice (future feature)
- **Emotes** - Character gestures and animations
- **Markers** - Place waypoints visible to party members

#### Server Administration
- **Whitelist/Blacklist** - Control who can join
- **Operator Permissions** - Trusted players with admin commands
- **Backup System** - Regular world backups
- **Config Files** - Customize world settings, difficulty, PvP rules
- **Mod Support** - Server-side mods for custom content

### 11. Texture Atlas System (Minecraft Beta 1.7 Style)

#### Atlas Architecture
- **Single Texture Atlas** - All block and item textures in one file (e.g., 256x256 or 512x512)
- **UV Mapping** - Each block face maps to specific atlas coordinates
- **16x16 Base Resolution** - Individual textures are 16x16 pixels (classic Minecraft style)
- **Minimal Draw Calls** - Single texture binding for all terrain meshes

#### Texture Atlas Layout
```
┌─────────────────────────────────────┐
│ Dirt│Grass│Stone│Sand│Gravel│ Ore  │
├─────┼─────┼─────┼─────┼──────┼──────┤
│ Wood│Plank│Brick│Glass│Torch │Leaves│
├─────┼─────┼─────┼─────┼──────┼──────┤
│ Iron│Gold │Silver│Mithril│Daedric│ │
├─────┼─────┼─────┼─────┼──────┼──────┤
│ UI  │Items│Armor│Weapons│Mobs │etc. │
└─────────────────────────────────────┘
```

#### Resource Pack System (Swappable Textures)
- **Resource Pack Folder** - Users can drop custom texture atlases
- **JSON Definitions** - Map block IDs to atlas coordinates
- **Hot Swapping** - Change texture packs without restarting (reload only)
- **Validation** - Check atlas dimensions and format on load
- **Fallback** - Default to vanilla textures if pack fails to load

#### Resource Pack Structure
```
resource_packs/
├── default/
│   ├── atlas.png (512x512)
│   ├── pack.json (metadata)
│   └── blocks.json (UV mappings)
├── medieval/
│   ├── atlas.png
│   ├── pack.json
│   └── blocks.json
└── pixel_perfect/
    ├── atlas.png
    ├── pack.json
    └── blocks.json
```

#### Pack Metadata (pack.json)
```json
{
  "name": "Default Texture Pack",
  "version": "1.0",
  "author": "Lost Rabbit Digital",
  "description": "Vanilla textures for Steel and Cube",
  "atlas_size": 512,
  "tile_size": 16
}
```

#### Block UV Mapping (blocks.json)
```json
{
  "grass": {
    "top": [0, 0],
    "sides": [1, 0],
    "bottom": [2, 0]
  },
  "stone": {
    "all": [3, 0]
  }
}
```

#### Technical Considerations
- **Mipmapping** - Generate mipmaps for distant textures
- **Filtering** - Point filtering for sharp pixel art look
- **Alpha Channel** - Support transparency (glass, leaves, water)
- **Animated Textures** - Support for animated tiles (water, lava, torches)
- **Item Icons** - Share atlas space with block textures

### 12. Dynamic World Systems

#### Day/Night Cycle
- **24-Minute Cycle** - Full day/night in 24 real-time minutes (configurable)
- **Dynamic Lighting** - Sunlight changes throughout day
- **Celestial Bodies** - Sun and moon move across sky
- **Time-Based Events** - Certain NPCs/enemies appear at specific times
- **Sleep System** - Use beds to skip night (single player) or vote to skip (multiplayer)

**Time Phases:**
- **Dawn** (05:00-07:00) - Sun rises, enemies retreat
- **Day** (07:00-17:00) - Full brightness, safe exploration
- **Dusk** (17:00-19:00) - Sun sets, danger increases
- **Night** (19:00-05:00) - Darkness, more enemies spawn on surface

#### Weather System
- **Weather Types:**
  - **Clear** - Normal sunny weather
  - **Cloudy** - Overcast, slightly darker
  - **Rain** - Reduces visibility, water sounds, fills containers
  - **Thunderstorm** - Lightning, thunder sounds, dangerous
  - **Snow** - Cold, reduced visibility, snow accumulation
  - **Fog** - Heavy mist, very limited visibility
  - **Sandstorm** - Desert biomes, wind effects

- **Weather Transitions** - Gradual changes between weather states
- **Biome-Specific** - Deserts don't get rain, tundras get more snow
- **Lightning Strikes** - Can start fires, damage players/mobs
- **Weather Effects on Gameplay:**
  - Rain extinguishes torches in the open
  - Snow slows movement slightly
  - Storms increase enemy spawn rates
  - Fog makes navigation difficult

#### Seasonal System
- **Four Seasons** - Spring, Summer, Autumn, Winter
- **Season Length** - Each season lasts 4 in-game days (configurable)
- **Visual Changes:**
  - **Spring** - Lush green grass, flowers bloom, baby animals
  - **Summer** - Bright colors, longer days, abundant crops
  - **Autumn** - Orange/red leaves, harvest time, shorter days
  - **Winter** - Snow coverage, frozen water, bare trees, cold nights

#### Seasonal Gameplay Effects
**Spring:**
- Increased crop growth speed
- More animals spawn
- Rain is more frequent
- Flowers and saplings can be found

**Summer:**
- Longest days, shortest nights
- Best time for exploration
- Crops grow at normal rate
- Rare herbs and plants appear

**Autumn:**
- Crop yield increased (bonus harvest)
- Leaves drop saplings more frequently
- Days and nights are equal length
- Preparation for winter

**Winter:**
- Crops don't grow (need greenhouses)
- Water freezes into ice blocks
- Snow accumulates (blocks placed on surface)
- Longer nights, more dangerous
- Some enemies are stronger (ice-based)
- Best time for dungeon delving

#### Year Progression
- **Calendar System** - Track current year, season, and day
- **Year Counter** - Display current year (Year 1, Year 2, etc.)
- **World Evolution** - Subtle changes over years:
  - Trees grow taller and thicker
  - Abandoned buildings decay
  - New dungeons may appear
  - NPC villages can expand or contract
  - Long-term quests and events

#### Temperature System (Optional Hardcore Feature)
- **Biome-Based Temperatures:**
  - Desert: Hot (need water, heat stroke risk)
  - Tundra: Cold (need warm clothes, frostbite risk)
  - Temperate: Comfortable
- **Seasonal Temperature Variation** - Winter is colder, summer is warmer
- **Clothing Effects** - Armor type affects temperature resistance
- **Campfires and Warmth** - Light fires to stay warm in cold biomes

#### Environmental Lighting
- **Sunlight Propagation** - Blocks block sunlight
- **Skylight** - Soft ambient light from sky
- **Block Light** - Torches, lava, glowstone emit light
- **Smooth Lighting** - Interpolated lighting between blocks
- **Shadow Rendering** - Dynamic shadows from sun/moon
- **Night Vision** - Potions or spells to see in the dark

### 13. Farming System (Stardew Valley-Inspired)

#### Crop System
- **Crop Types:**
  - **Spring Crops** - Parsnips, Cauliflower, Potatoes, Strawberries
  - **Summer Crops** - Tomatoes, Blueberries, Melons, Wheat
  - **Autumn Crops** - Corn, Pumpkins, Cranberries, Grapes
  - **Year-Round** - Mushrooms (indoors), greenhouse crops

- **Crop Growth Stages:**
  - Each crop has multiple growth stages (4-7 stages)
  - Visual progression from seedling to harvestable plant
  - Growth time varies by crop (3-13 days)
  - Season-appropriate planting required
  - Crops die when season changes (unless greenhouse)

- **Crop Quality:**
  - **Normal** - Standard yield
  - **Silver** - 1.25x value (better care)
  - **Gold** - 1.5x value (perfect care + luck)
  - **Iridium** - 2x value (rare, very lucky + perfect care)
  - Quality affected by: Soil quality, fertilizer, watering consistency

#### Farming Mechanics

**Soil Preparation:**
- **Tilling** - Use hoe to till soil blocks for planting
- **Soil Quality:**
  - Normal soil - Standard growth
  - Fertilized soil - Faster growth
  - Quality fertilizer - Better quality crops
  - Deluxe fertilizer - Max quality chance
- **Soil Moisture:**
  - Crops need daily watering (or rain)
  - Dry crops don't grow that day
  - Sprinklers automate watering (small, medium, large radius)
  - Rain counts as watering

**Planting & Harvesting:**
- **Seeds** - Purchase from merchants or harvest from crops
- **Planting** - Right-click tilled soil with seeds
- **Growth Tracking** - Inspect crop to see days until harvest
- **Harvesting** - Break fully grown crop with hand or tool
- **Multi-Harvest Crops** - Some crops regrow after harvest (tomatoes, berries, corn)
- **Giant Crops** - Rare 3x3 mega crops with bonus yield (melons, pumpkins, cauliflower)

#### Farm Infrastructure

**Sprinklers:**
- **Basic Sprinkler** - Waters 4 adjacent tiles (+ pattern)
- **Quality Sprinkler** - Waters 3x3 grid (8 tiles)
- **Iridium Sprinkler** - Waters 5x5 grid (24 tiles)
- Crafted from metal bars + quartz

**Scarecrows:**
- Prevent crows from eating crops
- 8-tile radius protection
- Can be decorative variants

**Fencing:**
- Wooden, stone, iron, or decorative fences
- Contain animals, mark territory
- Decay over time (except stone/iron)

**Paths:**
- Stone, wood, gravel, crystal paths
- Prevent grass/weed growth
- Faster walking speed

#### Greenhouse
- **Unlocked** - Quest reward or purchase/build
- **Year-Round Growing** - Any season crop grows
- **No Seasonal Death** - Crops persist through seasons
- **Optimal Environment** - Slightly faster growth
- **Limited Space** - Finite indoor area

#### Animals & Ranching

**Animal Types:**
- **Chickens** - Eggs daily (white, brown, or void eggs)
- **Cows** - Milk daily (large milk if happy)
- **Sheep** - Wool every 3 days (can be dyed)
- **Pigs** - Find truffles when outside (high value)
- **Goats** - Goat milk every 2 days
- **Ducks** - Duck eggs (sometimes duck feathers)
- **Rabbits** - Wool, rabbit's foot (rare, lucky)

**Animal Care:**
- **Feeding** - Place hay in feeding trough daily (or grass outside)
- **Petting** - Interact with animal to increase friendship
- **Happiness** - Affects product quality
  - Feed, pet, and let outside = happy
  - Hungry, unpetted, locked inside = unhappy
- **Product Quality:**
  - Normal, Silver, Gold, Iridium (based on happiness)

**Ranching Buildings:**
- **Coop** - Houses chickens, ducks, rabbits (4-12 animals)
  - Basic Coop (4 animals)
  - Big Coop (8 animals)
  - Deluxe Coop (12 animals, auto-feed)
- **Barn** - Houses cows, goats, sheep, pigs (4-12 animals)
  - Basic Barn (4 animals)
  - Big Barn (8 animals)
  - Deluxe Barn (12 animals, auto-feed)
- **Silo** - Stores hay (cut grass to fill)
- **Mill** - Process wheat into flour, beets into sugar

#### Artisan Goods (Processing)

**Machines:**
- **Keg** - Turns crops into beverages (wine, beer, juice, mead)
  - Processing time: 3-7 days
  - High value increase (2x-3x)
- **Preserves Jar** - Makes jams, pickles, roe
  - Processing time: 2-4 days
  - Moderate value increase (2x)
- **Cheese Press** - Milk → Cheese
  - Processing time: 3 hours
  - Good value increase
- **Mayonnaise Machine** - Eggs → Mayonnaise
  - Processing time: 3 hours
  - Good value increase
- **Loom** - Wool → Cloth
  - Processing time: 4 hours
- **Oil Maker** - Sunflowers, corn → Oil
  - Processing time: 1 day

**Artisan Profits:**
- Processed goods sell for much more than raw crops
- Quality of input affects quality of output
- Artisan skill increases value further

#### Farming Skills & Progression

**Farming Skill (0-100):**
- Gains XP from harvesting crops, collecting animal products
- Every 10 levels: Unlock new abilities/recipes

**Farming Perks:**
- **Level 10** - Crops sell for 5% more
- **Level 20** - Unlock quality sprinkler recipe
- **Level 30** - Crops grow 10% faster
- **Level 40** - Unlock iridium sprinkler recipe
- **Level 50** - Higher chance of quality crops
- **Level 60** - Crops sell for 10% more
- **Level 70** - Animal products worth more
- **Level 80** - Unlock deluxe barn/coop recipes
- **Level 90** - Unlock greenhouse blueprint
- **Level 100 (Master)** - Chance for double harvest

#### Seasonal Festivals & Farm Events

**Spring:**
- **Egg Festival** - Hunt for eggs, win prizes
- **Flower Dance** - Social event with NPCs

**Summer:**
- **Luau** - Community potluck
- **Moonlight Jellies** - Beach event

**Autumn:**
- **Fair** - Display crops for judging, win ribbons
- **Spirit's Eve** - Halloween-themed festival

**Winter:**
- **Festival of Ice** - Ice fishing competition
- **Feast of the Winter Star** - Secret gift exchange

#### Advanced Farming Features

**Crop Mutations:**
- Rare chance for hybrid crops
- Ancient fruit (year-round, very valuable)
- Sweet gem berries (most valuable crop)
- Requires specific conditions

**Seed Makers:**
- Convert harvested crops back into seeds
- Chance to produce multiple seeds
- Rare chance for ancient seeds

**Farm Layout Optimization:**
- Efficient sprinkler placement
- Crop rotation strategies
- Seasonal planning calendars
- Min-maxing profit per tile

**Community Center Bundles:**
- Deliver crop bundles for rewards
- Unlock greenhouse, minecarts, etc.
- Similar to Stardew Valley's system

#### Integration with Other Systems

**Cooking:**
- Crops used in recipes
- Food buffs (health, mana, stamina, stats)
- Cooking skill synergy

**Alchemy:**
- Some crops used in potions
- Rare flowers for magical recipes

**Economy:**
- Farming as primary income source (early game)
- Crop prices fluctuate by season
- Merchants buy/sell seeds and products

**Quests:**
- "Deliver X crops to NPC" quests
- "Grow Y quality produce" challenges
- Festival participation quests

**Multiplayer:**
- Shared farm space
- Cooperative crop management
- Division of labor (farming, mining, combat)
- Gifting crops to other players

---

## User Interface (Daggerfall-Inspired)

### HUD Elements

#### Main HUD (In-Game View)
```
┌─────────────────────────────────────────────────┐
│        🧭 N  [COMPASS]  ☀️ Day 3, Spring Y1   │
│                                                 │
│                  GAMEPLAY                       │
│                    VIEW                         │
│                                                 │
├─────────────────────────────────────────────────┤
│ ❤️ Health: ████████░░    🌧️ Rain              │
│ 💧 Mana:   ██████░░░░    🌡️ Temperate         │
│ ⚡ Stamina: ███████░░░    ⏰ 14:35             │
│ [1][2][3][4][5][6][7][8][9]                    │
└─────────────────────────────────────────────────┘
```

#### Compass & Time/Season Display
- Always visible at top-center of screen
- Shows cardinal directions (N, S, E, W)
- Quest markers appear on compass
- Dungeon entrance/exit markers
- **Time Display** - Current in-game time (e.g., "14:35")
- **Season/Day Counter** - Shows day and season (e.g., "Day 3, Spring, Year 1")
- **Weather Icon** - Current weather condition

#### Status Bars
- **Health** - Red bar, depletes from damage
- **Mana** - Blue bar, depletes from spell casting
- **Stamina** - Yellow bar, depletes from sprinting/attacking

#### Environmental Info (Top Right)
- **Current Weather** - Icon and text (Rain, Snow, Clear, etc.)
- **Temperature** - If hardcore mode enabled
- **Time of Day** - 24-hour format clock

#### Hotbar
- 9 slots for quick item/spell access
- Numbered 1-9 for keyboard shortcuts
- Shows item/spell icons and quantity

#### Multiplayer HUD Additions
- **Player List** - Toggle to show connected players (Tab key)
- **Chat Box** - Slide-out text chat (bottom left)
- **Party Health** - Small bars showing party member health
- **Player Markers** - See other players through walls (outline)

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

### Overworld (Primary Play Space)

#### Infinite Procedural Generation
- **Minecraft-Style Terrain** - Infinite world generation in all directions
- **Chunk-Based Rendering** - 16x16x256 chunks (or configurable)
- **Seed-Based Generation** - Same seed generates same world
- **Seamless Multiplayer** - All players share the same persistent world

#### Biomes
**Temperate Biomes:**
- **Plains** - Flat grasslands, villages, easy resources
- **Forest** - Dense trees, wildlife, shade
- **Hills** - Rolling terrain, stone outcrops

**Cold Biomes:**
- **Taiga** - Pine forests, snow patches
- **Tundra** - Snowy wasteland, ice, few resources
- **Mountain** - High altitude, snow peaks, valuable ores

**Hot Biomes:**
- **Desert** - Sand dunes, cacti, scarce water, sandstorms
- **Savanna** - Dry grassland, acacia trees
- **Jungle** - Dense vegetation, ruins, exotic resources (future)

**Special Biomes:**
- **Swamp** - Water, lily pads, witch huts (future)
- **Mushroom Island** - Rare, peaceful, unique blocks (future)
- **Volcanic** - Lava flows, obsidian, dangerous (future)

#### Biome Features
- **Smooth Transitions** - Biomes blend naturally at borders
- **Temperature Mapping** - Temperature affects biome placement
- **Humidity Mapping** - Rainfall affects vegetation density
- **Elevation** - Height affects biome type (mountains have snow caps)

### Points of Interest (Scattered Throughout World)

#### Villages
- **Procedurally Generated** - Small settlements spawn in plains/forests
- **Building Types:**
  - Houses (NPC residences)
  - Market square (merchants)
  - Blacksmith (weapon/armor merchant, repair services)
  - Inn (rest, food, rumors, quests)
  - Temple/Church (healing, blessings, restoration services)
  - Town Hall (quest board, mayor NPC)
- **NPC Population** - 10-20 NPCs per village
- **Safe Zones** - No enemy spawns within village boundaries
- **Trading** - Buy/sell items, services
- **Quests** - Quest givers, bounty boards
- **Protection** - Guards patrol and defend against enemies
- **Dynamic Growth** - Villages can expand over time based on player actions

#### Towns (Larger Settlements)
- **Rare Spawns** - Larger than villages, fewer in number
- **Specialized Districts:**
  - Merchant quarter (multiple shops)
  - Mage tower (spell trainers, enchanting)
  - Thieves' den (black market, lockpicking trainers)
  - Noble district (wealthy NPCs, rare items)
- **Guild Halls:**
  - Fighters Guild (combat quests, trainers)
  - Mages Guild (spell quests, magic trainers)
  - Thieves Guild (stealth quests, fence)
- **100+ NPCs** with schedules and personalities
- **Political System** - Town leadership, reputation affects prices/quests

#### Dungeons (Scattered Exploration)
- **Surface Entrances** - Dungeon openings in the overworld
- **Visible Indicators:**
  - Cave mouths in cliff sides
  - Ancient ruins with stairs down
  - Abandoned mine shafts
  - Crypts in graveyards near villages
  - Mysterious towers with basements
- **Instance-Based** - Entering dungeon loads separate area
- **Persistent State** - Dungeon remembers cleared rooms, loot taken
- **Respawn Timer** - Enemies/loot respawn after several in-game days
- **Difficulty Indicators:**
  - Dungeon entrance shows recommended level
  - Deeper dungeons have tougher enemies and better loot
- **Unique Dungeons** - Hand-crafted story dungeons with unique bosses

#### Natural Structures
- **Caves** - Natural cave systems, ore veins, underground lakes
- **Ravines** - Deep cracks in earth, exposed stone layers
- **Floating Islands** - Rare sky formations (magical areas)
- **Ancient Ruins** - Crumbling structures, lore, treasure
- **Shipwrecks** - Coastal wreckage with loot (future)
- **Abandoned Mines** - Old mining operations, rail carts, ore

#### Player-Built Structures
- **Full Building Freedom** - Build anywhere in the overworld
- **Claim System** - Mark land as your territory (prevents griefing in multiplayer)
- **Shared Builds** - Collaborate with other players
- **Showcase Settlements** - Build your own villages and towns
- **Functional Bases:**
  - Storage rooms with chests
  - Crafting halls with all stations
  - Farms for crops/animals
  - Defensive walls and towers
  - Player-run shops (multiplayer)

### Underground/Dungeons (Instanced Areas)

#### Dungeon Instances
- **Separate from Overworld** - Load into separate area when entering
- **Finite Size** - Large but bounded (prevents infinite exploration)
- **Limited Building** - Can place torches, but not blocks (or minimal)
- **Combat-Focused** - Designed for fighting and looting
- **Party-Shared** - In multiplayer, party enters same instance

#### Dungeon Types (As Before)
1. **Crypts** - Undead enemies, dark atmosphere, bone/soul themes
2. **Caves** - Natural formations, wildlife, ore-rich
3. **Ruins** - Ancient structures, magical enemies, puzzles
4. **Mines** - Industrial hazards, mining lore, ore veins
5. **Sewers** - Urban underground, rats, bandits
6. **Towers** - Vertical dungeons, mages, constructs

### World Persistence
- **Save System** - Entire world saved to disk
- **Block Changes** - Every placed/mined block is saved
- **Entity States** - NPC positions, inventory, relationships
- **Time/Season** - Current time, season, year saved
- **Quest Progress** - All quest states persist
- **Multiplayer Worlds** - Server hosts persistent world, players connect

### Fast Travel
- **Unlock System** - Discover towns/villages to unlock fast travel
- **Travel Map** - Daggerfall-style map interface
- **Time Cost** - Fast travel advances in-game time
- **Cannot Fast Travel:**
  - From within dungeons
  - When enemies are nearby
  - While in combat
- **Multiplayer** - Fast travel only affects your character

### World Scale
- **Overworld** - Infinite (practically limited by hardware/time)
- **Recommended Play Area** - 10,000 x 10,000 blocks for small group
- **Dungeon Spacing** - 500-1000 blocks apart on average
- **Village Spacing** - 1000-2000 blocks apart
- **Town Spacing** - 5000+ blocks apart (rare)

### Spawn Point
- **Initial Spawn** - Random temperate biome location
- **Bed Respawn** - Set spawn by sleeping in bed
- **Multiplayer Spawn** - Server config determines spawn (shared or random)

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

### Engine & Distribution
- **Engine:** Godot 4.5
- **Language:** GDScript (primary), C# (optional for performance-critical systems)
- **Distribution Platform:** Steam (PC: Windows, Linux, macOS)
- **Release Strategy:**
  - Steam Early Access for testing and community feedback
  - Regular updates during Early Access
  - Full 1.0 release after polish and content completion

### Steam Integration
- **Steamworks SDK** - Achievements, cloud saves, leaderboards
- **Steam Networking** - Built-in NAT punchthrough for multiplayer
- **Steam Workshop** - Resource pack and mod distribution (future)
- **Steam Friends** - Invite friends, join friend's games
- **Steam Cloud** - Character and world save backups

### Key Technical Features

#### Rendering
- **Voxel terrain system** - Chunk-based world generation (16x16x256 blocks)
- **Multithreaded chunk generation** - Performance optimization
- **Greedy meshing** - Efficient mesh generation
- **Texture atlas system** - Single texture binding (Beta 1.7 style)
- **Dynamic lighting** - Real-time shadows, sunlight, and block light
- **Smooth lighting** - Interpolated ambient occlusion
- **Shadow mapping** - Cascaded shadow maps for sun/moon
- **Particle systems** - Weather, magic effects, mining particles

#### World Generation
- **Procedural generation** - Infinite terrain using seed-based noise
- **Biome system** - Multiple biomes with smooth transitions
- **Structure generation** - Villages, towns, dungeons, ruins
- **Cave/ravine generation** - Underground formations
- **Ore distribution** - Realistic mineral veins at varying depths

#### Multiplayer Networking
- **Client-Server Architecture** - Dedicated or peer-to-peer
- **Server-Authoritative** - Server validates all actions
- **State Synchronization** - Position, inventory, world changes
- **Prediction and Lag Compensation** - Smooth client-side experience
- **UDP Protocol** - Low-latency networking (ENet or similar)
- **Chunk Streaming** - Efficient transmission of world data

#### Dynamic Systems
- **Day/Night Cycle** - 24-minute configurable cycle
- **Weather System** - Multiple weather types with transitions
- **Seasonal System** - Four seasons with visual and gameplay changes
- **Time Progression** - Calendar tracks days, seasons, years
- **Temperature System** - Biome and season-based (optional hardcore)

#### Resource Pack System
- **Texture Atlas Loading** - Runtime texture pack switching
- **JSON Configuration** - UV mappings and metadata
- **Validation** - Error checking for corrupt packs
- **Hot Reload** - Change packs without restart

#### Save System
- **World Persistence** - All block changes, entities, time/weather saved
- **Character Persistence** - Stats, inventory, quests, position
- **Chunk Serialization** - Efficient compressed chunk storage
- **Incremental Saves** - Auto-save without freezing game
- **Multiplayer Server Saves** - Server maintains world state

#### Performance Optimizations
- **Frustum Culling** - Don't render chunks outside view
- **Occlusion Culling** - Don't render chunks behind others
- **LOD System** - Lower detail for distant chunks
- **Chunk Pooling** - Reuse chunk data structures (see tasks.md)
- **Thread Pool** - Manage worker threads for generation
- **Batch Rendering** - Minimize draw calls via atlasing

### Performance Targets
- **60 FPS** on recommended hardware
- **Render distance** - 8-16 chunks (configurable)
- **Smooth chunk loading** - No stuttering during generation
- **Network latency** - <100ms for good multiplayer experience
- **2-8 players** - Stable multiplayer performance
- **World size** - Support for millions of chunks

---

## Development Priorities

### Phase 1: Core Voxel Mechanics ✓ (Mostly Complete)
- Voxel terrain rendering
- Chunk management system
- Basic world generation
- Player movement and camera

### Phase 2: Texture Atlas & Resource Packs
- Implement Beta 1.7-style texture atlas system
- Resource pack loading and validation
- JSON-based UV mapping
- Hot-swapping texture packs

### Phase 3: Dynamic World Systems
- Day/night cycle implementation
- Weather system (rain, snow, storms)
- Seasonal system with visual changes
- Time progression and calendar
- Environmental lighting (sun, moon, stars)

### Phase 4: Multiplayer Foundation
- Client-server networking architecture
- Player synchronization
- Block change synchronization
- Basic chat system
- Server browser/hosting

### Phase 5: Overworld Expansion
- Biome generation (temperature/humidity maps)
- Village generation
- Town generation (rare)
- Dungeon entrance placement
- Natural structures (caves, ravines, ruins)

### Phase 6: Daggerfall-Style RPG Foundation
- Character attribute and skill system
- Inventory and equipment system
- Daggerfall-inspired HUD with time/weather/season display
- Basic combat mechanics

### Phase 7: Building & Crafting
- Mining blocks
- Placing blocks
- Crafting system
- Building tools
- Land claim system (multiplayer)

### Phase 8: Combat & Magic
- Melee combat with directional attacks
- Blocking and parrying
- Magic casting system
- Basic enemy AI

### Phase 9: Dungeons & Enemies
- Dungeon generation system (instanced)
- Enemy spawning
- Loot system
- Traps and hazards

### Phase 10: NPCs & Quests
- NPC system with dialogue
- Quest system
- Merchant/trading
- Guild halls
- Reputation system

### Phase 11: Polish & Content
- More enemy types
- More spells and equipment
- Sound and music
- Particle effects for weather and magic
- Tutorial system

---

## Unique Selling Points

1. **Triple Genre Fusion** - Daggerfall RPG + Minecraft Building + Stardew Valley Farming in one game
2. **Living, Breathing World** - Dynamic seasons, weather, day/night cycles, and crops that grow in real-time
3. **Deep RPG in an Infinite Voxel World** - Stats, skills, and progression in a fully explorable world
4. **Terraria-Style Multiplayer** - Host or join with your character, multiple characters and worlds
5. **Build Together, Farm Together, Adventure Together** - Full co-op experience
6. **Classic Interface, Modern Engine** - Daggerfall aesthetics powered by Godot 4.5
7. **Scattered Points of Interest** - Discover villages, towns, dungeons, and farms organically
8. **Swappable Textures** - Beta 1.7-style resource packs for infinite customization
9. **Seasonal Farming** - Plant in spring, harvest in summer, sell in autumn, prepare for winter
10. **Persistent Everything** - Your builds, crops, animals, and friendships all persist
11. **Steam Early Access** - Join development, shape the game with your feedback

---

## Future Expansion Ideas

- **Mod support** - Server-side mods, custom content, modding API
- **Expanded magic system** - Spell creation and combination
- **Advanced NPCs** - More complex schedules, relationships, reputation, factions
- **More biomes** - Jungle, swamp, volcanic, mushroom islands, floating islands
- **Ocean update** - Boats, underwater dungeons, fishing, sea creatures
- **Boss raids** - Epic multi-player boss encounters
- **Farming system** - Crop growing influenced by seasons
- **Animal husbandry** - Breeding, raising livestock
- **PvP arenas** - Optional competitive multiplayer zones
- **World events** - Seasonal festivals, invasions, meteor showers
- **Voice chat** - Proximity-based in-game voice

---

## Conclusion

**Steel and Cube** aims to deliver a groundbreaking multiplayer experience by blending **four** beloved gaming philosophies:
- **Minecraft's** voxel sandbox freedom and building creativity
- **Daggerfall's** deep RPG systems and atmospheric dungeon crawling
- **Stardew Valley's** relaxing farming, ranching, and community life
- **Terraria's** accessible multiplayer (host/join, multiple characters/worlds)

Built in **Godot 4.5** and launching on **Steam Early Access**, the game offers a living, breathing world where:
- **Seasons change** - Watch autumn leaves fall, winter snow accumulate, spring flowers bloom
- **Crops grow** - Plant parsnips in spring, harvest melons in summer, process into wine
- **Animals thrive** - Raise chickens for eggs, cows for milk, pigs for truffles
- **Weather shifts** - Rain waters your crops, storms drive you to dungeons, fog creates mystery
- **Time flows** - Day/night cycles, seasonal festivals, years passing
- **Friends adventure** - Host or join, build together, farm together, raid dungeons together

Whether you're **farming rare ancient fruit in your greenhouse**, **crafting legendary daedric armor**, **building a fortress with friends**, **delving into ancient crypts**, **selling artisan cheese at the market**, or **watching the sun set over your wheat fields**, **Steel and Cube** offers a unique fusion greater than the sum of its parts.

This is a truly **living voxel RPG farming world** - and it's yours to shape.
