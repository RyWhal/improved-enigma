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
	_test_tileset_assets_available()
	_test_floor_autotile_uses_only_floor_cells()
	_test_wall_autotile_layers_follow_dungeon_shape()
	_test_tilemap_dirty_updates_batch_by_chunk()
	_test_grid_manual_draw_rects_track_unlocked_chunks()
	_test_grid_uses_128_world_with_32_tile_chunks()
	_test_cave_generation()
	_test_editor_preview_generation()
	_test_wall_sprites_follow_dug_layout()
	_test_planning_map_starts_mostly_solid()
	await _test_drag_dig_and_fill_preview_commits_on_release()
	await _test_building_is_limited_to_unlocked_chunks()
	await _test_night_countdown_can_be_paused()
	_test_build_warnings_are_warning_only()
	await _test_hud_does_not_block_world_input()
	await _test_hud_uses_collapsed_menus_and_top_resource_bar()
	_test_entities_interpolate_between_tile_steps()
	await _test_heart_must_be_reachable_to_place_start_and_fill()
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

func _test_tileset_assets_available() -> void:
	_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/atlas_floor-16x16.png"), "0x72 floor atlas should be available")
	_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/atlas_walls_low-16x16.png"), "0x72 low wall atlas should be available")
	_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/atlas_walls_high-16x32.png"), "0x72 high wall atlas should be available")
	_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/doors_leaf_closed.png"), "0x72 door sprite should be available")
	_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/chest_full_open_anim_f0.png"), "0x72 treasure chest sprite should be available")
	for floor_index in range(1, 9):
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/floor_%s.png" % floor_index), "0x72 floor_%s sprite should be available" % floor_index)
	for frame_index in range(4):
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/big_demon_idle_anim_f%s.png" % frame_index), "0x72 big demon idle frame %s should be available" % frame_index)
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/dwarf_m_run_anim_f%s.png" % frame_index), "0x72 dwarf run frame %s should be available" % frame_index)
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/knight_m_run_anim_f%s.png" % frame_index), "0x72 knight run frame %s should be available" % frame_index)
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/goblin_run_anim_f%s.png" % frame_index), "0x72 goblin run frame %s should be available" % frame_index)
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/skelet_run_anim_f%s.png" % frame_index), "0x72 skeleton run frame %s should be available" % frame_index)
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/floor_spikes_anim_f%s.png" % frame_index), "0x72 floor spike frame %s should be available" % frame_index)
	for wall_sprite in [
		"wall_mid", "wall_left", "wall_right", "wall_top_mid", "wall_top_left", "wall_top_right",
		"wall_edge_bottom_left", "wall_edge_bottom_right", "wall_edge_mid_left", "wall_edge_mid_right",
		"wall_edge_top_left", "wall_edge_top_right", "wall_edge_left", "wall_edge_right",
		"wall_edge_tshape_bottom_left", "wall_edge_tshape_bottom_right", "wall_edge_tshape_left", "wall_edge_tshape_right",
		"wall_outer_front_left", "wall_outer_front_right", "wall_outer_mid_left", "wall_outer_mid_right",
		"wall_outer_top_left", "wall_outer_top_right"
	]:
		_require(FileAccess.file_exists("res://assets/tilesets/0x72_DungeonTilesetII_v1.7/frames/%s.png" % wall_sprite), "0x72 %s sprite should be available" % wall_sprite)

func _test_wall_autotile_layers_follow_dungeon_shape() -> void:
	var grid = GridScript.new()
	get_root().add_child(grid)
	grid.call("generate_planning_map")
	var center: Vector2i = grid.start_center
	for coord in [
		center,
		center + Vector2i.RIGHT,
		center + Vector2i.DOWN,
		center + Vector2i.RIGHT + Vector2i.DOWN,
		center + Vector2i(2, 1),
		center + Vector2i(3, 1),
	]:
		grid.call("dig", coord)
	_require(grid.has_method("_refresh_tilemap_layers"), "grid should use Godot TileMapLayer terrain rendering for atlas walls")
	if not grid.has_method("_refresh_tilemap_layers"):
		grid.free()
		return
	grid.call("_refresh_tilemap_layers")
	_require(grid.has_node("FloorTileLayer"), "grid should create a floor TileMapLayer")
	_require(grid.has_node("WallBackingLayer"), "grid should create a backing layer under transparent wall pixels")
	_require(grid.has_node("WallTileLayer"), "grid should create a wall TileMapLayer")
	var floor_layer: TileMapLayer = grid.get_node("FloorTileLayer")
	var wall_backing_layer: TileMapLayer = grid.get_node("WallBackingLayer")
	var wall_layer: TileMapLayer = grid.get_node("WallTileLayer")
	_require(floor_layer.tile_set != null, "floor TileMapLayer should have a TileSet")
	_require(wall_backing_layer.tile_set != null, "wall backing TileMapLayer should have a TileSet")
	_require(wall_layer.tile_set != null, "wall TileMapLayer should have a TileSet")
	if wall_backing_layer.tile_set != null:
		var backing_source := wall_backing_layer.tile_set.get_source(0) as TileSetAtlasSource
		_require(backing_source != null and backing_source.texture != null and backing_source.texture.resource_path.ends_with("wall_mid.png"), "wall backing should use the wall_mid brick sprite, not a flat filler color")
	if wall_layer.tile_set != null:
		_require(wall_layer.tile_set.get_terrain_sets_count() == 1, "wall TileSet should define one terrain set")
	_require(floor_layer.get_used_cells().has(center), "dug floor should render on the floor layer")
	_require(not wall_layer.get_used_cells().has(center), "walkable floor should not be rendered as wall terrain")
	_require(wall_layer.get_used_cells().has(center + Vector2i.UP), "solid tile above floor should render as wall terrain")
	_require(not wall_layer.get_used_cells().has(center + Vector2i.UP * 2), "low autotile walls should not add a second cap row above floor")
	_require(wall_layer.get_used_cells().has(center + Vector2i.LEFT), "solid tile beside floor should render side wall terrain")
	_require(wall_backing_layer.get_used_cells().has(center + Vector2i.LEFT), "side wall terrain should have opaque backing behind transparent atlas pixels")
	_require(not wall_backing_layer.get_used_cells().has(center), "walkable floor should not get wall backing")
	grid.free()

func _test_floor_autotile_uses_only_floor_cells() -> void:
	var grid = GridScript.new()
	var valid_floor_cells := {
		Vector2i(0, 0): true,
		Vector2i(1, 0): true,
		Vector2i(2, 0): true,
		Vector2i(0, 1): true,
		Vector2i(1, 1): true,
		Vector2i(2, 1): true,
		Vector2i(0, 2): true,
		Vector2i(1, 2): true,
	}
	for x in range(48, 74):
		for y in range(48, 74):
			var atlas_coord: Vector2i = grid.call("_floor_atlas_coord", Vector2i(x, y))
			_require(valid_floor_cells.has(atlas_coord), "floor renderer should not select non-floor atlas cell %s,%s" % [atlas_coord.x, atlas_coord.y])
	grid.free()

func _test_tilemap_dirty_updates_batch_by_chunk() -> void:
	var grid = GridScript.new()
	get_root().add_child(grid)
	grid.call("generate_planning_map")
	grid.call("_refresh_tilemap_layers")
	_require(grid.has_method("begin_tilemap_batch"), "grid should support batched tilemap updates")
	_require(grid.has_method("end_tilemap_batch"), "grid should support ending batched tilemap updates")
	if not grid.has_method("begin_tilemap_batch") or not grid.has_method("end_tilemap_batch"):
		grid.free()
		return
	var first: Vector2i = grid.entrance_tile + Vector2i.RIGHT * 2
	var second: Vector2i = first + Vector2i.DOWN
	grid.call("begin_tilemap_batch")
	grid.call("dig", first)
	grid.call("dig", second)
	_require(grid.tilemap_dirty_cells.is_empty(), "tilemap dirty cells should wait until the batch ends")
	grid.call("end_tilemap_batch")
	_require(grid.tilemap_dirty_cells.size() > 0, "ending a tile batch should mark cells dirty")
	_require(grid.tilemap_dirty_cells.size() <= int(pow(DungeonGrid.CHUNK_SIZE + 4, 2)), "batched tilemap work should stay scoped near one 32x32 chunk")
	grid.free()

func _test_grid_manual_draw_rects_track_unlocked_chunks() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	_require(grid.has_method("_manual_draw_tile_rects"), "grid should expose bounded draw rects for manual tile rendering")
	if not grid.has_method("_manual_draw_tile_rects"):
		grid.free()
		return
	var rects: Array = grid.call("_manual_draw_tile_rects")
	_require(rects.size() == 1, "manual drawing should start limited to the unlocked starting chunk")
	_require(rects[0].has_point(grid.start_center), "manual draw rect should include the starting chunk")
	_require(not rects[0].has_point(grid.chunk_center_tile(grid.start_chunk + Vector2i.RIGHT)), "manual draw rect should not include locked neighbor chunks")
	grid.call("unlock_chunk", grid.start_chunk + Vector2i.RIGHT)
	rects = grid.call("_manual_draw_tile_rects")
	_require(rects.size() == 2, "manual drawing should add a rect when a new chunk is unlocked")
	grid.free()

func _test_grid_uses_128_world_with_32_tile_chunks() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	_require(DungeonGrid.GRID_SIZE == 128, "overall dungeon grid should be 128x128")
	_require(grid.has_method("chunk_for_coord"), "grid should expose chunk coordinates for influence expansion")
	_require(grid.has_method("unlocked_chunk_count"), "grid should track unlocked influence chunks")
	if not grid.has_method("chunk_for_coord") or not grid.has_method("unlocked_chunk_count"):
		grid.free()
		return
	_require(grid.call("chunk_for_coord", Vector2i(31, 31)) == Vector2i.ZERO, "dungeon chunks should be 32x32")
	_require(grid.call("chunk_for_coord", Vector2i(127, 127)) == Vector2i(3, 3), "128x128 dungeon should divide into four chunks per axis")
	_require(grid.call("unlocked_chunk_count") == 1, "planning map should start with exactly one unlocked build chunk")
	_require(grid.call("chunk_for_coord", grid.start_center) == grid.start_chunk, "start center should be inside the starting chunk")
	_require(grid.call("chunk_for_coord", grid.entrance_tile) == grid.start_chunk, "entrance should be inside the starting chunk")
	_require(grid.call("is_chunk_unlocked", grid.start_chunk), "starting chunk should be unlocked")
	_require(not grid.call("is_chunk_unlocked", grid.start_chunk + Vector2i.RIGHT), "neighbor chunks should start locked")
	grid.free()

func _test_cave_generation() -> void:
	var grid = GridScript.new()
	grid.call("generate_cave")
	_require(grid.tiles.size() == 128, "grid should have 128 columns")
	_require(grid.tiles[0].size() == 128, "grid should have 128 rows")
	_require(grid.call("get_tile", grid.start_center).is_walkable(), "starting chamber should be walkable")
	_require(grid.call("get_tile", grid.entrance_tile).is_walkable(), "entrance should be walkable")
	_require(grid.call("get_tile", Vector2i(12, 12)).is_diggable(), "stone should be diggable")
	grid.free()

func _test_editor_preview_generation() -> void:
	var grid = GridScript.new()
	grid.call("ensure_preview_generated")
	_require(grid.tiles.size() == 128, "editor preview should generate the grid")
	_require(grid.call("get_tile", grid.entrance_tile).is_walkable(), "editor preview should show the entrance")
	grid.free()

func _test_wall_sprites_follow_dug_layout() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	var center: Vector2i = grid.start_center
	grid.call("dig", center)
	_require(grid.call("_wall_sprite_name_for_coord", center + Vector2i.UP) == "wall_mid", "solid tile directly above dug floor should render as wall face")
	_require(grid.call("_wall_sprite_name_for_coord", center + Vector2i.UP * 2) == "wall_top_mid", "solid tile two above dug floor should render as wall top")
	_require(grid.call("_wall_sprite_name_for_coord", center + Vector2i.LEFT) == "wall_outer_mid_left", "solid tile left of dug floor should render as left outer wall")
	_require(grid.call("_wall_sprite_name_for_coord", center + Vector2i.RIGHT) == "wall_outer_mid_right", "solid tile right of dug floor should render as right outer wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(20, 20)) == "", "deep undug stone should not get structural wall sprites")
	for x in range(center.x, center.x + 3):
		for y in range(center.y + 4, center.y + 7):
			grid.call("dig", Vector2i(x, y))
	var top_face_y := center.y + 3
	var top_cap_y := center.y + 2
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x, top_face_y)) == "wall_left", "left end of a room top wall face should use wall-left")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 1, top_face_y)) == "wall_mid", "middle of a room top wall face should use wall-middle")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 2, top_face_y)) == "wall_right", "right end of a room top wall face should use wall-right")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x, top_cap_y)) == "wall_top_left", "left end of a room top cap should use top-left")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 1, top_cap_y)) == "wall_top_mid", "middle of a room top cap should use top-middle")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 2, top_cap_y)) == "wall_top_right", "right end of a room top cap should stay a top-right cap")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x - 1, top_face_y)) == "wall_edge_mid_right", "top-left corner should place a right-facing wall edge beside the top wall face")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 3, top_face_y)) == "wall_edge_mid_left", "top-right corner should place a left-facing wall edge beside the top wall face")
	var bottom_y := center.y + 7
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x, bottom_y)) == "wall_left", "left end of a room bottom wall should use front-left wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 1, bottom_y)) == "wall_mid", "middle of a room bottom wall should use middle wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 2, bottom_y)) == "wall_right", "right end of a room bottom wall should use front-right wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x - 1, bottom_y)) == "wall_edge_bottom_left", "bottom-left corner should use a transition edge")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 3, bottom_y)) == "wall_edge_bottom_right", "bottom-right corner should use a transition edge")
	_require(grid.has_method("_wall_overlay_sprite_names_for_coord"), "wall renderer should support topper overlays")
	if grid.has_method("_wall_overlay_sprite_names_for_coord"):
		_require(grid.call("_wall_overlay_sprite_names_for_coord", Vector2i(center.x, bottom_y)).has("wall_top_left"), "left bottom wall should draw a top cap overlay")
		_require(grid.call("_wall_overlay_sprite_names_for_coord", Vector2i(center.x + 1, bottom_y)).has("wall_top_mid"), "middle bottom wall should draw a top cap overlay")
		_require(grid.call("_wall_overlay_sprite_names_for_coord", Vector2i(center.x + 2, bottom_y)).has("wall_top_right"), "right bottom wall should draw a top cap overlay")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x - 1, center.y + 4)) == "wall_outer_top_left", "upper-left side of a room should use outer top left")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x - 1, center.y + 5)) == "wall_outer_mid_left", "middle-left side of a room should use outer mid left")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x - 1, center.y + 6)) == "wall_outer_front_left", "lower-left side of a room should use outer front left")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 3, center.y + 4)) == "wall_outer_top_right", "upper-right side of a room should use outer top right")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 3, center.y + 5)) == "wall_outer_mid_right", "middle-right side of a room should use outer mid right")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(center.x + 3, center.y + 6)) == "wall_outer_front_right", "lower-right side of a room should use outer front right")
	var hall := center + Vector2i(8, 0)
	for y in range(hall.y, hall.y + 4):
		grid.call("dig", Vector2i(hall.x, y))
	var hall_top_face_y := hall.y - 1
	var hall_bottom_y := hall.y + 4
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(hall.x - 1, hall_top_face_y)) == "wall_edge_mid_right", "vertical hall start should have a left-side transition beside its top wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(hall.x + 1, hall_top_face_y)) == "wall_edge_mid_left", "vertical hall start should have a right-side transition beside its top wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(hall.x - 1, hall_bottom_y)) == "wall_edge_bottom_left", "vertical hall end should have a left-side transition beside its bottom wall")
	_require(grid.call("_wall_sprite_name_for_coord", Vector2i(hall.x + 1, hall_bottom_y)) == "wall_edge_bottom_right", "vertical hall end should have a right-side transition beside its bottom wall")
	grid.free()

func _test_planning_map_starts_mostly_solid() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	_require(not grid.call("get_tile", grid.start_center).is_walkable(), "planning map should not start with an open chamber")
	_require(grid.call("get_tile", grid.entrance_tile).is_walkable(), "planning map should include an entrance")
	_require(grid.call("dig", grid.start_center), "planning map should let the player dig initial rooms")
	grid.free()

func _test_drag_dig_and_fill_preview_commits_on_release() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	_require(main.has_method("_begin_drag_preview"), "main should preview drag dig/fill before applying it")
	_require(main.has_method("_commit_drag_preview"), "main should commit drag dig/fill in one batch")
	if not main.has_method("_begin_drag_preview") or not main.has_method("_commit_drag_preview"):
		main.free()
		return
	var first: Vector2i = main.grid.entrance_tile + Vector2i.RIGHT * 2
	var second: Vector2i = first + Vector2i.DOWN
	main.selected_tool = "dig"
	var start_essence: int = main.resources.get_amount("essence")
	main.call("_begin_drag_preview", first)
	main.call("_extend_drag_preview", second)
	_require(not main.grid.get_tile(first).is_walkable(), "drag dig should only highlight before release")
	_require(not main.grid.get_tile(second).is_walkable(), "drag dig should not mutate later drag tiles before release")
	main.call("_commit_drag_preview")
	_require(main.grid.get_tile(first).is_walkable() and main.grid.get_tile(second).is_walkable(), "drag dig should apply all previewed tiles on release")
	_require(main.resources.get_amount("essence") == start_essence - 2, "batched drag dig should spend once for each changed tile")
	main.grid.call("_refresh_tilemap_layers")
	main.selected_tool = "fill"
	main.call("_begin_drag_preview", first)
	main.call("_extend_drag_preview", second)
	_require(main.grid.get_tile(first).is_walkable(), "drag fill should only highlight before release")
	main.call("_commit_drag_preview")
	_require(not main.grid.get_tile(first).is_walkable() and not main.grid.get_tile(second).is_walkable(), "drag fill should erase all previewed tiles on release")
	_require(main.resources.get_amount("essence") == start_essence, "batched planning fill should refund erased floor")
	main.free()

func _test_building_is_limited_to_unlocked_chunks() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var locked_coord: Vector2i = main.grid.chunk_origin(main.grid.start_chunk + Vector2i.RIGHT) + Vector2i(3, 3)
	main.selected_tool = "dig"
	var essence_before: int = main.resources.get_amount("essence")
	main.call("_handle_click", locked_coord)
	_require(not main.grid.get_tile(locked_coord).is_walkable(), "digging should be blocked outside the current influence chunk")
	_require(main.resources.get_amount("essence") == essence_before, "blocked locked-chunk digs should not spend essence")
	main.selected_tool = "expand_influence"
	main.call("_handle_click", locked_coord)
	_require(main.grid.call("is_chunk_unlocked", main.grid.call("chunk_for_coord", locked_coord)), "expand influence should unlock the clicked adjacent chunk")
	_require(main.resources.get_amount("essence") < essence_before, "expanding influence should spend essence")
	main.selected_tool = "dig"
	main.call("_handle_click", locked_coord)
	_require(main.grid.get_tile(locked_coord).is_walkable(), "digging should work after expanding influence into a chunk")
	main.free()

func _test_night_countdown_can_be_paused() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var heart: Vector2i = main.grid.entrance_tile + Vector2i.RIGHT
	main.selected_tool = "place_heart"
	main.call("_handle_click", heart)
	main.call("_start_dungeon")
	var before: float = main.incursion_timer
	main.call("_process", 1.0)
	_require(main.incursion_timer < before, "night countdown should tick down while unpaused")
	main.call("_set_night_paused", true)
	var paused_before: float = main.incursion_timer
	main.call("_process", 1.0)
	_require(is_equal_approx(main.incursion_timer, paused_before), "night countdown should stop while paused")
	_require(main.ui.has_node("HudRoot/TopResourceBar/ResourceRow/NightCountdown"), "HUD should show the next-night countdown")
	_require(main.ui.get_node("HudRoot/TopResourceBar/ResourceRow/NightCountdown").text.contains("Paused"), "HUD countdown should show paused state")
	main.free()

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
	_require(ui.call("should_block_world_input", ui.get_node("HudRoot/ToolRail")), "tool rail should block world clicks behind UI")
	_require(ui.call("should_block_world_input", ui.get_node("HudRoot/InfoPanel")), "inspect panel should block world clicks behind UI")
	_require(ui.call("should_block_world_input", ui.get_node("HudRoot/WarningsPopup")), "warnings popup should block world clicks behind UI")
	ui.free()

func _test_hud_uses_collapsed_menus_and_top_resource_bar() -> void:
	var ui = UIScript.new()
	get_root().add_child(ui)
	await process_frame
	_require(ui.has_node("HudRoot/TopResourceBar"), "HUD should show resources in a compact top bar")
	_require(ui.has_node("HudRoot/TopResourceBar/ResourceRow/NightCountdown"), "HUD should include a next-night countdown")
	_require(ui.has_node("HudRoot/TopResourceBar/ResourceRow/NightPauseButton"), "HUD should include a play/pause control for the next attack")
	_require(ui.has_node("HudRoot/TopResourceBar/ResourceRow/EssenceResource"), "HUD should keep essence in the compact resource bar")
	_require(ui.get_node("HudRoot/TopResourceBar/ResourceRow/EssenceResource").tooltip_text == "Essence", "resource icons should reveal full names on hover")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/CoreTools/DigTool"), "HUD should expose dig as a square rail button")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/BuildingsTools/PlaceDoorTool"), "HUD should group building tools in the rail")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/MonstersTools/SeedCarrionMiteTool"), "HUD should group dungeon monster tools in the rail")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/SpecialTools/ExplodeSporesTool"), "HUD should group special attack tools in the rail")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/OverlayTools/MagicOverlay"), "HUD should expose overlays as compact rail buttons")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/WarningsButton"), "warnings should live behind a rail button")
	_require(ui.has_node("HudRoot/ToolRail/MarginContainer/Rail/LogButton"), "game log should live behind a rail button")
	_require(ui.has_node("HudRoot/WarningsPopup/PopupMargin/WarningsPopupText"), "warnings button should open a warnings popup")
	_require(ui.has_node("HudRoot/LogPopup/PopupMargin/LogPopupText"), "log button should open a game log popup")
	ui.set_warnings(["No treasure placed."])
	ui.add_log("Crawler collected treasure.")
	_require(ui.get_node("HudRoot/WarningsPopup/PopupMargin/WarningsPopupText").text.contains("No treasure placed."), "warnings popup should show current warnings")
	_require(ui.get_node("HudRoot/LogPopup/PopupMargin/LogPopupText").text.contains("Crawler collected treasure."), "log popup should show recent game events")
	ui.free()

func _test_entities_interpolate_between_tile_steps() -> void:
	var grid = GridScript.new()
	grid.call("generate_planning_map")
	var resources = ResourcesScript.new()
	var start: Vector2i = grid.entrance_tile + Vector2i.RIGHT
	var next: Vector2i = start + Vector2i.RIGHT
	var target: Vector2i = next + Vector2i.RIGHT
	for coord in [start, next, target]:
		grid.call("dig", coord)
	var adventurer = AdventurerScript.new()
	adventurer.call("initialize", "looter", start, target)
	var start_position := _tile_center(start)
	_require(adventurer.position.distance_to(start_position) < 0.01, "crawler should initialize at its tile center")
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.tile_pos == next, "crawler simulation tile should advance immediately")
	_require(adventurer.position.distance_to(_tile_center(next)) > 2.0, "crawler visual position should not snap to the next tile")
	adventurer.call("_process", 0.12)
	_require(adventurer.position.distance_to(start_position) > 1.0, "crawler visual position should begin moving continuously")
	adventurer.call("_process", 0.14)
	_require(adventurer.position.distance_to(_tile_center(next)) > 1.0, "crawler visual stride should overlap the next simulation tick instead of pausing on a tile")
	adventurer.call("simulate_step", grid, [], resources)
	_require(adventurer.tile_pos == target, "crawler simulation tile should keep advancing while the visual body is still in transit")
	adventurer.call("_process", 1.0)
	_require(adventurer.position.distance_to(_tile_center(target)) < 0.01, "crawler visual position should finish at the latest simulation tile")
	var prey = CreatureScript.new()
	prey.call("initialize", "carrion_mite", target)
	var bat = CreatureScript.new()
	bat.call("initialize", "needle_bat", start)
	bat.call("simulate_step", grid, [bat, prey], [], resources)
	_require(bat.tile_pos == next, "monster simulation tile should advance immediately")
	_require(bat.position.distance_to(_tile_center(next)) > 2.0, "monster visual position should not snap to the next tile")
	bat.call("_process", 0.26)
	_require(bat.position.distance_to(_tile_center(next)) > 1.0, "monster visual stride should overlap the next simulation tick instead of pausing on a tile")
	bat.call("_process", 1.0)
	_require(bat.position.distance_to(_tile_center(next)) < 0.01, "monster visual position should finish at the simulation tile")
	grid.free()
	resources.free()
	adventurer.free()
	prey.free()
	bat.free()

func _tile_center(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * DungeonGrid.TILE_SIZE + DungeonGrid.TILE_SIZE * 0.5, coord.y * DungeonGrid.TILE_SIZE + DungeonGrid.TILE_SIZE * 0.5)

func _test_heart_must_be_reachable_to_place_start_and_fill() -> void:
	var main = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var isolated_heart: Vector2i = main.grid.start_center + Vector2i(5, 5)
	main.selected_tool = "dig"
	main.call("_handle_click", isolated_heart)
	main.selected_tool = "place_heart"
	main.call("_handle_click", isolated_heart)
	_require(main.grid.call("get_tile", isolated_heart).structure != "heart", "planning should reject Heart placement without an entrance path")
	main.grid.call("place_structure", isolated_heart, "heart")
	main.call("_start_dungeon")
	_require(main.planning_phase, "starting the dungeon should be blocked when the Heart is unreachable")
	main.grid.call("clear_structure", isolated_heart)
	var choke: Vector2i = main.grid.entrance_tile + Vector2i.RIGHT
	var reachable_heart: Vector2i = choke + Vector2i.RIGHT
	main.selected_tool = "dig"
	main.call("_handle_click", reachable_heart)
	main.selected_tool = "place_heart"
	main.call("_handle_click", reachable_heart)
	_require(main.grid.call("get_tile", reachable_heart).structure == "heart", "test setup should place a reachable Heart")
	main.selected_tool = "fill"
	main.call("_handle_click", choke)
	_require(main.grid.call("get_tile", choke).is_walkable(), "planning fill should refuse to sever the only path to the Heart")
	_require(main.grid.call("shortest_path_length", main.grid.entrance_tile, reachable_heart) >= 0, "Heart should remain reachable after blocked fill")
	main.free()
	var live_main = MainScene.instantiate()
	get_root().add_child(live_main)
	await process_frame
	var live_choke: Vector2i = live_main.grid.entrance_tile + Vector2i.RIGHT
	var live_heart: Vector2i = live_choke + Vector2i.RIGHT
	live_main.selected_tool = "dig"
	live_main.call("_handle_click", live_heart)
	live_main.selected_tool = "place_heart"
	live_main.call("_handle_click", live_heart)
	live_main.call("_start_dungeon")
	_require(not live_main.planning_phase, "test setup should start a live dungeon with a reachable Heart")
	live_main.selected_tool = "fill"
	live_main.call("_handle_click", live_choke)
	_require(live_main.grid.call("get_tile", live_choke).is_walkable(), "live fill should refuse to sever the only path to the Heart")
	_require(live_main.grid.call("shortest_path_length", live_main.grid.entrance_tile, live_heart) >= 0, "Heart should remain reachable after blocked live fill")
	live_main.free()

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
