# Dungeon Tycoon

A Godot 4 desktop prototype for a top-down dungeon ecosystem sim. The player plans a dungeon, places a defenseless but durable Heart, then grows a living ecosystem by shaping temperature, moisture, magic, darkness, and biomass.

## Run

Open this folder in Godot 4 and run `scenes/Main.tscn`.

The MVP uses only procedural visuals: CanvasItem drawing, primitive glyph creatures, atmospheric overlays, and UI generated from GDScript.

## Controls

- `WASD`: pan camera
- Mouse wheel: zoom
- Left click: use the selected tool
- Drag with Dig or Fill: paint multiple tiles
- Inspect: click tiles, creatures, or adventurers for state readouts
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

- 120x120 dungeon grid that starts mostly solid with an edge entrance
- Planning budget, reversible planning actions, and warning-only build validation
- Dungeon Heart fail state: durable, defenseless, no passive regeneration, and a damage health bar
- Treasure, doors, and a basic spike trap
- 2x2 monster dens that spawn small monsters based on local conditions
- Build-phase magic, heat, moisture, and spore seeding for pre-run ecosystem planning
- Heart-bound boss larva that stays near the Heart, hits harder, can be regrown after death, and can grow into a juvenile based on nearby conditions
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
