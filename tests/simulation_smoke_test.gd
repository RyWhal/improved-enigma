extends SceneTree

const GridScript = preload("res://scripts/grid.gd")
const SimulationScript = preload("res://scripts/simulation.gd")
const ResourcesScript = preload("res://scripts/resources.gd")
const CreatureScript = preload("res://scripts/creature.gd")
const AdventurerScript = preload("res://scripts/adventurer.gd")
const UIScript = preload("res://scripts/ui.gd")
const MainScene = preload("res://scenes/Main.tscn")

var failures: int = 0

func _initialize() -> void:
	randomize()
	_test_cave_generation()
	_test_editor_preview_generation()
	_test_planning_map_starts_mostly_solid()
	_test_build_warnings_are_warning_only()
	await _test_hud_does_not_block_world_input()
	await _test_hud_uses_collapsed_menus_and_top_resource_bar()
	await _test_planning_heart_is_free_and_fill_refunds()
	await _test_build_phase_sources_and_monster_den()
	await _test_monster_den_requires_clear_2x2()
	await _test_live_heart_can_be_moved_for_essence()
	await _test_live_fill_removes_door()
	await _test_essence_can_seed_emergency_mite()
	await _test_incursions_do_not_spawn_without_active_crawler_room()
	_test_background_essence_drip()
	_test_diffusion_and_growth()
	_test_magic_seep_has_local_falloff()
	_test_crawler_kills_give_limited_biomass()
	_test_mite_defends_against_nearby_crawler()
	await _test_monster_den_spawns_by_environment()
	await _test_heart_larva_spawns_and_stays_near_heart()
	await _test_boss_larva_is_sturdier_and_hits_harder()
	await _test_boss_can_be_respawned_after_delay()
	await _test_direct_mite_spam_cost_increases()
	await _test_exploding_spores_damage_crawlers_and_break_walls()
	_test_heart_is_durable_defenseless_and_does_not_regen()
	_test_crawler_retargets_to_treasure_then_heart()
	_test_crawler_cannot_sense_heart_beyond_door()
	_test_crawler_randomly_explores_multiple_doors()
	_test_crawler_keeps_chosen_door_until_reached()
	_test_crawler_commits_to_crossing_door()
	_test_crawler_does_not_reselect_explored_door_from_next_room()
	_test_crawler_wave_shares_explored_doors()
	_test_crawler_can_progress_through_door()
	_test_crawler_targets_visible_magic_source_before_heart()
	_test_crawler_disrupts_any_source_then_continues()
	_test_crawler_attacks_visible_creature()
	_test_crawler_does_not_farm_knowledge_each_magic_step()
	_test_mutation_pressure()
	if failures == 0:
		print("Dungeon Tycoon smoke tests passed")
	quit(failures)

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_cave_generation() -> void:
	var grid = GridScript.new()
	grid.call("generate_cave")
	_require(grid.tiles.size() == 120, "grid should have 120 columns")
	_require(grid.tiles[0].size() == 120, "grid should have 120 rows")
	_require(grid.call("get_tile", grid.start_center).is_walkable(), "starting chamber should be walkable")
	_require(grid.call("get_tile", grid.entrance_tile).is_walkable(), "entrance should be walkable")
	_require(grid.call("get_tile", Vector2i(12, 12)).is_diggable(), "stone should be diggable")
	grid.free()

func _test_editor_preview_generation() -> void:
	var grid = GridScript.new()
	grid.call("ensure_preview_generated")
	_require(grid.tiles.size() == 120, "editor preview should generate the grid")
	_require(grid.call("get_tile", grid.entrance_tile).is_walkable(), "editor preview should show the entrance")
	grid.free()

func _test_planning_map_starts_mostly_solid() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	_require(not grid.call("get_tile", grid.start_center).is_walkable(), "planning map should not start with an open chamber")
	_require(grid.call("get_tile", grid.entrance_tile).is_walkable(), "planning map should include an entrance")
	_require(grid.call("dig", grid.start_center), "planning map should let the player dig initial rooms")
	grid.free()

func _test_build_warnings_are_warning_only() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	var heart = grid.start_center
	grid.call("dig", heart)
	grid.call("place_structure", heart, "heart")
	var warnings = grid.call("get_build_warnings")
	_require(warnings.has("Heart unreachable from entrance."), "warnings should catch unreachable Heart")
	grid.free()

func _test_hud_does_not_block_world_input() -> void:
	var ui = UIScript.new()
	get_root().add_child(ui)
	await process_frame
	var hud_root = ui.get_node("HudRoot")
	_require(hud_root.mouse_filter == Control.MOUSE_FILTER_PASS, "HUD root should pass unhandled clicks to the world")
	_require(not ui.call("should_block_world_input", hud_root), "HUD root hover should not block world clicks")
	_require(ui.call("should_block_world_input", ui.get_node("HudRoot/CommandPanel")), "command panel should block world clicks behind UI")
	ui.free()

func _test_hud_uses_collapsed_menus_and_top_resource_bar() -> void:
	var ui = UIScript.new()
	get_root().add_child(ui)
	await process_frame
	_require(ui.has_node("HudRoot/TopResourceBar"), "HUD should show resources in a compact top bar")
	_require(ui.has_node("HudRoot/CommandPanel/MarginContainer/VBoxContainer/BuildMenuButton"), "HUD should collapse build tools into a popup menu")
	_require(ui.has_node("HudRoot/CommandPanel/MarginContainer/VBoxContainer/OverlayMenuButton"), "HUD should collapse overlays into a popup menu")
	_require(ui.get_node("HudRoot/CommandPanel/MarginContainer/VBoxContainer/BuildMenuButton").get_popup().item_count >= 8, "build popup should contain construction tools")
	ui.free()

func _test_planning_heart_is_free_and_fill_refunds() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var start_essence = main.resources.get_amount("essence")
	var heart_coord = main.grid.entrance_tile + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart_coord)
	_require(main.resources.get_amount("essence") == start_essence, "initial Heart placement should be free")
	var dig_coord = heart_coord + Vector2i.RIGHT
	main.selected_tool = "dig"
	main.call("_handle_click", dig_coord)
	var after_dig = main.resources.get_amount("essence")
	_require(after_dig < start_essence, "planning dig should spend essence")
	main.selected_tool = "fill"
	main.call("_handle_click", dig_coord)
	_require(main.resources.get_amount("essence") == start_essence, "planning fill should erase and refund built floor")
	main.free()

func _test_build_phase_sources_and_monster_den() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var anchor = main.grid.entrance_tile + Vector2i.RIGHT
	var den_anchor = anchor + Vector2i.RIGHT
	for coord in [den_anchor, den_anchor + Vector2i.RIGHT, den_anchor + Vector2i.DOWN, den_anchor + Vector2i.RIGHT + Vector2i.DOWN]:
		main.selected_tool = "dig"
		main.call("_handle_click", coord)
	main.selected_tool = "magic_seep"
	main.call("_handle_click", anchor)
	_require(main.grid.call("get_tile", anchor).magic_source, "magic seep should be available during planning")
	main.selected_tool = "heat_vent"
	main.call("_handle_click", anchor)
	_require(main.grid.call("get_tile", anchor).heat_source, "heat vent should be available during planning")
	main.selected_tool = "moisture_source"
	main.call("_handle_click", anchor)
	_require(main.grid.call("get_tile", anchor).moisture_source, "moisture source should be available during planning")
	main.selected_tool = "seed_spore_root"
	main.call("_handle_click", anchor)
	_require(main.grid.call("get_tile", anchor).spore_seed, "spore roots should be seedable during planning")
	main.selected_tool = "place_monster_den"
	main.call("_handle_click", den_anchor)
	_require(main.grid.call("get_tile", den_anchor).structure == "monster_den", "monster den should place on a clear 2x2 floor")
	_require(main.grid.call("get_tile", den_anchor + Vector2i.RIGHT + Vector2i.DOWN).den_id == main.grid.call("get_tile", den_anchor).den_id, "monster den should mark all 2x2 tiles with one den id")
	main.free()

func _test_monster_den_requires_clear_2x2() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	var anchor = grid.entrance_tile + Vector2i.RIGHT
	grid.call("dig", anchor + Vector2i.RIGHT)
	_require(not grid.call("place_monster_den", anchor), "monster den should reject incomplete 2x2 floor")
	for coord in [anchor, anchor + Vector2i.RIGHT, anchor + Vector2i.DOWN, anchor + Vector2i.RIGHT + Vector2i.DOWN]:
		grid.call("dig", coord)
	grid.call("place_structure", anchor, "treasure")
	_require(not grid.call("place_monster_den", anchor), "monster den should reject occupied 2x2 floor")
	grid.free()

func _test_live_heart_can_be_moved_for_essence() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart_coord = main.grid.entrance_tile + Vector2i.RIGHT
	var move_coord = heart_coord + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart_coord)
	main.selected_tool = "dig"
	main.call("_handle_click", move_coord)
	main.call("_start_dungeon")
	var before = main.resources.get_amount("essence")
	main.selected_tool = "move_heart"
	main.call("_handle_click", move_coord)
	_require(main.grid.call("get_tile", move_coord).structure == "heart", "live Heart should move to target floor")
	_require(main.grid.call("get_tile", heart_coord).structure == "", "old Heart tile should be cleared")
	_require(main.resources.get_amount("essence") == before - 20, "moving the live Heart should cost essence")
	main.free()

func _test_live_fill_removes_door() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart_coord = main.grid.entrance_tile + Vector2i.RIGHT
	var door_coord = heart_coord + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart_coord)
	main.selected_tool = "dig"
	main.call("_handle_click", door_coord)
	main.selected_tool = "place_door"
	main.call("_handle_click", door_coord)
	main.call("_start_dungeon")
	main.selected_tool = "fill"
	main.call("_handle_click", door_coord)
	_require(main.grid.call("get_tile", door_coord).structure == "", "live fill should remove doors/structures before filling floor")
	_require(main.grid.call("get_tile", door_coord).is_walkable(), "first live fill on a door should leave the floor in place")
	main.free()

func _test_essence_can_seed_emergency_mite() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart_coord = main.grid.entrance_tile + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart_coord)
	main.call("_start_dungeon")
	main.resources.set_amount("bone", 0)
	main.resources.set_amount("biomass", 0)
	main.resources.set_amount("essence", 20)
	main.selected_tool = "seed_carrion_mite"
	main.call("_handle_click", heart_coord)
	_require(main.creatures.size() > 0, "live dungeon should allow emergency mite seeding from essence when biomass is empty")
	_require(main.resources.get_amount("essence") < 20, "emergency mite seeding should spend essence")
	main.free()

func _test_incursions_do_not_spawn_without_active_crawler_room() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	for i in range(40):
		var adventurer = AdventurerScript.new()
		adventurer.call("initialize", "looter", main.grid.entrance_tile, main.grid.entrance_tile)
		main.adventurers.append(adventurer)
	var before: int = main.adventurers.size()
	main.call("_spawn_incursion")
	_require(main.adventurers.size() == before, "incursions should not create unbounded crawler stacks when too many are already active")
	for adventurer in main.adventurers:
		adventurer.free()
	main.adventurers.clear()
	main.free()

func _test_background_essence_drip() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	var simulation = SimulationScript.new()
	grid.call("generate_planning_map")
	simulation.call("configure", grid, resources)
	var before = resources.get_amount("essence")
	for i in range(18):
		simulation.call("step", [], [])
	_require(resources.get_amount("essence") > before, "live simulation should provide a small background essence drip")
	simulation.free()
	resources.free()
	grid.free()

func _test_diffusion_and_growth() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	var simulation = SimulationScript.new()
	grid.call("generate_cave")
	simulation.call("configure", grid, resources)
	var wet = grid.start_center + Vector2i(-2, 0)
	grid.call("get_tile", wet).moisture_source = true
	grid.call("get_tile", wet).moisture = 96.0
	grid.call("get_tile", wet).darkness = 95.0
	var neighbor = wet + Vector2i.RIGHT
	var before = grid.call("get_tile", neighbor).moisture
	for i in range(8):
		simulation.call("step", [], [])
	_require(grid.call("get_tile", neighbor).moisture > before, "moisture should diffuse to neighbors")
	_require(grid.call("get_tile", wet).biomass > 0.0, "damp dark floor should grow biomass")
	simulation.free()
	resources.free()
	grid.free()

func _test_magic_seep_has_local_falloff() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	var simulation = SimulationScript.new()
	grid.call("generate_planning_map")
	simulation.call("configure", grid, resources)
	var source = grid.entrance_tile + Vector2i.RIGHT
	var far = source + Vector2i.RIGHT * 12
	for x in range(source.x, far.x + 1):
		grid.call("dig", Vector2i(x, source.y))
	var source_tile = grid.call("get_tile", source)
	source_tile.magic_source = true
	source_tile.magic = 95.0
	grid.call("get_tile", far).magic = 90.0
	for i in range(16):
		simulation.call("step", [], [])
	_require(grid.call("get_tile", far).magic < 25.0, "magic seep should not make distant dungeon tiles strongly magical")
	simulation.free()
	resources.free()
	grid.free()

func _test_crawler_kills_give_limited_biomass() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var mite_coord = grid.entrance_tile + Vector2i.RIGHT
	var crawler_coord = mite_coord + Vector2i.RIGHT
	grid.call("dig", crawler_coord)
	var mite = CreatureScript.new()
	mite.call("initialize", "carrion_mite", mite_coord)
	var crawler = AdventurerScript.new()
	crawler.call("initialize", "looter", crawler_coord, crawler_coord)
	crawler.hp = 1.0
	var before: int = resources.get_amount("biomass")
	mite.call("simulate_step", grid, [mite], [crawler], resources)
	_require(resources.get_amount("biomass") - before <= 4, "crawler kills should not flood the dungeon with biomass")
	mite.free()
	crawler.free()
	resources.free()
	grid.free()

func _test_mite_defends_against_nearby_crawler() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var mite_coord = grid.entrance_tile + Vector2i.RIGHT
	var crawler_coord = mite_coord + Vector2i.RIGHT + Vector2i.RIGHT
	grid.call("dig", mite_coord + Vector2i.RIGHT)
	grid.call("dig", crawler_coord)
	var mite = CreatureScript.new()
	mite.call("initialize", "carrion_mite", mite_coord)
	var crawler = AdventurerScript.new()
	crawler.call("initialize", "looter", crawler_coord, crawler_coord)
	var before = crawler.hp
	for i in range(4):
		mite.call("simulate_step", grid, [mite], [crawler], resources)
	_require(crawler.hp < before, "nearby dungeon mite should move to defend against crawlers")
	mite.free()
	crawler.free()
	resources.free()
	grid.free()

func _test_monster_den_spawns_by_environment() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart = main.grid.entrance_tile + Vector2i.RIGHT
	var den = heart + Vector2i.RIGHT
	for coord in [den, den + Vector2i.RIGHT, den + Vector2i.DOWN, den + Vector2i.RIGHT + Vector2i.DOWN]:
		main.selected_tool = "dig"
		main.call("_handle_click", coord)
		var tile = main.grid.call("get_tile", coord)
		tile.magic = 92.0
		tile.temperature = 88.0
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart)
	main.selected_tool = "place_monster_den"
	main.call("_handle_click", den)
	main.call("_start_dungeon")
	main.creatures.clear()
	for i in range(22):
		main.call("_try_den_spawns")
	_require(main.call("_count_species", "cinder_witch") > 0, "magic plus heat den should spawn cinder witches")
	main.free()

func _test_heart_larva_spawns_and_stays_near_heart() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart = main.grid.entrance_tile + Vector2i.RIGHT
	var hall = heart + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart)
	main.selected_tool = "dig"
	main.call("_handle_click", hall)
	main.call("_start_dungeon")
	_require(main.call("_count_species", "heart_larva") == 1, "starting the dungeon should spawn a boss larva tied to the Heart")
	var larva = null
	for creature in main.creatures:
		if is_instance_valid(creature) and creature.species == "heart_larva":
			larva = creature
	var far_crawler = AdventurerScript.new()
	far_crawler.call("initialize", "looter", hall, hall)
	for i in range(8):
		larva.call("simulate_step", main.grid, main.creatures, [far_crawler], main.resources)
	_require(larva.tile_pos.distance_to(heart) <= 2.0, "boss larva should stay close to the Heart instead of chasing crawlers")
	far_crawler.free()
	main.free()

func _test_boss_larva_is_sturdier_and_hits_harder() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var heart = grid.entrance_tile + Vector2i.RIGHT
	var larva_coord = heart + Vector2i.RIGHT
	grid.call("dig", larva_coord)
	grid.call("place_structure", heart, "heart")
	var larva = CreatureScript.new()
	larva.call("initialize", "heart_larva", larva_coord)
	_require(larva.hp >= 70.0, "boss larva should be much sturdier than basic monsters")
	var crawler = AdventurerScript.new()
	crawler.call("initialize", "looter", heart, heart)
	var hp_before: float = crawler.hp
	larva.call("simulate_step", grid, [larva], [crawler], resources)
	_require(hp_before - crawler.hp >= 6.0, "boss larva should hit crawlers hard near the Heart")
	larva.free()
	crawler.free()
	resources.free()
	grid.free()

func _test_boss_can_be_respawned_after_delay() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart = main.grid.entrance_tile + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart)
	main.call("_start_dungeon")
	for creature in main.creatures:
		if is_instance_valid(creature) and creature.species.begins_with("heart_"):
			creature.queue_free()
	main.call("_prune_dead_entities")
	main.boss_respawn_ticks = main.BOSS_RESPAWN_DELAY_TICKS
	main.resources.set_amount("biomass", 300)
	main.resources.set_amount("essence", 200)
	main.selected_tool = "respawn_boss"
	main.call("_handle_click", heart)
	_require(main.call("_count_bosses") == 1, "boss should be respawnable after the delay for a large cost")
	_require(main.resources.get_amount("biomass") <= 180, "boss respawn should spend significant biomass")
	_require(main.resources.get_amount("essence") <= 140, "boss respawn should spend significant essence")
	main.free()

func _test_direct_mite_spam_cost_increases() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart = main.grid.entrance_tile + Vector2i.RIGHT
	var tile_a = heart + Vector2i.RIGHT
	var tile_b = tile_a + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart)
	for coord in [tile_a, tile_b]:
		main.selected_tool = "dig"
		main.call("_handle_click", coord)
	main.call("_start_dungeon")
	main.creatures.clear()
	main.resources.set_amount("bone", 0)
	main.resources.set_amount("biomass", 100)
	main.resources.set_amount("essence", 100)
	main.selected_tool = "seed_carrion_mite"
	var before_first: int = main.resources.get_amount("biomass")
	main.call("_handle_click", tile_a)
	var first_cost: int = before_first - main.resources.get_amount("biomass")
	var before_second: int = main.resources.get_amount("biomass")
	main.call("_handle_click", tile_b)
	var second_cost: int = before_second - main.resources.get_amount("biomass")
	_require(second_cost > first_cost, "direct carrion mite seeding should get more expensive as mite count rises")
	main.free()

func _test_exploding_spores_damage_crawlers_and_break_walls() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart = main.grid.entrance_tile + Vector2i.RIGHT
	var boss_pad = heart + Vector2i.RIGHT
	var spore = heart + Vector2i.DOWN + Vector2i.DOWN
	var crawler_coord = spore + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart)
	for coord in [boss_pad, spore, crawler_coord]:
		main.selected_tool = "dig"
		main.call("_handle_click", coord)
	var wall = spore + Vector2i.DOWN
	main.call("_start_dungeon")
	for creature in main.creatures:
		if is_instance_valid(creature):
			creature.queue_free()
	main.creatures.clear()
	var spore_creature = main.call("_spawn_creature", "spore_root", spore)
	var crawler = AdventurerScript.new()
	crawler.call("initialize", "looter", crawler_coord, heart)
	main.adventurers.append(crawler)
	main.selected_tool = "explode_spores"
	main.call("_handle_click", spore)
	_require(crawler.hp <= 4.0, "exploding spores should massively damage nearby crawlers")
	_require(not is_instance_valid(spore_creature) or spore_creature.is_queued_for_deletion(), "exploding spores should destroy the spore root")
	_require(main.grid.call("get_tile", wall).is_walkable(), "exploding spores should dig adjacent walls open")
	crawler.free()
	main.free()

func _test_heart_is_durable_defenseless_and_does_not_regen() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	var simulation = SimulationScript.new()
	grid.call("generate_planning_map")
	var heart = grid.entrance_tile + Vector2i.RIGHT
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", heart, heart)
	var before = grid.call("get_tile", heart).heart_hp
	adventurer.call("simulate_step", grid, [], resources)
	var damaged = grid.call("get_tile", heart).heart_hp
	_require(damaged < before, "crawler should damage the defenseless Heart")
	simulation.call("configure", grid, resources)
	for i in range(5):
		simulation.call("step", [], [])
	_require(grid.call("get_tile", heart).heart_hp == damaged, "Heart should not passively regenerate")
	adventurer.free()
	simulation.free()
	resources.free()
	grid.free()

func _test_crawler_retargets_to_treasure_then_heart() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var treasure = grid.entrance_tile + Vector2i.RIGHT
	var heart = treasure + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", treasure, "treasure")
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, Vector2i(80, 80))
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == treasure, "looter should dynamically retarget to reachable treasure")
	adventurer.tile_pos = treasure
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == heart, "looter should retarget to Heart after looting treasure")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_cannot_sense_heart_beyond_door() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var door = grid.entrance_tile + Vector2i.RIGHT
	var heart = door + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", door, "door")
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == door, "crawler should target an unexplored door instead of sensing Heart beyond it")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_randomly_explores_multiple_doors() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var room = grid.entrance_tile + Vector2i.RIGHT
	var door_a = room + Vector2i.RIGHT
	var door_b = room + Vector2i.DOWN
	var beyond_a = door_a + Vector2i.RIGHT
	var beyond_b = door_b + Vector2i.DOWN
	for coord in [door_a, door_b, beyond_a, beyond_b]:
		grid.call("dig", coord)
	grid.call("place_structure", door_a, "door")
	grid.call("place_structure", door_b, "door")
	grid.call("place_structure", beyond_b, "heart")
	var seen: Dictionary = {}
	for i in range(30):
		var adventurer = AdventurerScript.new()
		adventurer.call("initialize", "looter", room, beyond_b)
		adventurer.call("simulate_step", grid, [], resources)
		seen[adventurer.target] = true
		adventurer.free()
	_require(seen.has(door_a) and seen.has(door_b), "crawler should randomly explore among multiple unknown doors")
	resources.free()
	grid.free()

func _test_crawler_keeps_chosen_door_until_reached() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var room = grid.entrance_tile + Vector2i.RIGHT
	var door_a = room + Vector2i.RIGHT + Vector2i.RIGHT
	var door_b = room + Vector2i.DOWN + Vector2i.DOWN
	var path_a = room + Vector2i.RIGHT
	var path_b = room + Vector2i.DOWN
	for coord in [path_a, path_b, door_a, door_b, door_a + Vector2i.RIGHT, door_b + Vector2i.DOWN]:
		grid.call("dig", coord)
	grid.call("place_structure", door_a, "door")
	grid.call("place_structure", door_b, "door")
	grid.call("place_structure", door_b + Vector2i.DOWN, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", room, door_b + Vector2i.DOWN)
	adventurer.call("simulate_step", grid, [], resources)
	var chosen_door = adventurer.target
	_require(chosen_door == door_a or chosen_door == door_b, "crawler should choose one visible door frontier")
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == chosen_door, "crawler should keep the chosen door target until it reaches it")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_commits_to_crossing_door() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var door = grid.entrance_tile + Vector2i.RIGHT
	var heart = door + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", door, "door")
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == door, "crawler should first target the unknown door")
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == heart, "crawler standing at a door should commit to crossing and discover the next room")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_does_not_reselect_explored_door_from_next_room() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var door = grid.entrance_tile + Vector2i.RIGHT
	var room = door + Vector2i.RIGHT
	var heart = room + Vector2i.RIGHT
	grid.call("dig", room)
	grid.call("dig", heart)
	grid.call("place_structure", door, "door")
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	for i in range(4):
		adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.tile_pos != door, "crawler should not bounce back onto an already explored door")
	_require(adventurer.target == heart, "crawler should keep pursuing visible Heart after crossing door")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_wave_shares_explored_doors() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var room = grid.entrance_tile + Vector2i.RIGHT
	var door_a = room + Vector2i.RIGHT
	var door_b = room + Vector2i.DOWN
	var beyond_a = door_a + Vector2i.RIGHT
	var beyond_b = door_b + Vector2i.DOWN
	for coord in [door_a, door_b, beyond_a, beyond_b]:
		grid.call("dig", coord)
	grid.call("place_structure", door_a, "door")
	grid.call("place_structure", door_b, "door")
	grid.call("place_structure", beyond_b, "heart")
	var party_memory: Dictionary = {}
	var scout = AdventurerScript.new()
	scout.call("initialize", "looter", room, beyond_b)
	scout.call("share_exploration_memory", party_memory)
	scout.explored_doors[door_a] = true
	var follower = AdventurerScript.new()
	follower.call("initialize", "looter", room, beyond_b)
	follower.call("share_exploration_memory", party_memory)
	follower.call("simulate_step", grid, [], resources)
	_require(follower.target == door_b, "crawler wave should share explored-door memory and try unexplored doors")
	scout.free()
	follower.free()
	resources.free()
	grid.free()

func _test_crawler_can_progress_through_door() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var door = grid.entrance_tile + Vector2i.RIGHT
	var heart = door + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", door, "door")
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	for i in range(8):
		adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.tile_pos == heart, "crawler should be slowed by doors but still progress through them")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_targets_visible_magic_source_before_heart() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var magic_source = grid.entrance_tile + Vector2i.RIGHT
	var heart = magic_source + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", heart, "heart")
	grid.call("get_tile", magic_source).magic_source = true
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.target == magic_source, "crawler should target visible magic sources before the Heart")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_disrupts_any_source_then_continues() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var moisture_source = grid.entrance_tile + Vector2i.RIGHT
	var heart = moisture_source + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", heart, "heart")
	grid.call("get_tile", moisture_source).moisture_source = true
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	for i in range(5):
		adventurer.call("simulate_step", grid, [], resources)
	_require(not grid.call("get_tile", moisture_source).moisture_source, "crawler should disrupt moisture sources it chooses as a target")
	_require(adventurer.tile_pos == heart, "crawler should continue toward the Heart after disrupting a source")
	adventurer.free()
	resources.free()
	grid.free()

func _test_crawler_attacks_visible_creature() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var creature_coord = grid.entrance_tile + Vector2i.RIGHT
	var heart = creature_coord + Vector2i.RIGHT
	grid.call("dig", heart)
	grid.call("place_structure", heart, "heart")
	var creature = CreatureScript.new()
	creature.call("initialize", "spore_root", creature_coord)
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	var hp_before: float = creature.hp
	adventurer.call("simulate_step", grid, [creature], resources)
	_require(creature.hp < hp_before, "crawler should attack visible dungeon creatures, not only hunters")
	adventurer.free()
	creature.free()
	resources.free()
	grid.free()

func _test_crawler_does_not_farm_knowledge_each_magic_step() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_planning_map")
	var heart = grid.entrance_tile + Vector2i.RIGHT * 10
	for x in range(grid.entrance_tile.x + 1, heart.x + 1):
		var coord = Vector2i(x, grid.entrance_tile.y)
		grid.call("dig", coord)
		grid.call("get_tile", coord).magic = 80.0
	grid.call("place_structure", heart, "heart")
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", grid.entrance_tile, heart)
	for i in range(8):
		adventurer.call("simulate_step", grid, [], resources)
	_require(resources.get_amount("knowledge") <= 1, "crawlers should not generate knowledge every step while walking through ambient magic")
	adventurer.free()
	resources.free()
	grid.free()

func _test_mutation_pressure() -> void:
	var grid = GridScript.new()
	var resources = ResourcesScript.new()
	grid.call("generate_cave")
	var coord = grid.start_center
	for x in range(0, 120):
		for y in range(0, 120):
			var heat_tile = grid.call("get_tile", Vector2i(x, y))
			if heat_tile.is_walkable():
				heat_tile.temperature = 90.0
	var creature = CreatureScript.new()
	creature.call("initialize", "carrion_mite", coord)
	for i in range(38):
		creature.call("simulate_step", grid, [creature], [], resources)
	_require(creature.species == "ember_mite", "carrion mite should mutate under high heat")
	creature.free()
	resources.free()
	grid.free()
