@tool
class_name DungeonGrid
extends Node2D

signal hovered_tile_changed(coord: Vector2i)

const DungeonTileScript = preload("res://scripts/tile_data.gd")
const GRID_SIZE: int = 120
const TILE_SIZE: int = 32

var tiles: Array = []
var overlay_mode: String = "normal"
var hovered_tile: Vector2i = Vector2i(-1, -1)
var entrance_tile: Vector2i = Vector2i(0, 60)
var start_center: Vector2i = Vector2i(60, 60)
var shimmer_time: float = 0.0
var next_den_id: int = 1

func _ready() -> void:
	set_process(true)
	if Engine.is_editor_hint():
		ensure_preview_generated()

func ensure_preview_generated() -> void:
	if tiles.is_empty():
		generate_planning_map()

func generate_planning_map() -> void:
	tiles.clear()
	next_den_id = 1
	for x in range(GRID_SIZE):
		var column: Array = []
		for y in range(GRID_SIZE):
			var kind: int = DungeonTileScript.Kind.STONE
			if x == 0 or y == 0 or x == GRID_SIZE - 1 or y == GRID_SIZE - 1:
				kind = DungeonTileScript.Kind.WALL
			column.append(DungeonTileScript.new(kind))
		tiles.append(column)

	entrance_tile = Vector2i(0, start_center.y + randi_range(-10, 10))
	var entrance: DungeonTileData = get_tile(entrance_tile)
	entrance.kind = DungeonTileScript.Kind.ENTRANCE
	entrance.darkness = 48.0
	var foyer := entrance_tile + Vector2i.RIGHT
	if is_in_bounds(foyer):
		get_tile(foyer).set_floor()
		get_tile(foyer).darkness = 62.0
	queue_redraw()

func generate_cave() -> void:
	tiles.clear()
	next_den_id = 1
	for x in range(GRID_SIZE):
		var column: Array = []
		for y in range(GRID_SIZE):
			var kind: int = DungeonTileScript.Kind.STONE
			if x == 0 or y == 0 or x == GRID_SIZE - 1 or y == GRID_SIZE - 1:
				kind = DungeonTileScript.Kind.WALL
			column.append(DungeonTileScript.new(kind))
		tiles.append(column)

	var chamber_rx := 10
	var chamber_ry := 8
	for x in range(start_center.x - chamber_rx, start_center.x + chamber_rx + 1):
		for y in range(start_center.y - chamber_ry, start_center.y + chamber_ry + 1):
			var normalized := pow(float(x - start_center.x) / float(chamber_rx), 2.0) + pow(float(y - start_center.y) / float(chamber_ry), 2.0)
			if normalized <= 1.0 and is_in_bounds(Vector2i(x, y)):
				get_tile(Vector2i(x, y)).set_floor()

	entrance_tile = Vector2i(0, start_center.y + randi_range(-14, 14))
	get_tile(entrance_tile).kind = DungeonTileScript.Kind.ENTRANCE
	get_tile(entrance_tile).darkness = 54.0
	_carve_path(entrance_tile + Vector2i.RIGHT, start_center)
	_seed_starting_conditions()
	queue_redraw()

func _carve_path(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var cursor := from_tile
	while cursor.x != to_tile.x:
		if is_in_bounds(cursor):
			get_tile(cursor).set_floor()
			get_tile(cursor).darkness = lerpf(get_tile(cursor).darkness, 68.0, 0.35)
		cursor.x += _step_sign(to_tile.x - cursor.x)
	while cursor.y != to_tile.y:
		if is_in_bounds(cursor):
			get_tile(cursor).set_floor()
		cursor.y += _step_sign(to_tile.y - cursor.y)

func _step_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

func _seed_starting_conditions() -> void:
	for offset in [Vector2i(-4, 2), Vector2i(-3, 3), Vector2i(-5, 1)]:
		var coord: Vector2i = start_center + offset
		var tile: DungeonTileData = get_tile(coord)
		tile.moisture_source = true
		tile.moisture = 78.0
		tile.biomass = 34.0
	for offset in [Vector2i(5, -2), Vector2i(7, -1)]:
		var heat_tile: DungeonTileData = get_tile(start_center + offset)
		heat_tile.heat_source = true
		heat_tile.temperature = 82.0
	for offset in [Vector2i(2, 5), Vector2i(3, 6)]:
		var magic_tile: DungeonTileData = get_tile(start_center + offset)
		magic_tile.magic_source = true
		magic_tile.magic = 75.0

func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < GRID_SIZE and coord.y < GRID_SIZE

func get_tile(coord: Vector2i) -> DungeonTileData:
	return tiles[coord.x][coord.y]

func world_to_tile(world_position: Vector2) -> Vector2i:
	var local := to_local(world_position)
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.y / TILE_SIZE))

func tile_to_world(coord: Vector2i) -> Vector2:
	return to_global(Vector2(coord.x * TILE_SIZE + TILE_SIZE * 0.5, coord.y * TILE_SIZE + TILE_SIZE * 0.5))

func set_overlay(mode: String) -> void:
	overlay_mode = mode
	queue_redraw()

func dig(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if not tile.is_diggable():
		return false
	tile.set_floor()
	for neighbor in get_cardinal_neighbors(coord):
		if is_in_bounds(neighbor) and get_tile(neighbor).kind == DungeonTileScript.Kind.WALL:
			get_tile(neighbor).darkness = 95.0
	queue_redraw()
	return true

func fill(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if tile.kind != DungeonTileScript.Kind.FLOOR:
		return false
	if tile.structure != "":
		clear_structure(coord)
		return true
	tile.set_stone()
	queue_redraw()
	return true

func place_structure(coord: Vector2i, structure_name: String) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if not tile.is_walkable() or tile.kind == DungeonTileScript.Kind.ENTRANCE:
		return false
	if tile.structure != "":
		return false
	tile.structure = structure_name
	if structure_name == "heart":
		tile.heart_hp = 120
	elif structure_name == "trap":
		tile.trap_damage = 8
	queue_redraw()
	return true

func can_place_monster_den(anchor: Vector2i) -> bool:
	for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT + Vector2i.DOWN]:
		var coord: Vector2i = anchor + offset
		if not is_in_bounds(coord):
			return false
		var tile: DungeonTileData = get_tile(coord)
		if not tile.is_walkable() or tile.kind == DungeonTileScript.Kind.ENTRANCE:
			return false
		if tile.structure != "" or tile.den_id != -1:
			return false
	return true

func place_monster_den(anchor: Vector2i) -> bool:
	if not can_place_monster_den(anchor):
		return false
	var den_id := next_den_id
	next_den_id += 1
	for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT + Vector2i.DOWN]:
		var coord: Vector2i = anchor + offset
		var tile: DungeonTileData = get_tile(coord)
		tile.structure = "monster_den"
		tile.den_id = den_id
		tile.den_anchor = offset == Vector2i.ZERO
		tile.den_spawn_progress = 0
	queue_redraw()
	return true

func clear_structure(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if tile.structure == "":
		return false
	if tile.structure == "monster_den":
		clear_monster_den(tile.den_id)
		return true
	tile.structure = ""
	tile.heart_hp = 0
	tile.trap_damage = 0
	tile.locked_door = false
	queue_redraw()
	return true

func clear_monster_den(den_id: int) -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var tile: DungeonTileData = get_tile(Vector2i(x, y))
			if tile.den_id == den_id:
				tile.structure = ""
				tile.den_id = -1
				tile.den_anchor = false
				tile.den_spawn_progress = 0
	queue_redraw()

func den_anchors() -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			var tile: DungeonTileData = get_tile(coord)
			if tile.structure == "monster_den" and tile.den_anchor:
				anchors.append(coord)
	return anchors

func den_tiles(den_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			if get_tile(coord).den_id == den_id:
				result.append(coord)
	return result

func find_structure(structure_name: String) -> Vector2i:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			if get_tile(coord).structure == structure_name:
				return coord
	return Vector2i(-1, -1)

func find_structures(structure_name: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			if get_tile(coord).structure == structure_name:
				result.append(coord)
	return result

func visible_from(coord: Vector2i) -> Dictionary:
	var visible_tiles: Array[Vector2i] = []
	var frontier_doors: Array[Vector2i] = []
	if not is_in_bounds(coord) or not get_tile(coord).is_walkable():
		return {"tiles": visible_tiles, "doors": frontier_doors}
	var frontier: Array[Vector2i] = [coord]
	var visited: Dictionary = {coord: true}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		visible_tiles.append(current)
		for neighbor in walkable_neighbors(current):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			var neighbor_tile: DungeonTileData = get_tile(neighbor)
			if neighbor_tile.structure == "door":
				frontier_doors.append(neighbor)
			else:
				frontier.append(neighbor)
	return {"tiles": visible_tiles, "doors": frontier_doors}

func visible_structures(coord: Vector2i, structure_name: String) -> Array[Vector2i]:
	var visible: Dictionary = visible_from(coord)
	var result: Array[Vector2i] = []
	for tile_coord in visible["tiles"]:
		if get_tile(tile_coord).structure == structure_name:
			result.append(tile_coord)
	return result

func visible_doors(coord: Vector2i) -> Array[Vector2i]:
	var visible: Dictionary = visible_from(coord)
	return visible["doors"]

func get_build_warnings() -> Array[String]:
	var warnings: Array[String] = []
	var heart := find_structure("heart")
	if heart == Vector2i(-1, -1):
		warnings.append("Place the dungeon Heart before starting.")
	else:
		var path_to_heart := shortest_path_length(entrance_tile, heart)
		if path_to_heart < 0:
			warnings.append("Heart unreachable from entrance.")
		elif path_to_heart < 18:
			warnings.append("Very short path to Heart.")
	var treasures := find_structures("treasure")
	if treasures.is_empty():
		warnings.append("No treasure placed.")
	for treasure in treasures:
		if shortest_path_length(entrance_tile, treasure) < 0:
			warnings.append("Treasure unreachable at %s,%s." % [treasure.x, treasure.y])
	return warnings

func shortest_path_length(from_coord: Vector2i, to_coord: Vector2i) -> int:
	if not is_in_bounds(from_coord) or not is_in_bounds(to_coord):
		return -1
	if not get_tile(from_coord).is_walkable() or not get_tile(to_coord).is_walkable():
		return -1
	var frontier: Array[Vector2i] = [from_coord]
	var distances: Dictionary = {from_coord: 0}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		if current == to_coord:
			return int(distances[current])
		for neighbor in walkable_neighbors(current):
			if not distances.has(neighbor):
				distances[neighbor] = int(distances[current]) + 1
				frontier.append(neighbor)
	return -1

func find_path(from_coord: Vector2i, to_coord: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(from_coord) or not is_in_bounds(to_coord):
		return []
	if not get_tile(from_coord).is_walkable() or not get_tile(to_coord).is_walkable():
		return []
	var frontier: Array[Vector2i] = [from_coord]
	var came_from: Dictionary = {from_coord: from_coord}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		if current == to_coord:
			break
		for neighbor in walkable_neighbors(current):
			if not came_from.has(neighbor):
				came_from[neighbor] = current
				frontier.append(neighbor)
	if not came_from.has(to_coord):
		return []
	var path: Array[Vector2i] = []
	var step := to_coord
	while step != from_coord:
		path.push_front(step)
		step = came_from[step]
	path.push_front(from_coord)
	return path

func get_cardinal_neighbors(coord: Vector2i) -> Array[Vector2i]:
	return [
		coord + Vector2i.LEFT,
		coord + Vector2i.RIGHT,
		coord + Vector2i.UP,
		coord + Vector2i.DOWN,
	]

func walkable_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in get_cardinal_neighbors(coord):
		if is_in_bounds(neighbor) and get_tile(neighbor).is_walkable():
			result.append(neighbor)
	return result

func get_best_neighbor(coord: Vector2i, score_callable: Callable) -> Vector2i:
	var best := coord
	var best_score: float = score_callable.call(coord)
	for neighbor in walkable_neighbors(coord):
		var score: float = score_callable.call(neighbor)
		if score > best_score:
			best = neighbor
			best_score = score
	return best

func _process(delta: float) -> void:
	shimmer_time += delta
	var current_hover: Vector2i = world_to_tile(get_global_mouse_position())
	if current_hover != hovered_tile:
		hovered_tile = current_hover
		hovered_tile_changed.emit(hovered_tile)
		queue_redraw()
	if overlay_mode == "heat" or overlay_mode == "magic":
		queue_redraw()

func _draw() -> void:
	if tiles.is_empty():
		return
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, _tile_color(coord), true)
			_draw_tile_texture(coord, rect)
			if get_tile(coord).is_walkable():
				var grid_alpha := 0.22 if overlay_mode == "normal" else 0.10
				draw_rect(rect, Color(0.78, 0.70, 0.55, grid_alpha), false, 1.0)
			_draw_tile_effects(coord, rect)
	if is_in_bounds(hovered_tile):
		draw_rect(Rect2(hovered_tile.x * TILE_SIZE, hovered_tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color(0.8, 0.95, 0.75, 0.45), false, 2.0)

func _tile_color(coord: Vector2i) -> Color:
	var tile: DungeonTileData = get_tile(coord)
	if overlay_mode != "normal":
		return _overlay_color(tile)
	match tile.kind:
		DungeonTileScript.Kind.WALL:
			return Color(0.055, 0.040, 0.035)
		DungeonTileScript.Kind.STONE:
			return Color(0.24, 0.16, 0.10).lerp(Color(0.31, 0.22, 0.15), tile.moisture / 150.0)
		DungeonTileScript.Kind.ENTRANCE:
			return Color(0.47, 0.32, 0.17)
	var base := Color(0.36, 0.34, 0.31)
	base = base.lerp(Color(0.12, 0.32, 0.16), tile.biomass / 180.0)
	base = base.lerp(Color(0.68, 0.30, 0.08), max(tile.temperature - 45.0, 0.0) / 130.0)
	base = base.lerp(Color(0.30, 0.16, 0.58), tile.magic / 210.0)
	return base.darkened(tile.darkness / 650.0)

func _overlay_color(tile: DungeonTileData) -> Color:
	var amount := 0.0
	var tint := Color.WHITE
	match overlay_mode:
		"heat":
			amount = tile.temperature / 100.0
			tint = Color(1.0, 0.42, 0.08)
		"moisture":
			amount = tile.moisture / 100.0
			tint = Color(0.12, 0.55, 1.0)
		"magic":
			amount = tile.magic / 100.0
			tint = Color(0.68, 0.28, 1.0)
		"biomass":
			amount = tile.biomass / 100.0
			tint = Color(0.20, 0.95, 0.35)
	var base := Color(0.018, 0.018, 0.022) if not tile.is_walkable() else Color(0.035, 0.035, 0.038)
	return base.lerp(tint, clampf(amount * 0.85, 0.0, 0.85))

func _draw_tile_texture(coord: Vector2i, rect: Rect2) -> void:
	if overlay_mode != "normal":
		return
	var tile: DungeonTileData = get_tile(coord)
	if tile.kind == DungeonTileScript.Kind.STONE:
		var fleck_alpha := 0.08 + float((coord.x * 17 + coord.y * 31) % 5) * 0.018
		draw_line(rect.position + Vector2(5, 9 + (coord.x % 4)), rect.position + Vector2(15, 7 + (coord.y % 5)), Color(0.58, 0.42, 0.28, fleck_alpha), 1.0)
		draw_line(rect.position + Vector2(18, 22), rect.position + Vector2(28, 18 + (coord.x % 3)), Color(0.11, 0.07, 0.04, 0.12), 1.0)
	elif tile.is_walkable():
		var mortar := Color(0.13, 0.12, 0.11, 0.42)
		draw_line(rect.position + Vector2(0, 16), rect.position + Vector2(TILE_SIZE, 16), mortar, 1.0)
		draw_line(rect.position + Vector2(16, 0), rect.position + Vector2(16, 16), mortar, 1.0)
		draw_line(rect.position + Vector2(8, 16), rect.position + Vector2(8, TILE_SIZE), mortar, 1.0)
		draw_line(rect.position + Vector2(24, 16), rect.position + Vector2(24, TILE_SIZE), mortar, 1.0)

func _draw_tile_effects(coord: Vector2i, rect: Rect2) -> void:
	var tile = get_tile(coord)
	if not tile.is_walkable():
		return
	var center := rect.get_center()
	if tile.biomass > 18.0:
		var glow_alpha := clampf(tile.biomass / 180.0, 0.08, 0.48)
		draw_circle(center + Vector2(sin(coord.x * 1.7) * 4.0, cos(coord.y * 1.3) * 4.0), 3.0 + tile.biomass / 45.0, Color(0.38, 1.0, 0.45, glow_alpha))
	if tile.magic > 35.0:
		var mote_offset := Vector2(sin(shimmer_time * 2.4 + coord.x) * 7.0, cos(shimmer_time * 1.9 + coord.y) * 7.0)
		draw_circle(center + mote_offset, 2.2, Color(0.80, 0.38, 1.0, tile.magic / 180.0))
	if tile.temperature > 65.0:
		var heat_alpha := clampf((tile.temperature - 55.0) / 130.0, 0.08, 0.35)
		draw_line(center + Vector2(-7, sin(shimmer_time * 5.0 + coord.y) * 3.0), center + Vector2(7, sin(shimmer_time * 5.0 + coord.x) * 3.0), Color(1.0, 0.58, 0.12, heat_alpha), 1.2)
	_draw_structure(tile, center)

func _draw_structure(tile: DungeonTileData, center: Vector2) -> void:
	match tile.structure:
		"monster_den":
			draw_rect(Rect2(center - Vector2(13, 13), Vector2(26, 26)), Color(0.18, 0.09, 0.20, 0.92), true)
			draw_rect(Rect2(center - Vector2(10, 10), Vector2(20, 20)), Color(0.54, 0.28, 0.72, 0.75), false, 1.4)
			if tile.den_anchor:
				draw_circle(center, 4.0 + sin(shimmer_time * 3.0) * 1.0, Color(0.72, 0.96, 0.42, 0.85))
		"heart":
			draw_circle(center, 10.0, Color(0.92, 0.08, 0.22, 0.95))
			draw_circle(center, 5.0 + sin(shimmer_time * 4.0) * 1.2, Color(1.0, 0.36, 0.44, 0.95))
			if tile.heart_hp < 120:
				var bar_rect := Rect2(center + Vector2(-14, -22), Vector2(28, 4))
				var fill_width := 28.0 * clampf(float(tile.heart_hp) / 120.0, 0.0, 1.0)
				draw_rect(bar_rect, Color(0.08, 0.0, 0.0, 0.85), true)
				draw_rect(Rect2(bar_rect.position, Vector2(fill_width, 4)), Color(1.0, 0.12, 0.18, 0.95), true)
				draw_rect(bar_rect, Color(1.0, 0.75, 0.75, 0.65), false, 1.0)
		"treasure":
			draw_rect(Rect2(center - Vector2(7, 5), Vector2(14, 10)), Color(0.92, 0.66, 0.18, 0.95), true)
			draw_line(center + Vector2(-6, -1), center + Vector2(6, -1), Color(1.0, 0.90, 0.42, 0.9), 1.4)
		"trap":
			for i in range(3):
				var x := -7.0 + i * 7.0
				draw_polygon(PackedVector2Array([center + Vector2(x, 6), center + Vector2(x + 3, -6), center + Vector2(x + 6, 6)]), PackedColorArray([Color(0.78, 0.78, 0.72), Color(0.78, 0.78, 0.72), Color(0.78, 0.78, 0.72)]))
		"door":
			draw_rect(Rect2(center - Vector2(9, 11), Vector2(18, 22)), Color(0.42, 0.24, 0.12, 0.95), true)
			draw_line(center + Vector2(-7, -8), center + Vector2(7, -8), Color(0.72, 0.48, 0.26, 0.8), 1.2)
