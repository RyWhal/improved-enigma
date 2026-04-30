extends Node2D

const CreatureScene = preload("res://scenes/Creature.tscn")
const AdventurerScene = preload("res://scenes/Adventurer.tscn")
const DungeonTileScript = preload("res://scripts/tile_data.gd")
const MAX_ACTIVE_CRAWLERS := 32
const BOSS_RESPAWN_DELAY_TICKS := 215
const BOSS_RESPAWN_BIOMASS_COST := 120
const BOSS_RESPAWN_ESSENCE_COST := 60

@onready var grid: DungeonGrid = $Grid
@onready var simulation: DungeonSimulation = $Simulation
@onready var resources: DungeonResources = $Resources
@onready var camera: Camera2D = $WorldCamera
@onready var ui: DungeonUI = $UI

var selected_tool: String = "inspect"
var creatures: Array = []
var adventurers: Array = []
var planning_history: Array[Dictionary] = []
var planning_phase: bool = true
var dungeon_inert: bool = false
var heart_coord: Vector2i = Vector2i(-1, -1)
var is_dragging_tool: bool = false
var last_drag_coord: Vector2i = Vector2i(-1, -1)
var sim_accumulator: float = 0.0
var incursion_timer: float = 22.0
var natural_spawn_timer: float = 6.0
var boss_respawn_ticks: int = 0
var camera_speed: float = 680.0
var tool_costs: Dictionary = {
	"dig": 1,
	"fill": 1,
	"place_heart": 0,
	"place_treasure": 5,
	"place_trap": 6,
	"place_door": 3,
	"place_monster_den": 16,
	"move_heart": 20,
	"moisture_source": 5,
	"heat_vent": 5,
	"magic_seep": 8,
	"seed_spore_root": 6,
	"seed_carrion_mite": 4,
	"respawn_boss": 0,
	"explode_spores": 0,
}

func _ready() -> void:
	randomize()
	grid.generate_planning_map()
	simulation.configure(grid, resources)
	simulation.log_event.connect(_log_event)
	ui.bind_resources(resources)
	ui.tool_selected.connect(func(tool: String) -> void: selected_tool = tool)
	ui.overlay_selected.connect(func(overlay: String) -> void: grid.set_overlay(overlay))
	ui.undo_requested.connect(_undo_planning_action)
	ui.start_requested.connect(_start_dungeon)
	ui.restart_requested.connect(_restart_run)
	camera.position = grid.tile_to_world(grid.entrance_tile + Vector2i(14, 0))
	ui.set_phase("Planning Phase")
	_update_build_warnings()
	ui.show_message("Plan your first dungeon. Dig from the entrance, place the Heart, then start the run.")
	_log_event("New dungeon run started.")

func _process(delta: float) -> void:
	_handle_camera(delta)
	if planning_phase or dungeon_inert:
		return
	sim_accumulator += delta
	if sim_accumulator >= 0.28:
		sim_accumulator = 0.0
		_prune_dead_entities()
		simulation.step(creatures, adventurers)
		_check_heart_state()
		_update_boss_respawn_timer()
		_try_den_spawns()
		_try_natural_spawn()
	incursion_timer -= delta
	if incursion_timer <= 0.0:
		_spawn_incursion()
		incursion_timer = randf_range(28.0, 45.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.08).clamp(Vector2(0.35, 0.35), Vector2(1.8, 1.8))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom * 0.92).clamp(Vector2(0.35, 0.35), Vector2(1.8, 1.8))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if ui.is_world_input_blocked():
				return
			is_dragging_tool = selected_tool in ["dig", "fill"]
			var coord := grid.world_to_tile(get_global_mouse_position())
			last_drag_coord = coord
			_handle_click(coord)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_dragging_tool = false
			last_drag_coord = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and is_dragging_tool:
		if ui.is_world_input_blocked():
			return
		var drag_coord := grid.world_to_tile(get_global_mouse_position())
		if drag_coord != last_drag_coord:
			last_drag_coord = drag_coord
			_handle_click(drag_coord)

func _handle_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if direction.length_squared() > 0.0:
		camera.position += direction.normalized() * camera_speed * delta / camera.zoom.x
		var world_size: int = DungeonGrid.GRID_SIZE * DungeonGrid.TILE_SIZE
		camera.position = camera.position.clamp(Vector2.ZERO, Vector2(world_size, world_size))

func _handle_click(coord: Vector2i) -> void:
	if not grid.is_in_bounds(coord):
		return
	var creature = _creature_at(coord)
	if selected_tool == "inspect":
		if creature != null:
			ui.show_creature_info(creature)
			return
		var adventurer = _adventurer_at(coord)
		if adventurer != null:
			ui.show_adventurer_info(adventurer)
			return
		ui.show_tile_info(coord, grid.get_tile(coord), _mutation_conditions_near(coord))
		return
	if planning_phase and not selected_tool in ["dig", "fill", "place_heart", "place_treasure", "place_trap", "place_door", "place_monster_den", "move_heart", "moisture_source", "heat_vent", "magic_seep", "seed_spore_root"]:
		ui.show_message("Natural shaping unlocks after the dungeon starts. Use build tools during planning.")
		return
	match selected_tool:
		"dig":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.dig(coord))
		"fill":
			if planning_phase:
				_erase_planning_tile(coord)
			else:
				_apply_tile_action(coord, selected_tool, func() -> bool: return grid.fill(coord))
		"place_heart":
			_apply_tile_action(coord, selected_tool, func() -> bool: return _place_unique_structure(coord, "heart"))
		"move_heart":
			_apply_tile_action(coord, selected_tool, func() -> bool: return _move_heart(coord))
		"place_treasure":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_structure(coord, "treasure"))
		"place_trap":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_structure(coord, "trap"))
		"place_door":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_structure(coord, "door"))
		"place_monster_den":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_monster_den(coord))
		"moisture_source":
			_apply_source_action(coord, selected_tool, func(tile: DungeonTileData) -> void:
				tile.moisture_source = true
				tile.moisture = max(tile.moisture, 82.0)
			)
		"heat_vent":
			_apply_source_action(coord, selected_tool, func(tile: DungeonTileData) -> void:
				tile.heat_source = true
				tile.temperature = max(tile.temperature, 84.0)
			)
		"magic_seep":
			_apply_source_action(coord, selected_tool, func(tile: DungeonTileData) -> void:
				tile.magic_source = true
				tile.magic = max(tile.magic, 78.0)
			)
		"seed_spore_root":
			if planning_phase:
				if _spend_and_require_floor(coord, "biomass", int(tool_costs[selected_tool])):
					var tile: DungeonTileData = grid.get_tile(coord)
					tile.spore_seed = true
					tile.biomass = max(tile.biomass, 28.0)
			elif _spend_and_require_floor(coord, "biomass", int(tool_costs[selected_tool])):
				_spawn_creature("spore_root", coord)
		"seed_carrion_mite":
			_seed_carrion_mite(coord)
		"respawn_boss":
			_respawn_boss()
		"explode_spores":
			_explode_spores(coord)
	grid.queue_redraw()

func _apply_tile_action(coord: Vector2i, tool: String, action: Callable) -> void:
	var cost: int = int(tool_costs.get(tool, 0))
	var before: Dictionary = grid.get_tile(coord).snapshot() if grid.is_in_bounds(coord) else {}
	if cost > 0 and not resources.spend("essence", cost):
		ui.show_message("Need %s essence." % cost)
		return
	if not action.call():
		if cost > 0:
			resources.add("essence", cost)
		ui.show_message("That action cannot be used there.")
		return
	if planning_phase:
		var tile: DungeonTileData = grid.get_tile(coord)
		if tool == "dig":
			tile.planning_floor_cost += cost
		elif tool in ["place_heart", "place_treasure", "place_trap", "place_door", "place_monster_den"]:
			tile.planning_structure_cost += cost
		planning_history.append({"coord": coord, "before": before, "cost": cost})
		_update_build_warnings()
	heart_coord = grid.find_structure("heart")

func _apply_source_action(coord: Vector2i, tool: String, mutation: Callable) -> void:
	if not grid.is_in_bounds(coord):
		return
	var cost: int = int(tool_costs[tool])
	var before: Dictionary = grid.get_tile(coord).snapshot()
	if not _spend_and_require_floor(coord, "essence", cost):
		return
	mutation.call(grid.get_tile(coord))
	if planning_phase:
		var tile: DungeonTileData = grid.get_tile(coord)
		tile.planning_structure_cost += cost
		planning_history.append({"coord": coord, "before": before, "cost": cost})
		_update_build_warnings()

func _erase_planning_tile(coord: Vector2i) -> void:
	if not grid.is_in_bounds(coord):
		return
	var tile: DungeonTileData = grid.get_tile(coord)
	if tile.kind == DungeonTileScript.Kind.ENTRANCE:
		ui.show_message("The entrance cannot be erased.")
		return
	if tile.structure == "monster_den":
		var den_refund := 0
		for den_tile_coord in grid.den_tiles(tile.den_id):
			den_refund += grid.get_tile(den_tile_coord).planning_structure_cost
		grid.clear_monster_den(tile.den_id)
		resources.add("essence", den_refund)
		_update_build_warnings()
		ui.show_message("Monster den erased. Refunded %s essence." % den_refund)
		return
	if tile.structure != "":
		var refund: int = tile.planning_structure_cost
		tile.structure = ""
		tile.heart_hp = 0
		tile.trap_damage = 0
		tile.locked_door = false
		tile.planning_structure_cost = 0
		resources.add("essence", refund)
		heart_coord = grid.find_structure("heart")
		_update_build_warnings()
		ui.show_message("Structure erased. Refunded %s essence." % refund)
		grid.queue_redraw()
		return
	if tile.heat_source or tile.moisture_source or tile.magic_source or tile.spore_seed:
		var source_refund: int = tile.planning_structure_cost
		tile.heat_source = false
		tile.moisture_source = false
		tile.magic_source = false
		tile.spore_seed = false
		tile.planning_structure_cost = 0
		resources.add("essence", source_refund)
		_update_build_warnings()
		ui.show_message("Source erased. Refunded %s essence." % source_refund)
		grid.queue_redraw()
		return
	if tile.kind == DungeonTileScript.Kind.FLOOR:
		var floor_refund: int = tile.planning_floor_cost
		tile.set_stone()
		resources.add("essence", floor_refund)
		_update_build_warnings()
		ui.show_message("Floor erased. Refunded %s essence." % floor_refund)
		grid.queue_redraw()
		return
	ui.show_message("Nothing planned there to erase.")

func _place_unique_structure(coord: Vector2i, structure_name: String) -> bool:
	if grid.find_structure(structure_name) != Vector2i(-1, -1):
		return false
	return grid.place_structure(coord, structure_name)

func _move_heart(coord: Vector2i) -> bool:
	if planning_phase:
		ui.show_message("During planning, erase and replace the Heart freely.")
		return false
	var old_heart := grid.find_structure("heart")
	if old_heart == Vector2i(-1, -1) or not grid.is_in_bounds(coord):
		return false
	if not grid.get_tile(coord).is_walkable() or grid.get_tile(coord).structure != "":
		return false
	var old_hp: int = max(grid.get_tile(old_heart).heart_hp, 1)
	grid.clear_structure(old_heart)
	grid.place_structure(coord, "heart")
	grid.get_tile(coord).heart_hp = old_hp
	heart_coord = coord
	_update_build_warnings()
	return true

func _undo_planning_action() -> void:
	if not planning_phase or planning_history.is_empty():
		ui.show_message("Nothing to undo in planning.")
		return
	var entry: Dictionary = planning_history.pop_back()
	var coord: Vector2i = entry["coord"]
	grid.get_tile(coord).restore(entry["before"])
	resources.add("essence", int(entry["cost"]))
	heart_coord = grid.find_structure("heart")
	_update_build_warnings()
	ui.show_message("Planning action undone.")

func _start_dungeon() -> void:
	heart_coord = grid.find_structure("heart")
	if heart_coord == Vector2i(-1, -1):
		ui.show_message("The dungeon needs a Heart before it can awaken.")
		return
	planning_phase = false
	planning_history.clear()
	ui.set_phase("Live Dungeon")
	_update_build_warnings()
	_seed_initial_ecosystem()
	_spawn_boss_larva()
	incursion_timer = 7.0
	ui.show_message("The dungeon wakes. Protect the Heart; it will not heal on its own.")
	_log_event("The dungeon wakes.")

func _restart_run() -> void:
	for creature in creatures:
		if is_instance_valid(creature):
			creature.queue_free()
	for adventurer in adventurers:
		if is_instance_valid(adventurer):
			adventurer.queue_free()
	creatures.clear()
	adventurers.clear()
	planning_history.clear()
	planning_phase = true
	dungeon_inert = false
	heart_coord = Vector2i(-1, -1)
	is_dragging_tool = false
	last_drag_coord = Vector2i(-1, -1)
	sim_accumulator = 0.0
	incursion_timer = 22.0
	natural_spawn_timer = 6.0
	boss_respawn_ticks = 0
	resources.reset()
	grid.generate_planning_map()
	camera.position = grid.tile_to_world(grid.entrance_tile + Vector2i(14, 0))
	ui.set_phase("Planning Phase")
	_update_build_warnings()
	ui.show_message("Plan your next dungeon. Place the Heart, then start the run.")
	_log_event("Run restarted.")

func _update_build_warnings() -> void:
	ui.set_warnings(grid.get_build_warnings())

func _spend_and_require_floor(coord: Vector2i, resource_name: String, cost: int) -> bool:
	if not grid.get_tile(coord).is_walkable():
		ui.show_message("The dungeon must be opened before it can be shaped there.")
		return false
	if not resources.spend(resource_name, cost):
		ui.show_message("Need %s %s." % [cost, resource_name])
		return false
	return true

func _spend_alternative_floor(coord: Vector2i, options: Array[Dictionary]) -> bool:
	if not grid.get_tile(coord).is_walkable():
		ui.show_message("The dungeon must be opened before it can be shaped there.")
		return false
	for option in options:
		var resource_name: String = String(option["resource"])
		var cost: int = int(option["cost"])
		if resources.get_amount(resource_name) >= cost:
			resources.spend(resource_name, cost)
			return true
	var parts: Array[String] = []
	for option in options:
		parts.append("%s %s" % [option["cost"], option["resource"]])
	ui.show_message("Need %s." % " or ".join(parts))
	return false

func _seed_carrion_mite(coord: Vector2i) -> void:
	if not grid.get_tile(coord).is_walkable():
		ui.show_message("The dungeon must be opened before it can be shaped there.")
		return
	var mite_count := _count_species("carrion_mite") + _count_species("bloat_mite") + _count_species("ember_mite")
	var biomass_cost := 4 + mite_count * 2
	var essence_cost := 12 + mite_count * 2
	if resources.get_amount("bone") >= 1:
		resources.spend("bone", 1)
	elif resources.get_amount("biomass") >= biomass_cost:
		resources.spend("biomass", biomass_cost)
	elif resources.get_amount("essence") >= essence_cost:
		resources.spend("essence", essence_cost)
	else:
		ui.show_message("Need 1 bone, %s biomass, or %s essence." % [biomass_cost, essence_cost])
		return
	_spawn_creature("carrion_mite", coord)

func _seed_initial_ecosystem() -> void:
	var seed_center: Vector2i = heart_coord if heart_coord != Vector2i(-1, -1) else grid.start_center
	for x in range(1, DungeonGrid.GRID_SIZE - 1):
		for y in range(1, DungeonGrid.GRID_SIZE - 1):
			var coord := Vector2i(x, y)
			var tile: DungeonTileData = grid.get_tile(coord)
			if tile.spore_seed and _creature_at(coord) == null:
				_spawn_creature("spore_root", coord)
	for offset in [Vector2i(-4, 2), Vector2i(-2, 3), Vector2i(3, -2)]:
		_spawn_creature("spore_root", seed_center + offset)
	for offset in [Vector2i(0, 2), Vector2i(2, 1), Vector2i(-3, -1)]:
		_spawn_creature("carrion_mite", seed_center + offset)
	_spawn_creature("gloom_slug", seed_center + Vector2i(-5, 3))

func _spawn_creature(species: String, coord: Vector2i) -> DungeonCreature:
	if not grid.is_in_bounds(coord) or not grid.get_tile(coord).is_walkable():
		return null
	var creature: DungeonCreature = CreatureScene.instantiate() as DungeonCreature
	grid.add_child(creature)
	creature.initialize(species, coord)
	creature.log_event.connect(_log_event)
	creatures.append(creature)
	return creature

func _spawn_boss_larva() -> void:
	if heart_coord == Vector2i(-1, -1) or _count_bosses() > 0:
		return
	var spawn_coord := heart_coord
	for candidate in [heart_coord + Vector2i.RIGHT, heart_coord + Vector2i.DOWN, heart_coord + Vector2i.LEFT, heart_coord + Vector2i.UP, heart_coord]:
		if grid.is_in_bounds(candidate) and grid.get_tile(candidate).is_walkable():
			spawn_coord = candidate
			break
	_spawn_creature("heart_larva", spawn_coord)
	boss_respawn_ticks = 0

func _update_boss_respawn_timer() -> void:
	if _count_bosses() > 0:
		boss_respawn_ticks = 0
	elif grid.find_structure("heart") != Vector2i(-1, -1):
		boss_respawn_ticks += 1

func _respawn_boss() -> bool:
	heart_coord = grid.find_structure("heart")
	if planning_phase or heart_coord == Vector2i(-1, -1):
		ui.show_message("The boss is bound to a live dungeon Heart.")
		return false
	if _count_bosses() > 0:
		ui.show_message("The boss is already alive.")
		return false
	if boss_respawn_ticks < BOSS_RESPAWN_DELAY_TICKS:
		var remaining := ceili(float(BOSS_RESPAWN_DELAY_TICKS - boss_respawn_ticks) * 0.28)
		ui.show_message("The Heart needs %s more seconds before it can regrow the boss." % remaining)
		return false
	if resources.get_amount("biomass") < BOSS_RESPAWN_BIOMASS_COST or resources.get_amount("essence") < BOSS_RESPAWN_ESSENCE_COST:
		ui.show_message("Need %s biomass and %s essence to regrow the boss." % [BOSS_RESPAWN_BIOMASS_COST, BOSS_RESPAWN_ESSENCE_COST])
		return false
	resources.spend("biomass", BOSS_RESPAWN_BIOMASS_COST)
	resources.spend("essence", BOSS_RESPAWN_ESSENCE_COST)
	_spawn_boss_larva()
	_log_event("The Heart spends biomass and essence to regrow its boss larva.")
	return true

func _explode_spores(coord: Vector2i) -> bool:
	var spore = _creature_at(coord)
	var tile: DungeonTileData = grid.get_tile(coord)
	if spore == null or spore.species != "spore_root":
		if not tile.spore_seed:
			ui.show_message("Exploding spores needs a spore root.")
			return false
	for adventurer in adventurers:
		if is_instance_valid(adventurer) and adventurer.tile_pos.distance_to(coord) <= 2.4:
			adventurer.hp -= 22.0
			_log_event("Exploding spores rupture over a crawler.")
	for x in range(coord.x - 1, coord.x + 2):
		for y in range(coord.y - 1, coord.y + 2):
			var nearby := Vector2i(x, y)
			if grid.is_in_bounds(nearby) and grid.get_tile(nearby).is_diggable():
				grid.dig(nearby)
	for creature in creatures:
		if is_instance_valid(creature) and creature.species == "spore_root" and creature.tile_pos.distance_to(coord) <= 0.5:
			creature.queue_free()
	tile.spore_seed = false
	tile.biomass = 0.0
	_log_event("A spore root detonates and tears open nearby stone.")
	return true

func _try_den_spawns() -> void:
	for anchor in grid.den_anchors():
		var tile: DungeonTileData = grid.get_tile(anchor)
		tile.den_spawn_progress += 1
		if tile.den_spawn_progress < 18:
			continue
		tile.den_spawn_progress = 0
		if _creatures_near(anchor, 7) >= 4:
			continue
		var spawn_coord := _den_spawn_tile(tile.den_id)
		if spawn_coord == Vector2i(-1, -1):
			continue
		var species := _species_for_den(tile.den_id)
		_spawn_creature(species, spawn_coord)
		_log_event("Monster den spawns a %s." % species.replace("_", " "))

func _den_spawn_tile(den_id: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for coord in grid.den_tiles(den_id):
		if _creature_at(coord) == null:
			candidates.append(coord)
		for neighbor in grid.walkable_neighbors(coord):
			if _creature_at(neighbor) == null:
				candidates.append(neighbor)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates.pick_random()

func _species_for_den(den_id: int) -> String:
	var totals := {"magic": 0.0, "temperature": 0.0, "moisture": 0.0, "biomass": 0.0}
	var count := 0.0
	for coord in grid.den_tiles(den_id):
		var tile: DungeonTileData = grid.get_tile(coord)
		totals["magic"] += tile.magic
		totals["temperature"] += tile.temperature
		totals["moisture"] += tile.moisture
		totals["biomass"] += tile.biomass
		count += 1.0
	if count <= 0.0:
		return "goblin"
	var avg_magic: float = totals["magic"] / count
	var avg_heat: float = totals["temperature"] / count
	var avg_moisture: float = totals["moisture"] / count
	var avg_biomass: float = totals["biomass"] / count
	if avg_magic >= 65.0 and avg_heat >= 70.0:
		return "cinder_witch"
	if avg_moisture >= 60.0 and avg_biomass >= 35.0:
		return "bog_mite"
	if avg_heat >= 70.0:
		return "ember_imp"
	if avg_magic >= 65.0:
		return "hex_goblin"
	return "goblin"

func _spawn_incursion() -> void:
	var active_count := _active_adventurer_count()
	if active_count >= MAX_ACTIVE_CRAWLERS:
		_log_event("Crawler party waits outside; too many crawlers are already active.")
		return
	var roles: Array[String] = ["looter", "torchbearer", "hunter"]
	var count: int = 1 + int(resources.get_amount("fear") / 12)
	var party_explored_doors: Dictionary = {}
	for i in range(mini(clampi(count, 1, 5), MAX_ACTIVE_CRAWLERS - active_count)):
		var role: String = roles.pick_random()
		var adventurer: DungeonAdventurer = AdventurerScene.instantiate() as DungeonAdventurer
		grid.add_child(adventurer)
		adventurer.initialize(role, grid.entrance_tile, _find_incursion_target(role))
		adventurer.share_exploration_memory(party_explored_doors)
		adventurer.log_event.connect(_log_event)
		adventurer.hp += resources.get_amount("fear") * 0.25
		adventurers.append(adventurer)
	ui.show_message("A crawler party enters. Fear has reached %s." % resources.get_amount("fear"))
	_log_event("A crawler party enters. Fear %s." % resources.get_amount("fear"))

func _active_adventurer_count() -> int:
	var count := 0
	for adventurer in adventurers:
		if is_instance_valid(adventurer) and not adventurer.is_queued_for_deletion():
			count += 1
	return count

func _find_incursion_target(role: String) -> Vector2i:
	var heart := grid.find_structure("heart")
	var best: Vector2i = heart if heart != Vector2i(-1, -1) else grid.start_center
	var best_score: float = -9999.0
	for x in range(1, DungeonGrid.GRID_SIZE - 1):
		for y in range(1, DungeonGrid.GRID_SIZE - 1):
			var coord: Vector2i = Vector2i(x, y)
			if not grid.is_in_bounds(coord) or not grid.get_tile(coord).is_walkable():
				continue
			var tile: DungeonTileData = grid.get_tile(coord)
			var score: float = -coord.distance_to(best)
			if tile.structure == "heart":
				score += 220.0
			elif tile.structure == "treasure":
				score += 160.0
			if role == "torchbearer":
				score = tile.biomass * 1.5 + tile.darkness * 0.2
			elif role == "hunter":
				score = -coord.distance_to(grid.start_center) + _creature_density(coord) * 20.0
			if score > best_score:
				best_score = score
				best = coord
	return best

func _try_natural_spawn() -> void:
	natural_spawn_timer -= 0.28
	if natural_spawn_timer > 0.0:
		return
	natural_spawn_timer = randf_range(8.0, 15.0)
	if creatures.size() > 48:
		return
	var coord := _random_living_floor()
	if coord == Vector2i(-1, -1):
		return
	var tile = grid.get_tile(coord)
	if tile.moisture > 60.0 and tile.darkness > 70.0 and tile.biomass > 35.0 and randf() < 0.55:
		_spawn_creature("gloom_slug", coord)
	elif tile.biomass > 48.0 and randf() < 0.35:
		_spawn_creature("carrion_mite", coord)
	elif _count_species("needle_bat") < 3 and _count_prey() > 8 and randf() < 0.18:
		_spawn_creature("needle_bat", coord)

func _random_living_floor() -> Vector2i:
	for attempt in range(80):
		var coord := Vector2i(randi_range(1, DungeonGrid.GRID_SIZE - 2), randi_range(1, DungeonGrid.GRID_SIZE - 2))
		if grid.get_tile(coord).is_walkable() and grid.get_tile(coord).biomass > 20.0:
			return coord
	return Vector2i(-1, -1)

func _creature_at(coord: Vector2i):
	for creature in creatures:
		if is_instance_valid(creature) and creature.tile_pos == coord:
			return creature
	return null

func _adventurer_at(coord: Vector2i):
	for adventurer in adventurers:
		if is_instance_valid(adventurer) and adventurer.tile_pos == coord:
			return adventurer
	return null

func _prune_dead_entities() -> void:
	creatures = creatures.filter(func(creature) -> bool: return is_instance_valid(creature) and not creature.is_queued_for_deletion())
	adventurers = adventurers.filter(func(adventurer) -> bool: return is_instance_valid(adventurer) and not adventurer.is_queued_for_deletion())
	_check_heart_state()

func _check_heart_state() -> void:
	heart_coord = grid.find_structure("heart")
	if heart_coord == Vector2i(-1, -1):
		return
	var heart_tile: DungeonTileData = grid.get_tile(heart_coord)
	if heart_tile.heart_hp <= 0 and not dungeon_inert:
		dungeon_inert = true
		ui.set_phase("Game Over")
		ui.show_message("The dungeon Heart has been destroyed. The run is over.")
		_log_event("Game over: the dungeon Heart was destroyed.")

func _log_event(message: String) -> void:
	ui.add_log(message)

func _mutation_conditions_near(coord: Vector2i) -> String:
	var counts := {
		"bloat mite": 0,
		"ember mite": 0,
		"oracle slug": 0,
	}
	for x in range(coord.x - 3, coord.x + 4):
		for y in range(coord.y - 3, coord.y + 4):
			var nearby := Vector2i(x, y)
			if not grid.is_in_bounds(nearby):
				continue
			var tile = grid.get_tile(nearby)
			if tile.moisture > 68.0 and tile.biomass > 45.0:
				counts["bloat mite"] += 1
			if tile.temperature > 74.0:
				counts["ember mite"] += 1
			if tile.magic > 66.0 and tile.darkness > 76.0:
				counts["oracle slug"] += 1
	var lines: Array[String] = []
	for key in counts.keys():
		lines.append("%s: %s nearby tiles" % [key, counts[key]])
	return "\n".join(lines)

func _creature_density(coord: Vector2i) -> int:
	var count := 0
	for creature in creatures:
		if is_instance_valid(creature) and creature.tile_pos.distance_to(coord) <= 6.0:
			count += 1
	return count

func _creatures_near(coord: Vector2i, radius: int) -> int:
	var count := 0
	for creature in creatures:
		if is_instance_valid(creature) and not creature.is_queued_for_deletion() and creature.tile_pos.distance_to(coord) <= radius:
			count += 1
	return count

func _count_bosses() -> int:
	var count := 0
	for creature in creatures:
		if is_instance_valid(creature) and not creature.is_queued_for_deletion() and creature.species.begins_with("heart_"):
			count += 1
	return count

func _count_species(species_name: String) -> int:
	var count := 0
	for creature in creatures:
		if is_instance_valid(creature) and creature.species == species_name:
			count += 1
	return count

func _count_prey() -> int:
	var count := 0
	for creature in creatures:
		if is_instance_valid(creature) and creature.species in ["carrion_mite", "bloat_mite", "ember_mite", "gloom_slug", "oracle_slug"]:
			count += 1
	return count
