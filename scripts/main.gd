extends Node2D

const CreatureScene = preload("res://scenes/Creature.tscn")
const AdventurerScene = preload("res://scenes/Adventurer.tscn")
const DungeonTileScript = preload("res://scripts/tile_data.gd")
const MAX_ACTIVE_CRAWLERS := 32
const BOSS_RESPAWN_DELAY_TICKS := 215
const BOSS_RESPAWN_BIOMASS_COST := 120
const BOSS_RESPAWN_ESSENCE_COST := 60
const BASE_EXPAND_INFLUENCE_COST := 70
const EXPAND_INFLUENCE_COST_STEP := 30
const UNLIMITED_RESOURCE_AMOUNT := 999999
const RESEARCH_TICKS_PER_KNOWLEDGE := 8
const RESEARCH_UPGRADE_DEFS := {
	"dungeon_praxis": {"costs": [8, 14, 22], "label": "Dungeon Praxis", "prereqs": {}},
	"stonecraft": {"costs": [10, 18], "label": "Stonecraft", "prereqs": {"dungeon_praxis": 1}},
	"goblin_warrens": {"costs": [10], "label": "Goblin Warrens", "prereqs": {"dungeon_praxis": 1}},
	"hardened_brood": {"costs": [14, 22, 34], "label": "Hardened Brood", "prereqs": {"goblin_warrens": 1}},
	"quickened_brood": {"costs": [18, 28, 42], "label": "Quickened Brood", "prereqs": {"hardened_brood": 1}},
	"feral_vitality": {"costs": [22, 36], "label": "Feral Vitality", "prereqs": {"hardened_brood": 1}},
	"den_fertility": {"costs": [18, 30, 44], "label": "Den Fertility", "prereqs": {"quickened_brood": 1}},
	"skeleton_servitors": {"costs": [20], "label": "Skeleton Servitors", "prereqs": {"hardened_brood": 1}},
	"hexbound_kin": {"costs": [24], "label": "Hexbound Kin", "prereqs": {"dungeon_praxis": 2}},
	"ember_pact": {"costs": [28], "label": "Ember Pact", "prereqs": {"hexbound_kin": 1}},
	"bog_brood": {"costs": [28], "label": "Bog Brood", "prereqs": {"hardened_brood": 1}},
	"heart_pupation": {"costs": [24], "label": "Heart Pupation", "prereqs": {"dungeon_praxis": 2}},
	"heart_bulk": {"costs": [20, 34, 52], "label": "Heart Bulk", "prereqs": {"heart_pupation": 1}},
	"heart_violence": {"costs": [22, 38, 56], "label": "Heart Violence", "prereqs": {"heart_pupation": 1}},
	"heart_dominion": {"costs": [70], "label": "Heart Dominion", "prereqs": {"heart_bulk": 2, "heart_violence": 2}},
	"reinforced_doors": {"costs": [16, 28], "label": "Reinforced Doors", "prereqs": {"stonecraft": 1}},
	"poison_craft": {"costs": [18, 32], "label": "Poison Craft", "prereqs": {"dungeon_praxis": 1}},
	"hidden_ways": {"costs": [20, 34], "label": "Hidden Ways", "prereqs": {"stonecraft": 1}},
	"claimed_spoils": {"costs": [16, 28], "label": "Claimed Spoils", "prereqs": {"dungeon_praxis": 1}},
	"fearful_reclamation": {"costs": [34], "label": "Fearful Reclamation", "prereqs": {"claimed_spoils": 1}},
	"arcane_spawning": {"costs": [32], "label": "Arcane Spawning", "prereqs": {"hexbound_kin": 1}},
}
const BASE_TOOL_COSTS := {
	"dig": 1,
	"fill": 1,
	"place_heart": 0,
	"place_treasure": 5,
	"place_trap": 6,
	"place_poison_trap": 8,
	"place_door": 3,
	"place_locked_door": 7,
	"place_secret_tunnel": 4,
	"place_monster_den": 16,
	"place_carrion_den": 14,
	"move_heart": 20,
	"moisture_source": 5,
	"heat_vent": 5,
	"magic_seep": 8,
	"seed_spore_root": 6,
	"seed_carrion_mite": 4,
	"spawn_carrion_mite": 4,
	"poison_cloud": 6,
	"magic_field": 6,
	"heal": 5,
	"respawn_boss": 0,
	"explode_spores": 0,
	"expand_influence": 0,
	"den_order_guard_heart": 0,
	"den_order_guard_room": 0,
	"den_order_patrol": 0,
	"den_order_ambush_door": 0,
}

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
var drag_preview_active: bool = false
var drag_preview_tool: String = ""
var drag_preview_last_coord: Vector2i = Vector2i(-1, -1)
var drag_preview_tiles: Dictionary = {}
var sim_accumulator: float = 0.0
var incursion_timer: float = 22.0
var night_paused: bool = false
var wave_number: int = 0
var last_wave_size: int = 0
var last_wave_pressure: int = 0
var natural_spawn_timer: float = 6.0
var boss_respawn_ticks: int = 0
var camera_speed: float = 680.0
var run_mode: String = ""
var start_menu_active: bool = true
var action_failure_message: String = ""
var research_upgrades: Dictionary = {}
var tool_costs: Dictionary = BASE_TOOL_COSTS.duplicate()
var temporary_effect_tick: int = 0

func _ready() -> void:
	randomize()
	grid.generate_planning_map()
	simulation.configure(grid, resources)
	simulation.log_event.connect(_log_event)
	ui.bind_resources(resources)
	resources.changed.connect(func(_values: Dictionary) -> void: _sync_research_ui())
	ui.tool_selected.connect(func(tool: String) -> void: selected_tool = tool)
	ui.overlay_selected.connect(func(overlay: String) -> void: grid.set_overlay(overlay))
	ui.undo_requested.connect(_undo_planning_action)
	ui.start_requested.connect(_start_dungeon)
	ui.restart_requested.connect(_restart_run)
	ui.night_pause_toggled.connect(_set_night_paused)
	ui.den_order_requested.connect(_set_den_order_from_ui)
	ui.research_upgrade_requested.connect(_buy_research_upgrade)
	ui.mode_selected.connect(_select_run_mode)
	camera.position = grid.tile_to_world(grid.start_center)
	ui.set_phase("Planning Phase")
	_sync_night_ui()
	_sync_research_ui()
	_update_build_warnings()
	ui.show_message("Plan your first dungeon. Dig from the entrance, place the Heart, then start the run.")
	ui.show_start_menu()
	_log_event("New dungeon run started.")

func _process(delta: float) -> void:
	if start_menu_active:
		return
	_handle_camera(delta)
	if planning_phase or dungeon_inert:
		_sync_night_ui()
		return
	sim_accumulator += delta
	if sim_accumulator >= 0.28:
		sim_accumulator = 0.0
		_prune_dead_entities()
		simulation.step(creatures, adventurers)
		_apply_temporary_tile_effects()
		_check_heart_state()
		_update_boss_respawn_timer()
		_try_research_rooms()
		_try_den_spawns()
		_try_natural_spawn()
	if not night_paused:
		incursion_timer -= delta
		if incursion_timer <= 0.0:
			_spawn_incursion()
			incursion_timer = _next_wave_delay()
	_sync_night_ui()

func _unhandled_input(event: InputEvent) -> void:
	if start_menu_active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.08).clamp(Vector2(0.35, 0.35), Vector2(1.8, 1.8))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom * 0.92).clamp(Vector2(0.35, 0.35), Vector2(1.8, 1.8))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if ui.is_world_input_blocked():
				return
			var coord := grid.world_to_tile(get_global_mouse_position())
			if selected_tool in ["dig", "fill"]:
				_begin_drag_preview(coord)
			else:
				_handle_click(coord)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if drag_preview_active:
				_commit_drag_preview()
			is_dragging_tool = false
			last_drag_coord = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and drag_preview_active:
		if ui.is_world_input_blocked():
			return
		var drag_coord := grid.world_to_tile(get_global_mouse_position())
		if drag_coord != drag_preview_last_coord:
			_extend_drag_preview(drag_coord)

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

func _select_run_mode(mode: String) -> void:
	match mode:
		"standard":
			run_mode = "standard"
			start_menu_active = false
			ui.hide_start_menu()
			ui.set_phase("Planning Phase")
			ui.show_message("Plan your first dungeon. Dig from the entrance, place the Heart, then start the run.")
			_sync_night_ui()
			_sync_research_ui()
		"unlimited_build":
			run_mode = "unlimited_build"
			start_menu_active = false
			_apply_unlimited_build_mode()
			ui.hide_start_menu()
			ui.set_phase("Unlimited Build")
			ui.show_message("Unlimited Build: resources and research are unlocked for testing.")
			_sync_night_ui()
			_sync_research_ui()

func _apply_unlimited_build_mode() -> void:
	for resource_name in ["essence", "biomass", "magic", "bone", "fear", "knowledge"]:
		resources.set_amount(resource_name, UNLIMITED_RESOURCE_AMOUNT)
	research_upgrades.clear()
	for upgrade_id in RESEARCH_UPGRADE_DEFS.keys():
		var costs: Array = RESEARCH_UPGRADE_DEFS[upgrade_id].get("costs", [])
		research_upgrades[upgrade_id] = costs.size()
	tool_costs = BASE_TOOL_COSTS.duplicate()
	resources.set_looted_spoils_rank(_research_rank("claimed_spoils"))
	resources.set_fearful_reclamation_rank(_research_rank("fearful_reclamation"))

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
		ui.show_tile_info(coord, grid.get_tile(coord), _mutation_conditions_near(coord), grid.room_profile_from(coord))
		return
	if selected_tool == "expand_influence":
		_expand_influence_at(coord)
		return
	if planning_phase and not selected_tool in ["dig", "fill", "place_heart", "place_treasure", "place_trap", "place_poison_trap", "place_door", "place_locked_door", "place_secret_tunnel", "place_monster_den", "place_carrion_den", "move_heart", "moisture_source", "heat_vent", "magic_seep", "seed_spore_root", "expand_influence", "den_order_guard_heart", "den_order_guard_room", "den_order_patrol", "den_order_ambush_door"]:
		ui.show_message("Natural shaping unlocks after the dungeon starts. Use build tools during planning.")
		return
	if not _has_influence_for_tool(coord):
		return
	match selected_tool:
		"dig":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.dig(coord))
		"fill":
			if planning_phase:
				_erase_planning_tile(coord)
			else:
				_apply_tile_action(coord, selected_tool, func() -> bool: return _fill_preserving_heart_access(coord))
		"place_heart":
			_apply_tile_action(coord, selected_tool, func() -> bool: return _place_unique_structure(coord, "heart"))
		"move_heart":
			_apply_tile_action(coord, selected_tool, func() -> bool: return _move_heart(coord))
		"place_treasure":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_structure(coord, "treasure"))
		"place_trap":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_structure(coord, "trap"))
		"place_poison_trap":
			_apply_tile_action(coord, selected_tool, func() -> bool:
				if _research_rank("poison_craft") <= 0:
					return _fail_action("Research Poison Craft before placing poison traps.")
				return grid.place_structure(coord, "poison_trap")
			)
		"place_door":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_structure(coord, "door"))
		"place_locked_door":
			_apply_tile_action(coord, selected_tool, func() -> bool:
				if _research_rank("reinforced_doors") <= 0:
					return _fail_action("Research Reinforced Doors before placing locked doors.")
				var placed := grid.place_structure(coord, "locked_door")
				if placed:
					grid.get_tile(coord).door_hp += max(0, _research_rank("reinforced_doors") - 1) * 10
				return placed
			)
		"place_secret_tunnel":
			_apply_tile_action(coord, selected_tool, func() -> bool:
				if _research_rank("hidden_ways") <= 0:
					return _fail_action("Research Hidden Ways before placing secret tunnels.")
				return grid.place_structure(coord, "secret_tunnel")
			)
		"place_monster_den":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_monster_den(coord, "goblin"))
		"place_carrion_den":
			_apply_tile_action(coord, selected_tool, func() -> bool: return grid.place_carrion_den(coord))
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
		"seed_carrion_mite", "spawn_carrion_mite":
			_seed_carrion_mite(coord)
		"respawn_boss":
			_respawn_boss()
		"explode_spores":
			_explode_spores(coord)
		"poison_cloud":
			_place_poison_cloud(coord)
		"magic_field":
			_place_magic_field(coord)
		"heal":
			_heal_at(coord)
		"den_order_guard_heart":
			_set_den_order_at(coord, "guard_heart")
		"den_order_guard_room":
			_set_den_order_at(coord, "guard_room")
		"den_order_patrol":
			_set_den_order_at(coord, "patrol")
		"den_order_ambush_door":
			_set_den_order_at(coord, "ambush_door")
	grid.queue_redraw()

func _begin_drag_preview(coord: Vector2i) -> void:
	if not selected_tool in ["dig", "fill"]:
		_handle_click(coord)
		return
	drag_preview_active = true
	is_dragging_tool = true
	drag_preview_tool = selected_tool
	drag_preview_last_coord = coord
	last_drag_coord = coord
	drag_preview_tiles.clear()
	_add_drag_preview_line(coord, coord)
	_sync_drag_preview_to_grid()

func _extend_drag_preview(coord: Vector2i) -> void:
	if not drag_preview_active:
		return
	_add_drag_preview_line(drag_preview_last_coord, coord)
	drag_preview_last_coord = coord
	last_drag_coord = coord
	_sync_drag_preview_to_grid()

func _commit_drag_preview() -> void:
	if not drag_preview_active:
		return
	var committed_tool := drag_preview_tool
	var coords: Array[Vector2i] = []
	for coord in drag_preview_tiles.keys():
		coords.append(coord)
	drag_preview_active = false
	is_dragging_tool = false
	drag_preview_tool = ""
	drag_preview_last_coord = Vector2i(-1, -1)
	last_drag_coord = Vector2i(-1, -1)
	drag_preview_tiles.clear()
	grid.clear_drag_preview_tiles()
	match committed_tool:
		"dig":
			_commit_drag_dig(coords)
		"fill":
			_commit_drag_fill(coords)

func _add_drag_preview_line(from_coord: Vector2i, to_coord: Vector2i) -> void:
	var delta := to_coord - from_coord
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		if _can_preview_drag_tile(to_coord, drag_preview_tool):
			drag_preview_tiles[to_coord] = true
		return
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var coord := Vector2i(roundi(lerpf(from_coord.x, to_coord.x, t)), roundi(lerpf(from_coord.y, to_coord.y, t)))
		if _can_preview_drag_tile(coord, drag_preview_tool):
			drag_preview_tiles[coord] = true

func _can_preview_drag_tile(coord: Vector2i, tool: String) -> bool:
	if not grid.is_in_bounds(coord) or not grid.is_in_unlocked_chunk(coord):
		return false
	var tile: DungeonTileData = grid.get_tile(coord)
	match tool:
		"dig":
			return tile.is_diggable()
		"fill":
			if planning_phase:
				return tile.kind != DungeonTileScript.Kind.ENTRANCE and (tile.kind == DungeonTileScript.Kind.FLOOR or tile.structure != "" or tile.heat_source or tile.moisture_source or tile.magic_source or tile.spore_seed)
			return tile.kind == DungeonTileScript.Kind.FLOOR
	return false

func _sync_drag_preview_to_grid() -> void:
	var coords: Array[Vector2i] = []
	for coord in drag_preview_tiles.keys():
		coords.append(coord)
	grid.set_drag_preview_tiles(coords)

func _commit_drag_dig(coords: Array[Vector2i]) -> void:
	var valid: Array[Vector2i] = []
	for coord in coords:
		if _can_preview_drag_tile(coord, "dig"):
			valid.append(coord)
	if valid.is_empty():
		ui.show_message("No diggable tiles selected.")
		return
	var cost: int = int(tool_costs["dig"])
	var total_cost := cost * valid.size()
	if total_cost > 0 and not resources.spend("essence", total_cost):
		ui.show_message("Need %s essence." % total_cost)
		return
	var changed := 0
	grid.begin_tilemap_batch()
	for coord in valid:
		var before: Dictionary = grid.get_tile(coord).snapshot()
		if grid.dig(coord):
			changed += 1
			if planning_phase:
				grid.get_tile(coord).planning_floor_cost += cost
				planning_history.append({"coord": coord, "before": before, "cost": cost})
		elif cost > 0:
			resources.add("essence", cost)
	grid.end_tilemap_batch()
	if changed > 0:
		if planning_phase:
			_update_build_warnings()
		heart_coord = grid.find_structure("heart")
		ui.show_message("Dug %s tiles." % changed)

func _commit_drag_fill(coords: Array[Vector2i]) -> void:
	var valid: Array[Vector2i] = []
	for coord in coords:
		if _can_preview_drag_tile(coord, "fill"):
			valid.append(coord)
	if valid.is_empty():
		ui.show_message("No fillable tiles selected.")
		return
	if not _heart_path_survives_fill_batch(valid, planning_phase):
		ui.show_message("The Heart must remain reachable from the entrance.")
		return
	var changed := 0
	grid.begin_tilemap_batch()
	if planning_phase:
		for coord in valid:
			if _erase_planning_tile(coord, false, false):
				changed += 1
	else:
		var cost: int = int(tool_costs["fill"])
		var total_cost := cost * valid.size()
		if total_cost > 0 and not resources.spend("essence", total_cost):
			grid.end_tilemap_batch()
			ui.show_message("Need %s essence." % total_cost)
			return
		for coord in valid:
			if _fill_preserving_heart_access(coord):
				changed += 1
			elif cost > 0:
				resources.add("essence", cost)
	grid.end_tilemap_batch()
	if changed > 0:
		if planning_phase:
			_update_build_warnings()
		heart_coord = grid.find_structure("heart")
		ui.show_message("Filled %s tiles." % changed)

func _apply_tile_action(coord: Vector2i, tool: String, action: Callable) -> void:
	var cost: int = int(tool_costs.get(tool, 0))
	var before: Dictionary = grid.get_tile(coord).snapshot() if grid.is_in_bounds(coord) else {}
	if cost > 0 and not resources.spend("essence", cost):
		ui.show_message("Need %s essence." % cost)
		return
	action_failure_message = ""
	if not action.call():
		if cost > 0:
			resources.add("essence", cost)
		ui.show_message(action_failure_message if action_failure_message != "" else "That action cannot be used there.")
		return
	if planning_phase:
		var tile: DungeonTileData = grid.get_tile(coord)
		if tool == "dig":
			tile.planning_floor_cost += cost
		elif tool in ["place_heart", "place_treasure", "place_trap", "place_poison_trap", "place_door", "place_locked_door", "place_secret_tunnel", "place_monster_den", "place_carrion_den"]:
			tile.planning_structure_cost += cost
		planning_history.append({"coord": coord, "before": before, "cost": cost})
		_update_build_warnings()
	heart_coord = grid.find_structure("heart")

func _fail_action(message: String) -> bool:
	action_failure_message = message
	return false

func _heart_is_reachable() -> bool:
	var heart := grid.find_structure("heart")
	if heart == Vector2i(-1, -1):
		return false
	return grid.shortest_path_length(grid.entrance_tile, heart) >= 0

func _heart_path_survives_blocked_tiles(blocked_tiles: Array) -> bool:
	var heart := grid.find_structure("heart")
	if heart == Vector2i(-1, -1):
		return true
	var blocked: Dictionary = {}
	for raw_coord in blocked_tiles:
		var coord: Vector2i = raw_coord
		if not grid.is_in_bounds(coord):
			continue
		if coord == heart:
			return false
		blocked[coord] = true
	return grid.shortest_path_length_avoiding(grid.entrance_tile, heart, blocked) >= 0

func _heart_path_survives_fill_batch(coords: Array[Vector2i], is_planning: bool) -> bool:
	var heart := grid.find_structure("heart")
	if heart == Vector2i(-1, -1):
		return true
	var blocked: Dictionary = {}
	for coord in coords:
		if not grid.is_in_bounds(coord):
			continue
		var tile: DungeonTileData = grid.get_tile(coord)
		if is_planning and tile.structure == "heart":
			return true
		if not is_planning and tile.structure == "heart":
			return false
		var clears_floor := tile.kind == DungeonTileScript.Kind.FLOOR and tile.structure == "" and not tile.secret_tunnel
		if is_planning and (tile.heat_source or tile.moisture_source or tile.magic_source or tile.spore_seed):
			clears_floor = false
		if clears_floor:
			blocked[coord] = true
	if blocked.is_empty():
		return true
	return grid.shortest_path_length_avoiding(grid.entrance_tile, heart, blocked) >= 0

func _fill_preserving_heart_access(coord: Vector2i) -> bool:
	if not grid.is_in_bounds(coord):
		return false
	var tile: DungeonTileData = grid.get_tile(coord)
	if tile.kind != DungeonTileScript.Kind.FLOOR:
		return false
	if tile.structure == "heart":
		return _fail_action("The Heart cannot be filled in.")
	if tile.structure != "" or tile.secret_tunnel:
		return grid.fill(coord)
	if not _heart_path_survives_blocked_tiles([coord]):
		return _fail_action("The Heart must remain reachable from the entrance.")
	return grid.fill(coord)

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

func _erase_planning_tile(coord: Vector2i, announce: bool = true, refresh_warnings: bool = true) -> bool:
	if not grid.is_in_bounds(coord):
		return false
	if not grid.is_in_unlocked_chunk(coord):
		if announce:
			ui.show_message("Expand influence into that chunk before shaping it.")
		return false
	var tile: DungeonTileData = grid.get_tile(coord)
	if tile.kind == DungeonTileScript.Kind.ENTRANCE:
		if announce:
			ui.show_message("The entrance cannot be erased.")
		return false
	if tile.structure == "monster_den":
		var den_refund := 0
		for den_tile_coord in grid.den_tiles(tile.den_id):
			den_refund += grid.get_tile(den_tile_coord).planning_structure_cost
		grid.clear_monster_den(tile.den_id)
		resources.add("essence", den_refund)
		if refresh_warnings:
			_update_build_warnings()
		if announce:
			ui.show_message("Monster den erased. Refunded %s essence." % den_refund)
		return true
	if tile.structure != "" or tile.secret_tunnel:
		var refund: int = tile.planning_structure_cost
		grid.clear_structure(coord)
		tile.planning_structure_cost = 0
		resources.add("essence", refund)
		heart_coord = grid.find_structure("heart")
		if refresh_warnings:
			_update_build_warnings()
		if announce:
			ui.show_message("Structure erased. Refunded %s essence." % refund)
		grid.queue_redraw()
		return true
	if tile.heat_source or tile.moisture_source or tile.magic_source or tile.spore_seed:
		var source_refund: int = tile.planning_structure_cost
		tile.heat_source = false
		tile.moisture_source = false
		tile.magic_source = false
		tile.spore_seed = false
		tile.planning_structure_cost = 0
		resources.add("essence", source_refund)
		if refresh_warnings:
			_update_build_warnings()
		if announce:
			ui.show_message("Source erased. Refunded %s essence." % source_refund)
		grid.queue_redraw()
		return true
	if tile.kind == DungeonTileScript.Kind.FLOOR:
		if not _heart_path_survives_blocked_tiles([coord]):
			if announce:
				ui.show_message("The Heart must remain reachable from the entrance.")
			return false
		var floor_refund: int = tile.planning_floor_cost
		tile.set_stone()
		resources.add("essence", floor_refund)
		if refresh_warnings:
			_update_build_warnings()
		if announce:
			ui.show_message("Floor erased. Refunded %s essence." % floor_refund)
		grid.call("_mark_tilemap_layers_dirty", coord)
		return true
	if announce:
		ui.show_message("Nothing planned there to erase.")
	return false

func _place_unique_structure(coord: Vector2i, structure_name: String) -> bool:
	if grid.find_structure(structure_name) != Vector2i(-1, -1):
		return false
	if structure_name == "heart" and grid.shortest_path_length(grid.entrance_tile, coord) < 0:
		return _fail_action("The Heart needs an open path from the entrance.")
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
	if grid.shortest_path_length(grid.entrance_tile, coord) < 0:
		return _fail_action("The Heart needs an open path from the entrance.")
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
	if entry.get("type", "") == "unlock_chunk":
		grid.lock_chunk(entry["chunk"])
		resources.add("essence", int(entry["cost"]))
		_update_build_warnings()
		ui.show_message("Influence expansion undone.")
		return
	var coord: Vector2i = entry["coord"]
	grid.get_tile(coord).restore(entry["before"])
	resources.add("essence", int(entry["cost"]))
	heart_coord = grid.find_structure("heart")
	_update_build_warnings()
	ui.show_message("Planning action undone.")

func _start_dungeon() -> void:
	if start_menu_active and run_mode == "":
		_select_run_mode("standard")
	heart_coord = grid.find_structure("heart")
	if heart_coord == Vector2i(-1, -1):
		ui.show_message("The dungeon needs a Heart before it can awaken.")
		return
	if not _heart_is_reachable():
		ui.show_message("The Heart needs an open path from the entrance before the dungeon can awaken.")
		return
	planning_phase = false
	planning_history.clear()
	ui.set_phase("Live Dungeon")
	_update_build_warnings()
	_seed_initial_ecosystem()
	_spawn_boss_larva()
	incursion_timer = 7.0
	night_paused = false
	wave_number = 0
	last_wave_size = 0
	last_wave_pressure = 0
	_sync_night_ui()
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
	drag_preview_active = false
	drag_preview_tool = ""
	drag_preview_last_coord = Vector2i(-1, -1)
	drag_preview_tiles.clear()
	sim_accumulator = 0.0
	incursion_timer = 22.0
	night_paused = false
	wave_number = 0
	last_wave_size = 0
	last_wave_pressure = 0
	natural_spawn_timer = 6.0
	boss_respawn_ticks = 0
	run_mode = ""
	start_menu_active = true
	research_upgrades.clear()
	tool_costs = BASE_TOOL_COSTS.duplicate()
	resources.reset()
	grid.generate_planning_map()
	camera.position = grid.tile_to_world(grid.start_center)
	ui.set_phase("Planning Phase")
	_sync_night_ui()
	_sync_research_ui()
	_update_build_warnings()
	ui.show_message("Plan your next dungeon. Place the Heart, then start the run.")
	ui.show_start_menu()
	_log_event("Run restarted.")

func _update_build_warnings() -> void:
	ui.set_warnings(grid.get_build_warnings())

func _has_influence_for_tool(coord: Vector2i) -> bool:
	if grid.is_in_unlocked_chunk(coord):
		return true
	ui.show_message("Expand influence into that 32x32 chunk before shaping it.")
	return false

func _expand_influence_at(coord: Vector2i) -> bool:
	if not grid.is_in_bounds(coord):
		return false
	var chunk: Vector2i = grid.chunk_for_coord(coord)
	if grid.is_chunk_unlocked(chunk):
		ui.show_message("That chunk is already under dungeon influence.")
		return false
	if not grid.can_unlock_chunk(chunk):
		ui.show_message("Influence can only expand into an adjacent 32x32 chunk.")
		return false
	var cost := _expand_influence_cost()
	if not resources.spend("essence", cost):
		ui.show_message("Need %s essence to expand influence." % cost)
		return false
	if not grid.unlock_chunk(chunk):
		resources.add("essence", cost)
		ui.show_message("Influence cannot expand there.")
		return false
	if planning_phase:
		planning_history.append({"type": "unlock_chunk", "chunk": chunk, "cost": cost})
	_update_build_warnings()
	ui.show_message("Influence spreads into chunk %s,%s." % [chunk.x, chunk.y])
	_log_event("The dungeon expands influence into chunk %s,%s." % [chunk.x, chunk.y])
	return true

func _expand_influence_cost() -> int:
	if run_mode == "unlimited_build":
		return 0
	return BASE_EXPAND_INFLUENCE_COST + maxi(grid.unlocked_chunk_count() - 1, 0) * EXPAND_INFLUENCE_COST_STEP

func _set_night_paused(paused: bool) -> void:
	if planning_phase or dungeon_inert:
		night_paused = false
	else:
		night_paused = paused
	_sync_night_ui()

func _sync_night_ui() -> void:
	if ui != null:
		ui.set_night_countdown(incursion_timer, night_paused, planning_phase, dungeon_inert, wave_number + 1, _wave_pressure_for_next_wave())

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

func _place_poison_cloud(coord: Vector2i) -> bool:
	if not grid.get_tile(coord).is_walkable():
		ui.show_message("Poison clouds need open dungeon floor.")
		return false
	var cost: int = int(tool_costs.get("poison_cloud", 0))
	if cost > 0 and not resources.spend("magic", cost):
		ui.show_message("Need %s magic." % cost)
		return false
	for x in range(coord.x - 1, coord.x + 2):
		for y in range(coord.y - 1, coord.y + 2):
			var cloud_coord := Vector2i(x, y)
			if not grid.is_in_bounds(cloud_coord):
				continue
			var tile: DungeonTileData = grid.get_tile(cloud_coord)
			if tile.is_walkable():
				tile.poison_cloud_ticks = 10
				tile.poison_cloud_damage = 1.8
	_log_event("A poison cloud blooms in the dungeon.")
	grid.queue_redraw()
	return true

func _place_magic_field(coord: Vector2i) -> bool:
	if not grid.get_tile(coord).is_walkable():
		ui.show_message("Magic fields need open dungeon floor.")
		return false
	var cost: int = int(tool_costs.get("magic_field", 0))
	if cost > 0 and not resources.spend("magic", cost):
		ui.show_message("Need %s magic." % cost)
		return false
	for x in range(coord.x - 1, coord.x + 2):
		for y in range(coord.y - 1, coord.y + 2):
			var field_coord := Vector2i(x, y)
			if not grid.is_in_bounds(field_coord):
				continue
			var tile: DungeonTileData = grid.get_tile(field_coord)
			if tile.is_walkable():
				tile.magic_field_ticks = 12
				tile.magic = min(tile.magic + 6.0, 100.0)
	_log_event("A strengthening magic field hums open.")
	grid.queue_redraw()
	return true

func _heal_at(coord: Vector2i) -> bool:
	if not grid.is_in_bounds(coord):
		return false
	var cost: int = int(tool_costs.get("heal", 0))
	var creature = _creature_at(coord)
	var heart_tile: DungeonTileData = grid.get_tile(coord)
	if creature == null and heart_tile.structure != "heart":
		ui.show_message("Heal needs a monster, boss, or the Heart.")
		return false
	if cost > 0 and not resources.spend("magic", cost):
		ui.show_message("Need %s magic." % cost)
		return false
	if creature != null:
		creature.hp = min(creature.hp + 18.0, max(creature.max_hp, creature.hp + 1.0))
		_log_event("The dungeon knits a wounded %s." % creature.species.replace("_", " "))
		return true
	heart_tile.heart_hp = mini(120, heart_tile.heart_hp + 20)
	_log_event("The Heart drinks a rare pulse of healing magic.")
	grid.queue_redraw()
	return true

func _apply_temporary_tile_effects() -> void:
	temporary_effect_tick += 1
	for x in range(DungeonGrid.GRID_SIZE):
		for y in range(DungeonGrid.GRID_SIZE):
			var tile: DungeonTileData = grid.get_tile(Vector2i(x, y))
			if tile.poison_cloud_ticks > 0:
				tile.poison_cloud_ticks -= 1
			if tile.magic_field_ticks > 0:
				tile.magic_field_ticks -= 1
	for adventurer in adventurers:
		if not is_instance_valid(adventurer) or adventurer.is_queued_for_deletion():
			continue
		if not grid.is_in_bounds(adventurer.tile_pos):
			continue
		var tile: DungeonTileData = grid.get_tile(adventurer.tile_pos)
		if tile.poison_cloud_ticks > 0:
			adventurer.hp -= max(tile.poison_cloud_damage, 1.0)
			if temporary_effect_tick % 3 == 0:
				_log_event("%s coughs in a poison cloud." % String(adventurer.role).capitalize())
	for creature in creatures:
		if not is_instance_valid(creature) or creature.is_queued_for_deletion():
			continue
		if not grid.is_in_bounds(creature.tile_pos):
			continue
		if grid.get_tile(creature.tile_pos).magic_field_ticks > 0:
			creature.apply_magic_field_bonus(5, 2.0)
	grid.queue_redraw()

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
	var spawn_coord := _nearest_open_creature_tile(coord)
	if spawn_coord == Vector2i(-1, -1):
		return null
	var creature: DungeonCreature = CreatureScene.instantiate() as DungeonCreature
	grid.add_child(creature)
	creature.initialize(species, spawn_coord)
	_apply_research_bonuses(creature)
	creature.log_event.connect(_log_event)
	creatures.append(creature)
	return creature

func _apply_research_bonuses(creature: DungeonCreature) -> void:
	if creature.species in ["goblin", "skeleton_servitor", "hex_goblin", "ember_imp", "bog_mite", "cinder_witch"]:
		var hardened_rank := _research_rank("hardened_brood")
		if hardened_rank > 0:
			creature.hp += 5.0 * hardened_rank
			creature.max_hp += 5.0 * hardened_rank
			if not creature.traits.has("hardened"):
				creature.traits.append("hardened")
		var quickened_rank := _research_rank("quickened_brood")
		if quickened_rank > 0:
			creature.move_cooldown = -quickened_rank
			if not creature.traits.has("quickened"):
				creature.traits.append("quickened")
		var lifesteal_rank := _research_rank("feral_vitality")
		if lifesteal_rank > 0:
			creature.lifesteal_chance = 0.06 * lifesteal_rank
			if not creature.traits.has("lifesteal"):
				creature.traits.append("lifesteal")
	if creature.species.begins_with("heart_"):
		var bulk_rank := _research_rank("heart_bulk")
		if bulk_rank > 0:
			creature.hp += 25.0 * bulk_rank
			creature.max_hp += 25.0 * bulk_rank
			if not creature.traits.has("bulked"):
				creature.traits.append("bulked")
		var violence_rank := _research_rank("heart_violence")
		if violence_rank > 0:
			creature.attack_bonus += 4.0 * violence_rank
			if not creature.traits.has("violent"):
				creature.traits.append("violent")
		creature.boss_can_evolve = _research_rank("heart_pupation") > 0

func _nearest_open_creature_tile(coord: Vector2i) -> Vector2i:
	if grid.is_in_bounds(coord) and grid.get_tile(coord).is_walkable() and _creature_at(coord) == null:
		return coord
	var frontier: Array[Vector2i] = [coord]
	var visited: Dictionary = {coord: true}
	var cursor := 0
	while cursor < frontier.size() and cursor < 96:
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for neighbor in grid.walkable_neighbors(current):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			if _creature_at(neighbor) == null:
				return neighbor
			frontier.append(neighbor)
	return Vector2i(-1, -1)

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
		if tile.den_order == "research":
			continue
		tile.den_spawn_progress += 1
		var spawn_threshold: int = max(6, 18 - _research_rank("den_fertility") * 6)
		if tile.den_spawn_progress < spawn_threshold:
			continue
		tile.den_spawn_progress = 0
		if _creatures_near(anchor, 7) >= 4:
			continue
		var spawn_coord := _den_spawn_tile(tile.den_id)
		if spawn_coord == Vector2i(-1, -1):
			continue
		var species := _species_for_den(tile.den_id)
		var spawned := _spawn_creature(species, spawn_coord)
		if spawned != null:
			_configure_den_spawn(spawned, tile.den_id)
		_log_event("%s spawns a %s." % [_den_display_name(tile.den_id), species.replace("_", " ")])

func _try_research_rooms() -> void:
	for anchor in grid.den_anchors():
		var tile: DungeonTileData = grid.get_tile(anchor)
		if tile.den_order != "research":
			continue
		if not _den_is_qualified_research_room(tile.den_id):
			continue
		var scholars := _research_scholars_for_den(tile.den_id)
		if scholars <= 0:
			var spawned := _spawn_creature("goblin", anchor)
			if spawned != null:
				_configure_den_spawn(spawned, tile.den_id)
				scholars = 1
		if scholars <= 0:
			continue
		tile.den_research_progress += scholars
		if tile.den_research_progress >= RESEARCH_TICKS_PER_KNOWLEDGE:
			var gained := maxi(1, int(tile.den_research_progress / RESEARCH_TICKS_PER_KNOWLEDGE))
			tile.den_research_progress %= RESEARCH_TICKS_PER_KNOWLEDGE
			resources.add("knowledge", gained)
			_log_event("A research den distills %s knowledge." % gained)

func _research_scholars_for_den(den_id: int) -> int:
	var anchor := grid.den_anchor_for_id(den_id)
	if anchor == Vector2i(-1, -1):
		return 0
	var room := grid.room_tiles_from(anchor)
	var room_lookup := {}
	for coord in room:
		room_lookup[coord] = true
	var count := 0
	for creature in creatures:
		if not is_instance_valid(creature) or creature.is_queued_for_deletion():
			continue
		if creature.den_id == den_id and creature.species in ["goblin", "hex_goblin"]:
			if room_lookup.has(creature.tile_pos):
				count += 1
	return count

func _den_is_qualified_research_room(den_id: int) -> bool:
	var anchor := grid.den_anchor_for_id(den_id)
	if anchor == Vector2i(-1, -1):
		return false
	if grid.nearest_room_door(anchor) == Vector2i(-1, -1):
		return false
	var room := grid.room_tiles_from(anchor)
	var magic_total := 0.0
	for coord in room:
		var tile: DungeonTileData = grid.get_tile(coord)
		if tile.magic_source:
			return true
		magic_total += tile.magic
	return not room.is_empty() and magic_total / float(room.size()) >= 42.0

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

func _configure_den_spawn(creature: DungeonCreature, den_id: int) -> void:
	var anchor := grid.den_anchor_for_id(den_id)
	if anchor == Vector2i(-1, -1):
		return
	var den_tile: DungeonTileData = grid.get_tile(anchor)
	creature.den_id = den_id
	creature.den_order = den_tile.den_order
	creature.home_tile = anchor
	creature.command_target = _den_command_target(anchor, den_tile.den_order)

func _set_den_order_at(coord: Vector2i, order: String) -> bool:
	if not grid.is_in_bounds(coord):
		return false
	var tile: DungeonTileData = grid.get_tile(coord)
	if tile.den_id == -1:
		ui.show_message("Click a den to assign that order.")
		return false
	return _set_den_order_for_den(tile.den_id, order, true)

func _set_den_order_from_ui(den_id: int, order: String) -> void:
	var anchor := grid.den_anchor_for_id(den_id)
	if _set_den_order_for_den(den_id, order, false) and anchor != Vector2i(-1, -1):
		ui.show_tile_info(anchor, grid.get_tile(anchor), _mutation_conditions_near(anchor), grid.room_profile_from(anchor))

func _set_den_order_for_den(den_id: int, order: String, show_message_on_success: bool = true) -> bool:
	var anchor := grid.den_anchor_for_id(den_id)
	if anchor == Vector2i(-1, -1):
		return false
	if order == "research" and not _den_is_qualified_research_room(den_id):
		ui.show_message("Research dens need a magical room with a door boundary.")
		return false
	var target := _den_command_target(anchor, order)
	if order == "ambush_door" and target == Vector2i(-1, -1):
		ui.show_message("That den's room has no door to ambush.")
		return false
	grid.set_den_order(den_id, order, target)
	for creature in creatures:
		if is_instance_valid(creature) and creature.den_id == den_id:
			creature.den_order = order
			creature.command_target = target
	if show_message_on_success:
		ui.show_message("%s order: %s." % [_den_display_name(den_id), order.replace("_", " ").capitalize()])
	return true

func _den_display_name(den_id: int) -> String:
	var anchor := grid.den_anchor_for_id(den_id)
	if anchor == Vector2i(-1, -1):
		return "Den"
	return "Carrion den" if grid.get_tile(anchor).den_kind == "carrion" else "Goblin den"

func _den_command_target(anchor: Vector2i, order: String) -> Vector2i:
	match order:
		"guard_heart":
			return grid.find_structure("heart")
		"guard_room":
			return grid.room_center_tile(anchor)
		"patrol":
			return anchor
		"ambush_door":
			var door := grid.nearest_room_door(anchor)
			if door != Vector2i(-1, -1):
				return door
		"research":
			return anchor
	return grid.room_center_tile(anchor)

func _species_for_den(den_id: int) -> String:
	var anchor := grid.den_anchor_for_id(den_id)
	if anchor != Vector2i(-1, -1) and grid.get_tile(anchor).den_kind == "carrion":
		return "carrion_mite"
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
		if _research_rank("ember_pact") <= 0:
			return "hex_goblin" if _research_rank("hexbound_kin") > 0 else "goblin"
		return "cinder_witch"
	if avg_moisture >= 60.0 and avg_biomass >= 35.0:
		if _research_rank("bog_brood") <= 0:
			return "goblin"
		return "bog_mite"
	if avg_heat >= 70.0:
		if _research_rank("ember_pact") <= 0:
			return "goblin"
		return "ember_imp"
	if avg_magic >= 65.0:
		if _research_rank("arcane_spawning") > 0:
			return "cinder_witch"
		return "hex_goblin" if _research_rank("hexbound_kin") > 0 else "goblin"
	if _research_rank("skeleton_servitors") > 0 and avg_biomass >= 20.0:
		return "skeleton_servitor"
	return "goblin"

func _buy_research_upgrade(upgrade_id: String) -> bool:
	if not RESEARCH_UPGRADE_DEFS.has(upgrade_id):
		return false
	var definition: Dictionary = RESEARCH_UPGRADE_DEFS[upgrade_id]
	var costs: Array = definition.get("costs", [])
	var current_rank := _research_rank(upgrade_id)
	if current_rank >= costs.size():
		ui.show_message("Research already completed.")
		return false
	if not _research_prereqs_met(definition.get("prereqs", {})):
		ui.show_message("Research prerequisites are not met.")
		return false
	var cost: int = int(costs[current_rank])
	if not resources.spend("knowledge", cost):
		ui.show_message("Need %s knowledge." % cost)
		return false
	research_upgrades[upgrade_id] = current_rank + 1
	_apply_research_side_effect(upgrade_id)
	_apply_research_upgrade_to_existing(upgrade_id)
	_sync_research_ui()
	ui.show_message("Research complete: %s %s." % [String(definition["label"]), current_rank + 1])
	_log_event("Research complete: %s %s." % [String(definition["label"]), current_rank + 1])
	return true

func _research_rank(upgrade_id: String) -> int:
	return int(research_upgrades.get(upgrade_id, 0))

func _research_prereqs_met(prereqs: Dictionary) -> bool:
	for upgrade_id in prereqs.keys():
		if _research_rank(upgrade_id) < int(prereqs[upgrade_id]):
			return false
	return true

func _apply_research_side_effect(upgrade_id: String) -> void:
	match upgrade_id:
		"stonecraft":
			tool_costs["dig"] = maxi(0, 1 - _research_rank("stonecraft"))
		"poison_craft":
			tool_costs["place_poison_trap"] = maxi(4, 8 - _research_rank("poison_craft"))
		"reinforced_doors":
			tool_costs["place_locked_door"] = maxi(4, 7 - _research_rank("reinforced_doors"))
		"claimed_spoils":
			resources.set_looted_spoils_rank(_research_rank("claimed_spoils"))
		"fearful_reclamation":
			resources.set_fearful_reclamation_rank(_research_rank("fearful_reclamation"))

func _apply_research_upgrade_to_existing(upgrade_id: String) -> void:
	for creature in creatures:
		if not is_instance_valid(creature) or creature.is_queued_for_deletion():
			continue
		match upgrade_id:
			"hardened_brood":
				if creature.species in ["goblin", "skeleton_servitor", "hex_goblin", "ember_imp", "bog_mite", "cinder_witch"]:
					creature.hp += 5.0
					creature.max_hp += 5.0
					if not creature.traits.has("hardened"):
						creature.traits.append("hardened")
			"quickened_brood":
				if creature.species in ["goblin", "skeleton_servitor", "hex_goblin", "ember_imp", "bog_mite", "cinder_witch"]:
					creature.move_cooldown = min(creature.move_cooldown, -_research_rank("quickened_brood"))
					if not creature.traits.has("quickened"):
						creature.traits.append("quickened")
			"feral_vitality":
				if not creature.species.begins_with("heart_"):
					creature.lifesteal_chance = max(creature.lifesteal_chance, 0.06 * _research_rank("feral_vitality"))
					if not creature.traits.has("lifesteal"):
						creature.traits.append("lifesteal")
			"heart_bulk":
				if creature.species.begins_with("heart_"):
					creature.hp += 45.0
					creature.max_hp += 45.0
					if not creature.traits.has("bulked"):
						creature.traits.append("bulked")
			"heart_violence":
				if creature.species.begins_with("heart_"):
					creature.attack_bonus += 4.0
					if not creature.traits.has("violent"):
						creature.traits.append("violent")
			"heart_pupation":
				if creature.species.begins_with("heart_"):
					creature.boss_can_evolve = true

func _sync_research_ui() -> void:
	if ui != null:
		ui.set_research_state(research_upgrades, resources.get_amount("knowledge"), RESEARCH_UPGRADE_DEFS)

func _spawn_incursion() -> void:
	var active_count := _active_adventurer_count()
	if active_count >= MAX_ACTIVE_CRAWLERS:
		_log_event("Crawler party waits outside; too many crawlers are already active.")
		return
	wave_number += 1
	last_wave_pressure = _wave_pressure_for_wave(wave_number)
	var roles: Array[String] = _roles_for_wave(wave_number)
	var count: int = _wave_size_for_pressure(last_wave_pressure)
	var party_explored_doors: Dictionary = {}
	last_wave_size = mini(clampi(count, 1, 8), MAX_ACTIVE_CRAWLERS - active_count)
	for i in range(last_wave_size):
		var role: String = roles.pick_random()
		var adventurer: DungeonAdventurer = AdventurerScene.instantiate() as DungeonAdventurer
		grid.add_child(adventurer)
		adventurer.initialize(role, grid.entrance_tile, _find_incursion_target(role))
		adventurer.secret_tunnel_discover_chance = 0.04 / max(1, _research_rank("hidden_ways"))
		adventurer.share_exploration_memory(party_explored_doors)
		adventurer.log_event.connect(_log_event)
		adventurer.hp += float(last_wave_pressure) * 0.65
		adventurers.append(adventurer)
	ui.show_message("Wave %s enters. Pressure %s." % [wave_number, last_wave_pressure])
	_log_event("Wave %s enters with %s crawlers. Pressure %s." % [wave_number, last_wave_size, last_wave_pressure])
	_sync_night_ui()

func _wave_pressure_for_next_wave() -> int:
	return _wave_pressure_for_wave(wave_number + 1)

func _wave_pressure_for_wave(target_wave: int) -> int:
	return maxi(1, target_wave + int(resources.get_amount("fear") / 18))

func _wave_size_for_pressure(pressure: int) -> int:
	return clampi(1 + int(ceil(float(pressure) / 2.0)), 2, 8)

func _roles_for_wave(target_wave: int) -> Array[String]:
	var roles: Array[String] = ["looter"]
	if target_wave >= 2 or resources.get_amount("fear") >= 10:
		roles.append("torchbearer")
	if target_wave >= 3 or resources.get_amount("fear") >= 24:
		roles.append("hunter")
	return roles

func _next_wave_delay() -> float:
	var pressure := _wave_pressure_for_next_wave()
	return clampf(46.0 - float(pressure) * 2.4, 18.0, 44.0)

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
