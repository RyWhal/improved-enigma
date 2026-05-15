# Heartwarren

A Godot 4 desktop prototype for a top-down dungeon ecosystem sim. The player plans a dungeon, places a defenseless but durable Heart, then grows a living ecosystem by shaping temperature, moisture, magic, darkness, and biomass.

## Run

Open this folder in Godot 4 and run `scenes/Main.tscn`.

The MVP uses bundled pixel tiles and sprites plus CanvasItem drawing, atmospheric overlays, and UI generated from GDScript.

## Controls

- `WASD`: pan camera
- Mouse wheel: zoom
- Left click: use the selected tool
- Drag with Dig or Fill: paint multiple tiles
- Inspect: click tiles, creatures, or adventurers for state readouts
- Inspect a monster den: assign den behavior, including magical research rooms
- Research: open the `Rs` button to spend knowledge on upgrade nodes
- Research tree: branches show ranks, costs, locked prerequisites, and effect tooltips
- Planning phase: dig/fill, place the Heart, add treasure, doors, and basic traps
- Build menu: opens construction tools, including 2x2 monster dens and environmental sources
- Overlay menu: opens normal, heat, moisture, magic, and biomass views
- Top resource bar: shows compact resource counts with hover names
- Fill in planning: erases a planned floor/structure and refunds its essence
- Undo: backs out planning actions before the dungeon starts
- Start Dungeon: awakens the dungeon and begins crawler incursions
- Respawn Boss: after the boss has been dead for about a minute, regrows it for a large biomass and essence cost
- Explode Spores: detonates a spore root, heavily damaging nearby crawlers and tearing open adjacent diggable stone
- Restart: appears after the Heart is destroyed

## Included Systems

- 128x128 dungeon grid split into 32x32 influence chunks, starting mostly solid with an edge entrance
- Planning budget, reversible planning actions, and warning-only build validation
- Dungeon Heart fail state: durable, defenseless, no passive regeneration, and a damage health bar
- Treasure, doors, and a basic spike trap
- 2x2 monster dens that spawn small monsters based on local conditions
- Research dens: qualified magical rooms behind doors can assign goblins to produce knowledge for upgrades
- Ranked evolution tree with prerequisite paths for dungeon economy, monsters, Heart growth, defensive structures, and hidden routes
- Research unlocks locked doors, poison traps, secret tunnels, skeleton servitors, elemental den spawns, lifesteal, den birth-rate boosts, cheaper digging, and recovered loot
- Wave director that shows the next wave, pressure, and pause state while scaling crawler count and HP over time
- Room identity profiles for inspect readouts, including research chambers, hatcheries, trap halls, treasure vaults, corridors, and Heart chambers
- Build-phase magic, heat, moisture, and spore seeding for pre-run ecosystem planning
- Heart-bound boss larva that stays near the Heart, can be regrown after death, and grows through research-gated Heart upgrades
- Live Heart relocation for a high essence cost
- Slow background essence condensation during live play
- Environmental diffusion for heat, moisture, magic, darkness, and biomass growth, with magic seep strength falling off locally
- Player tools for digging, filling, structures, environmental sources, seeding, and inspection
- Emergency carrion mite seeding can spend essence when biomass and bone are empty, while repeated direct mite seeding gets more expensive
- Reduced biomass rewards and passive biomass growth to slow runaway horde economies
- Resources: essence, biomass, magic, bone, fear, knowledge
- Organisms: spore roots, carrion mites, gloom slugs, needle bats, den-spawned monsters, the boss larva, and mutation variants that defend nearby dungeon threats
- Adventurer incursions: looters, torchbearers, and hunters that escalate with fear, attack visible creatures, disrupt visible sources, and respect an active-crawler cap
- Debug game log for crawler, creature, trap, Heart, and resource events
- Visual overlays: normal, heat, moisture, magic, biomass

## Research Tree

Magical research rooms generate knowledge when a 2x2 monster den is placed in a room with a door and strong magic. Inspect the den and set it to `Study` to keep scholar goblins researching.

- `Dungeon Praxis I-III`: root knowledge path; unlocks basic branches.
- `Stonecraft I-II`: reduces dig cost and unlocks stronger construction.
- `Reinforced Doors I-II`: unlocks locked doors that crawlers must break before passing.
- `Poison Craft I-II`: unlocks poison traps that deal damage over time.
- `Hidden Ways I-II`: unlocks secret tunnels for monsters; crawlers have only a small discovery chance.
- `Goblin Warrens`: unlocks the main monster improvement branch.
- `Hardened Brood I-III`: increases den-spawned monster HP.
- `Quickened Brood I-III`: speeds den-spawned monsters.
- `Feral Vitality I-II`: gives monsters a small lifesteal chance when hitting crawlers.
- `Den Fertility I-III`: increases monster den birth rate.
- `Skeleton Servitors`, `Hexbound Kin`, `Ember Pact`, `Bog Brood`, `Arcane Spawning`: unlock condition-based monster variants from dens.
- `Heart Pupation`: allows the Heart larva to evolve.
- `Heart Bulk I-III` and `Heart Violence I-III`: improve boss HP and attack.
- `Heart Dominion`: late Heart branch capstone placeholder.
- `Claimed Spoils I-II` and `Fearful Reclamation`: economy branch for recovering looted treasure and fear-driven reclamation hooks.
