@tool
class_name DungeonGrid
extends Node2D

signal hovered_tile_changed(coord: Vector2i)

const DungeonTileScript = preload("res://scripts/tile_data.gd")
const GRID_SIZE: int = 128
const CHUNK_SIZE: int = 32
const CHUNKS_PER_AXIS: int = 4
const TILE_SIZE: int = 32
const TILESET_ROOT := "res://assets/tilesets/0x72_DungeonTilesetII_v1.7"
const ACTION_ICON_ATLAS := "res://assets/ui/action_icons.png"
const ATLAS_TILE_SIZE: int = 16
const ACTION_ICON_SIZE: int = 64
const HEART_ICON_INDEX: int = 4
const TILEMAP_LAYER_SCALE := Vector2(float(TILE_SIZE) / float(ATLAS_TILE_SIZE), float(TILE_SIZE) / float(ATLAS_TILE_SIZE))
const FLOOR_REGIONS := [
	Rect2(0, 0, 16, 16),
	Rect2(16, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16),
	Rect2(0, 16, 16, 16),
	Rect2(16, 16, 16, 16),
	Rect2(32, 16, 16, 16),
	Rect2(48, 16, 16, 16),
]
const STONE_REGIONS := [
	Rect2(0, 0, 16, 16),
	Rect2(16, 0, 16, 16),
	Rect2(32, 0, 16, 16),
	Rect2(48, 0, 16, 16),
	Rect2(0, 16, 16, 16),
	Rect2(16, 16, 16, 16),
	Rect2(32, 16, 16, 16),
	Rect2(48, 16, 16, 16),
]
const OUTER_WALL_REGION := Rect2(32, 0, 16, 16)
const FLOOR_ATLAS_COORDS := [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(0, 2),
	Vector2i(1, 2),
]
const WALL_TERRAIN_MASK_ROWS := [
	["000010010", "000011010", "000111010", "000110010", "110111010", "000111011", "000111110", "011111010", "000011011", "010111111", "000111111", "000110110"],
	["010010010", "010011010", "010111010", "010110010", "010011011", "011111111", "110111111", "010110110", "011011011", "011111110", "000000000", "110111110"],
	["010010000", "010011000", "010111000", "010110000", "011011010", "111111011", "111111110", "110110010", "011111011", "111111111", "110111011", "110110110"],
	["000010000", "000011000", "000111000", "000110000", "010111110", "011111000", "110111000", "010111011", "011011000", "111111000", "111111010", "110110000"],
]
const TERRAIN_MASK_PEERING_BITS := [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	-1,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]
const WALL_SPRITE_NAMES := [
	"wall_mid", "wall_left", "wall_right", "wall_top_mid", "wall_top_left", "wall_top_right",
	"wall_edge_bottom_left", "wall_edge_bottom_right", "wall_edge_left", "wall_edge_right",
	"wall_edge_mid_left", "wall_edge_mid_right", "wall_edge_top_left", "wall_edge_top_right",
	"wall_edge_tshape_bottom_left", "wall_edge_tshape_bottom_right", "wall_edge_tshape_left", "wall_edge_tshape_right",
	"wall_outer_front_left", "wall_outer_front_right", "wall_outer_mid_left", "wall_outer_mid_right",
	"wall_outer_top_left", "wall_outer_top_right",
]
const DEN_ROOM_DEPTH: int = 3
const DEN_ROOM_HALF_WIDTH: int = 1

var tiles: Array = []
var overlay_mode: String = "normal"
var hovered_tile: Vector2i = Vector2i(-1, -1)
var start_chunk: Vector2i = Vector2i(0, 1)
var entrance_tile: Vector2i = Vector2i(0, 48)
var start_center: Vector2i = Vector2i(16, 48)
var shimmer_time: float = 0.0
var next_den_id: int = 1
var unlocked_chunks: Dictionary = {}
var dungeon_floor_tileset: Texture2D
var dungeon_wall_tileset: Texture2D
var dungeon_door_texture: Texture2D
var dungeon_treasure_texture: Texture2D
var action_icon_atlas: Texture2D
var dungeon_floor_textures: Array[Texture2D] = []
var dungeon_spike_textures: Array[Texture2D] = []
var dungeon_wall_textures: Dictionary = {}
var floor_tile_layer: TileMapLayer
var wall_backing_layer: TileMapLayer
var wall_tile_layer: TileMapLayer
var floor_tile_set: TileSet
var wall_backing_tile_set: TileSet
var wall_tile_set: TileSet
var tilemap_layers_dirty: bool = true
var tilemap_full_refresh_pending: bool = true
var tilemap_dirty_cells: Dictionary = {}
var tilemap_batch_depth: int = 0
var tilemap_batched_full_refresh: bool = false
var tilemap_batched_chunks: Dictionary = {}
var drag_preview_tiles: Dictionary = {}
var placement_preview_tiles: Dictionary = {}
var placement_preview_valid: bool = true

func _ready() -> void:
	_ensure_tilesets_loaded()
	_ensure_tilemap_layers()
	set_process(true)
	if Engine.is_editor_hint():
		ensure_preview_generated()

func _ensure_tilesets_loaded() -> void:
	if dungeon_floor_tileset != null and dungeon_wall_tileset != null and dungeon_door_texture != null and dungeon_treasure_texture != null and action_icon_atlas != null and dungeon_floor_textures.size() == 8 and dungeon_spike_textures.size() == 4 and dungeon_wall_textures.size() == WALL_SPRITE_NAMES.size():
		return
	dungeon_floor_tileset = _load_texture("%s/atlas_floor-16x16.png" % TILESET_ROOT)
	dungeon_wall_tileset = _load_texture("%s/atlas_walls_low-16x16.png" % TILESET_ROOT)
	dungeon_door_texture = _load_texture("%s/frames/doors_leaf_closed.png" % TILESET_ROOT)
	dungeon_treasure_texture = _load_texture("%s/frames/chest_full_open_anim_f0.png" % TILESET_ROOT)
	action_icon_atlas = _load_texture(ACTION_ICON_ATLAS)
	if dungeon_floor_textures.is_empty():
		for floor_index in range(1, 9):
			dungeon_floor_textures.append(_load_texture("%s/frames/floor_%s.png" % [TILESET_ROOT, floor_index]))
	if dungeon_spike_textures.is_empty():
		for frame_index in range(4):
			dungeon_spike_textures.append(_load_texture("%s/frames/floor_spikes_anim_f%s.png" % [TILESET_ROOT, frame_index]))
	if dungeon_wall_textures.is_empty():
		for sprite_name in WALL_SPRITE_NAMES:
			dungeon_wall_textures[sprite_name] = _load_texture("%s/frames/%s.png" % [TILESET_ROOT, sprite_name])

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := ResourceLoader.load(path)
		if imported is Texture2D:
			return imported
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _ensure_tilemap_layers() -> void:
	if floor_tile_layer == null or not is_instance_valid(floor_tile_layer):
		floor_tile_layer = get_node_or_null("FloorTileLayer") as TileMapLayer
		if floor_tile_layer == null:
			floor_tile_layer = TileMapLayer.new()
			floor_tile_layer.name = "FloorTileLayer"
			add_child(floor_tile_layer)
	if wall_backing_layer == null or not is_instance_valid(wall_backing_layer):
		wall_backing_layer = get_node_or_null("WallBackingLayer") as TileMapLayer
		if wall_backing_layer == null:
			wall_backing_layer = TileMapLayer.new()
			wall_backing_layer.name = "WallBackingLayer"
			add_child(wall_backing_layer)
	if wall_tile_layer == null or not is_instance_valid(wall_tile_layer):
		wall_tile_layer = get_node_or_null("WallTileLayer") as TileMapLayer
		if wall_tile_layer == null:
			wall_tile_layer = TileMapLayer.new()
			wall_tile_layer.name = "WallTileLayer"
			add_child(wall_tile_layer)
	for layer in [floor_tile_layer, wall_backing_layer, wall_tile_layer]:
		layer.scale = TILEMAP_LAYER_SCALE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.visible = overlay_mode == "normal"
	floor_tile_layer.z_index = -30
	wall_backing_layer.z_index = -25
	wall_tile_layer.z_index = -20
	if floor_tile_set == null:
		floor_tile_set = _create_floor_tile_set()
	if wall_backing_tile_set == null:
		wall_backing_tile_set = _create_wall_backing_tile_set()
	if wall_tile_set == null:
		wall_tile_set = _create_wall_terrain_tile_set()
	floor_tile_layer.tile_set = floor_tile_set
	wall_backing_layer.tile_set = wall_backing_tile_set
	wall_tile_layer.tile_set = wall_tile_set

func _create_floor_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	if dungeon_floor_tileset == null:
		return tile_set
	var source := TileSetAtlasSource.new()
	source.texture = dungeon_floor_tileset
	source.texture_region_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	for atlas_coord in FLOOR_ATLAS_COORDS:
		source.create_tile(atlas_coord)
	tile_set.add_source(source, 0)
	return tile_set

func _create_wall_backing_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	var texture: Texture2D = dungeon_wall_textures.get("wall_mid", null)
	if texture == null:
		var image := Image.create(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.22, 0.17, 0.14, 1.0))
		texture = ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	return tile_set

func _create_wall_terrain_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "wall")
	if dungeon_wall_tileset == null:
		return tile_set
	var source := TileSetAtlasSource.new()
	source.texture = dungeon_wall_tileset
	source.texture_region_size = Vector2i(ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)
	for y in range(WALL_TERRAIN_MASK_ROWS.size()):
		for x in range(WALL_TERRAIN_MASK_ROWS[y].size()):
			var mask: String = WALL_TERRAIN_MASK_ROWS[y][x]
			if mask == "000000000":
				continue
			var atlas_coord := Vector2i(x, y)
			source.create_tile(atlas_coord)
			var tile_data := source.get_tile_data(atlas_coord, 0)
			tile_data.terrain_set = 0
			tile_data.terrain = 0
			_apply_terrain_mask(tile_data, mask)
	tile_set.add_source(source, 0)
	return tile_set

func _apply_terrain_mask(tile_data: TileData, mask: String) -> void:
	for bit in TERRAIN_MASK_PEERING_BITS:
		if bit != -1:
			tile_data.set_terrain_peering_bit(bit, -1)
	for index in range(min(mask.length(), TERRAIN_MASK_PEERING_BITS.size())):
		var peering_bit: int = TERRAIN_MASK_PEERING_BITS[index]
		if peering_bit != -1 and mask[index] == "1":
			tile_data.set_terrain_peering_bit(peering_bit, 0)

func begin_tilemap_batch() -> void:
	tilemap_batch_depth += 1

func end_tilemap_batch() -> void:
	if tilemap_batch_depth <= 0:
		return
	tilemap_batch_depth -= 1
	if tilemap_batch_depth > 0:
		return
	if tilemap_batched_full_refresh:
		tilemap_full_refresh_pending = true
	else:
		for chunk in tilemap_batched_chunks.keys():
			_mark_tilemap_chunk_dirty(chunk)
	tilemap_batched_full_refresh = false
	tilemap_batched_chunks.clear()
	tilemap_layers_dirty = true
	queue_redraw()

func _mark_tilemap_layers_dirty(center: Vector2i = Vector2i(-9999, -9999), radius: int = 2) -> void:
	if center == Vector2i(-9999, -9999):
		if tilemap_batch_depth > 0:
			tilemap_batched_full_refresh = true
		else:
			tilemap_full_refresh_pending = true
	else:
		if tilemap_batch_depth > 0:
			tilemap_batched_chunks[chunk_for_coord(center)] = true
		else:
			_mark_tilemap_radius_dirty(center, radius)
	tilemap_layers_dirty = true
	if tilemap_batch_depth <= 0:
		queue_redraw()

func _mark_tilemap_radius_dirty(center: Vector2i, radius: int) -> void:
	for x in range(maxi(0, center.x - radius), mini(GRID_SIZE, center.x + radius + 1)):
		for y in range(maxi(0, center.y - radius), mini(GRID_SIZE, center.y + radius + 1)):
			tilemap_dirty_cells[Vector2i(x, y)] = true

func _mark_tilemap_chunk_dirty(chunk: Vector2i, margin: int = 2) -> void:
	var origin := chunk_origin(chunk)
	for x in range(maxi(0, origin.x - margin), mini(GRID_SIZE, origin.x + CHUNK_SIZE + margin)):
		for y in range(maxi(0, origin.y - margin), mini(GRID_SIZE, origin.y + CHUNK_SIZE + margin)):
			tilemap_dirty_cells[Vector2i(x, y)] = true

func _update_tilemap_visibility() -> void:
	if floor_tile_layer != null and is_instance_valid(floor_tile_layer):
		floor_tile_layer.visible = overlay_mode == "normal"
	if wall_backing_layer != null and is_instance_valid(wall_backing_layer):
		wall_backing_layer.visible = overlay_mode == "normal"
	if wall_tile_layer != null and is_instance_valid(wall_tile_layer):
		wall_tile_layer.visible = overlay_mode == "normal"

func _refresh_tilemap_layers() -> void:
	if tiles.is_empty():
		return
	_ensure_tilesets_loaded()
	_ensure_tilemap_layers()
	_update_tilemap_visibility()
	if tilemap_full_refresh_pending:
		_refresh_all_tilemap_cells()
	else:
		_refresh_dirty_tilemap_cells()
	tilemap_layers_dirty = false

func _refresh_all_tilemap_cells() -> void:
	floor_tile_layer.clear()
	wall_backing_layer.clear()
	wall_tile_layer.clear()
	var wall_cells: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			if _is_layout_floor(coord):
				floor_tile_layer.set_cell(coord, 0, _floor_atlas_coord(coord))
			elif _is_wall_terrain_cell(coord):
				wall_backing_layer.set_cell(coord, 0, Vector2i.ZERO)
				wall_cells.append(coord)
	if not wall_cells.is_empty():
		wall_tile_layer.set_cells_terrain_connect(wall_cells, 0, 0, true)
	tilemap_dirty_cells.clear()
	tilemap_full_refresh_pending = false

func _refresh_dirty_tilemap_cells() -> void:
	if tilemap_dirty_cells.is_empty():
		return
	var wall_cells: Array[Vector2i] = []
	for coord in tilemap_dirty_cells.keys():
		floor_tile_layer.erase_cell(coord)
		wall_backing_layer.erase_cell(coord)
		wall_tile_layer.erase_cell(coord)
	for coord in tilemap_dirty_cells.keys():
		if _is_layout_floor(coord):
			floor_tile_layer.set_cell(coord, 0, _floor_atlas_coord(coord))
		elif _is_wall_terrain_cell(coord):
			wall_backing_layer.set_cell(coord, 0, Vector2i.ZERO)
			wall_cells.append(coord)
	if not wall_cells.is_empty():
		wall_tile_layer.set_cells_terrain_connect(wall_cells, 0, 0, true)
	tilemap_dirty_cells.clear()

func set_drag_preview_tiles(coords: Array[Vector2i]) -> void:
	drag_preview_tiles.clear()
	for coord in coords:
		if is_in_bounds(coord):
			drag_preview_tiles[coord] = true
	queue_redraw()

func clear_drag_preview_tiles() -> void:
	if drag_preview_tiles.is_empty():
		return
	drag_preview_tiles.clear()
	queue_redraw()

func set_placement_preview_tiles(coords: Array[Vector2i], valid: bool = true) -> void:
	placement_preview_tiles.clear()
	placement_preview_valid = valid
	for coord in coords:
		if is_in_bounds(coord):
			placement_preview_tiles[coord] = true
	queue_redraw()

func clear_placement_preview_tiles() -> void:
	if placement_preview_tiles.is_empty():
		return
	placement_preview_tiles.clear()
	queue_redraw()

func placement_preview_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for coord in placement_preview_tiles.keys():
		coords.append(coord)
	return coords

func chunk_for_coord(coord: Vector2i) -> Vector2i:
	return Vector2i(floori(float(coord.x) / float(CHUNK_SIZE)), floori(float(coord.y) / float(CHUNK_SIZE)))

func chunk_origin(chunk: Vector2i) -> Vector2i:
	return Vector2i(chunk.x * CHUNK_SIZE, chunk.y * CHUNK_SIZE)

func chunk_center_tile(chunk: Vector2i) -> Vector2i:
	return chunk_origin(chunk) + Vector2i(CHUNK_SIZE / 2, CHUNK_SIZE / 2)

func is_chunk_coord_in_bounds(chunk: Vector2i) -> bool:
	return chunk.x >= 0 and chunk.y >= 0 and chunk.x < CHUNKS_PER_AXIS and chunk.y < CHUNKS_PER_AXIS

func is_chunk_unlocked(chunk: Vector2i) -> bool:
	return unlocked_chunks.has(chunk)

func is_in_unlocked_chunk(coord: Vector2i) -> bool:
	return is_in_bounds(coord) and is_chunk_unlocked(chunk_for_coord(coord))

func unlocked_chunk_count() -> int:
	return unlocked_chunks.size()

func can_unlock_chunk(chunk: Vector2i) -> bool:
	if not is_chunk_coord_in_bounds(chunk) or is_chunk_unlocked(chunk):
		return false
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_chunk_unlocked(chunk + offset):
			return true
	return false

func unlock_chunk(chunk: Vector2i) -> bool:
	if not can_unlock_chunk(chunk):
		return false
	unlocked_chunks[chunk] = true
	queue_redraw()
	return true

func lock_chunk(chunk: Vector2i) -> void:
	if chunk == start_chunk:
		return
	unlocked_chunks.erase(chunk)
	queue_redraw()

func _reset_unlocked_chunks() -> void:
	unlocked_chunks.clear()
	unlocked_chunks[start_chunk] = true

func _floor_atlas_coord(coord: Vector2i) -> Vector2i:
	if FLOOR_ATLAS_COORDS.is_empty():
		return Vector2i.ZERO
	var hash: int = abs(coord.x * 19 + coord.y * 31)
	var roll: int = hash % 20
	var index: int = roll % 3
	if roll >= 15:
		index = 3 + (hash % 5)
	return FLOOR_ATLAS_COORDS[index]

func _is_wall_terrain_cell(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if tile.is_walkable():
		return false
	for offset in [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP + Vector2i.LEFT,
		Vector2i.UP + Vector2i.RIGHT,
		Vector2i.DOWN + Vector2i.LEFT,
		Vector2i.DOWN + Vector2i.RIGHT,
	]:
		if _is_layout_floor(coord + offset):
			return true
	return false

func ensure_preview_generated() -> void:
	if tiles.is_empty():
		generate_planning_map()

func generate_planning_map() -> void:
	tiles.clear()
	next_den_id = 1
	start_center = chunk_center_tile(start_chunk)
	entrance_tile = Vector2i(chunk_origin(start_chunk).x, start_center.y)
	_reset_unlocked_chunks()
	for x in range(GRID_SIZE):
		var column: Array = []
		for y in range(GRID_SIZE):
			var kind: int = DungeonTileScript.Kind.STONE
			if x == 0 or y == 0 or x == GRID_SIZE - 1 or y == GRID_SIZE - 1:
				kind = DungeonTileScript.Kind.WALL
			column.append(DungeonTileScript.new(kind))
		tiles.append(column)

	entrance_tile = Vector2i(chunk_origin(start_chunk).x, start_center.y + randi_range(-10, 10))
	var entrance: DungeonTileData = get_tile(entrance_tile)
	entrance.kind = DungeonTileScript.Kind.ENTRANCE
	entrance.darkness = 48.0
	var foyer := entrance_tile + Vector2i.RIGHT
	if is_in_bounds(foyer):
		get_tile(foyer).set_floor()
		get_tile(foyer).darkness = 62.0
	_mark_tilemap_layers_dirty()

func generate_cave() -> void:
	tiles.clear()
	next_den_id = 1
	start_center = chunk_center_tile(start_chunk)
	entrance_tile = Vector2i(chunk_origin(start_chunk).x, start_center.y)
	_reset_unlocked_chunks()
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
	_mark_tilemap_layers_dirty()

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
	_update_tilemap_visibility()
	queue_redraw()

func dig(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if not tile.is_diggable():
		return false
	if would_expand_prefab_room(coord):
		return false
	tile.set_floor()
	for neighbor in get_cardinal_neighbors(coord):
		if is_in_bounds(neighbor) and get_tile(neighbor).kind == DungeonTileScript.Kind.WALL:
			get_tile(neighbor).darkness = 95.0
	_mark_tilemap_layers_dirty(coord)
	return true

func fill(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if tile.kind != DungeonTileScript.Kind.FLOOR:
		return false
	if tile.prefab_room_id != -1:
		return false
	if tile.structure != "" or tile.secret_tunnel or tile.heat_source or tile.moisture_source or tile.magic_source or tile.spore_seed:
		return false
	tile.set_stone()
	_mark_tilemap_layers_dirty(coord)
	return true

func place_structure(coord: Vector2i, structure_name: String) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if not tile.is_walkable() or tile.kind == DungeonTileScript.Kind.ENTRANCE:
		return false
	if tile.structure != "" or tile.secret_tunnel:
		return false
	tile.structure = structure_name
	if structure_name == "heart":
		tile.heart_hp = 120
	elif structure_name == "trap":
		tile.trap_damage = 8
	elif structure_name == "poison_trap":
		tile.poison_damage = 2
		tile.poison_duration = 4
	elif structure_name == "locked_door":
		tile.structure = "door"
		tile.locked_door = true
		tile.door_hp = 18
	elif structure_name == "secret_tunnel":
		tile.secret_tunnel = true
		tile.structure = ""
	queue_redraw()
	return true

func can_place_monster_den(connector: Vector2i) -> bool:
	return not monster_den_room_tiles(connector).is_empty()

func place_monster_den(connector: Vector2i, den_kind: String = "goblin") -> bool:
	var floor_tiles := monster_den_room_tiles(connector)
	if floor_tiles.is_empty():
		return false
	var direction := _den_room_direction(connector)
	var anchor := monster_den_room_anchor(connector)
	var den_id := next_den_id
	next_den_id += 1
	begin_tilemap_batch()
	for coord in floor_tiles:
		var tile: DungeonTileData = get_tile(coord)
		tile.set_floor()
		tile.darkness = max(tile.darkness, 92.0)
		tile.prefab_room_id = den_id
		tile.prefab_room_kind = "monster_den"
		_mark_tilemap_layers_dirty(coord)
	var den_offsets := _den_footprint_offsets(direction)
	for offset in den_offsets:
		var coord: Vector2i = anchor + offset
		var tile: DungeonTileData = get_tile(coord)
		tile.prefab_room_id = den_id
		tile.prefab_room_kind = "monster_den"
		tile.structure = "monster_den"
		tile.den_id = den_id
		tile.den_anchor = offset == Vector2i.ZERO
		tile.den_spawn_progress = 0
		tile.den_research_progress = 0
		tile.den_kind = den_kind
		tile.den_order = "guard_room"
		tile.den_target = room_center_tile(anchor)
	end_tilemap_batch()
	return true

func place_carrion_den(anchor: Vector2i) -> bool:
	return place_monster_den(anchor, "carrion")

func monster_den_room_anchor(connector: Vector2i) -> Vector2i:
	var direction := _den_room_direction(connector)
	if direction == Vector2i.ZERO:
		return Vector2i(-1, -1)
	return connector + direction

func monster_den_room_tiles(connector: Vector2i) -> Array[Vector2i]:
	var direction := _den_room_direction(connector)
	if direction == Vector2i.ZERO:
		return []
	var anchor := connector + direction
	var perpendicular := Vector2i(-direction.y, direction.x)
	var result: Array[Vector2i] = [connector]
	for depth in range(DEN_ROOM_DEPTH):
		for width in range(-DEN_ROOM_HALF_WIDTH, DEN_ROOM_HALF_WIDTH + 1):
			result.append(anchor + direction * depth + perpendicular * width)
	for side in [-1, 1]:
		result.append(anchor + direction + perpendicular * side * 2)
	var seen := {}
	var unique: Array[Vector2i] = []
	for coord in result:
		if seen.has(coord):
			continue
		seen[coord] = true
		if not _can_claim_den_room_tile(coord, connector):
			return []
		unique.append(coord)
	for den_coord in _den_footprint_tiles(connector):
		if den_coord == Vector2i(-1, -1):
			return []
		if not unique.has(den_coord):
			return []
	return unique

func _den_room_direction(connector: Vector2i) -> Vector2i:
	if not is_in_bounds(connector) or not is_in_unlocked_chunk(connector):
		return Vector2i.ZERO
	var connector_tile: DungeonTileData = get_tile(connector)
	if connector_tile.structure != "" or connector_tile.den_id != -1 or connector_tile.secret_tunnel:
		return Vector2i.ZERO
	if not connector_tile.is_diggable():
		return Vector2i.ZERO
	var adjacent_floors: Array[Vector2i] = []
	for neighbor in get_cardinal_neighbors(connector):
		if is_in_bounds(neighbor) and get_tile(neighbor).is_walkable():
			adjacent_floors.append(neighbor)
	for floor_coord in adjacent_floors:
		var direction := connector - floor_coord
		var anchor := connector + direction
		if is_in_bounds(anchor) and is_in_unlocked_chunk(anchor) and get_tile(anchor).is_diggable():
			return direction
	return Vector2i.ZERO

func _can_claim_den_room_tile(coord: Vector2i, connector: Vector2i) -> bool:
	if not is_in_bounds(coord) or not is_in_unlocked_chunk(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if coord == connector:
		return tile.is_diggable() and tile.structure == "" and tile.den_id == -1 and tile.prefab_room_id == -1 and not tile.secret_tunnel
	if not tile.is_diggable():
		return false
	return tile.structure == "" and tile.den_id == -1 and tile.prefab_room_id == -1 and not tile.secret_tunnel

func _den_footprint_tiles(connector: Vector2i) -> Array[Vector2i]:
	var direction := _den_room_direction(connector)
	if direction == Vector2i.ZERO:
		return []
	var anchor := connector + direction
	var result: Array[Vector2i] = []
	for offset in _den_footprint_offsets(direction):
		result.append(anchor + offset)
	return result

func _den_footprint_offsets(direction: Vector2i) -> Array[Vector2i]:
	var perpendicular := Vector2i(-direction.y, direction.x)
	return [Vector2i.ZERO, perpendicular, direction, direction + perpendicular]

func clear_structure(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if tile.structure == "" and not tile.secret_tunnel:
		return false
	if tile.structure == "monster_den":
		clear_monster_den(tile.den_id)
		return true
	tile.clear_structure_state()
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
				tile.den_research_progress = 0
				tile.den_kind = "goblin"
				tile.den_order = "guard_room"
				tile.den_target = Vector2i(-1, -1)
			if tile.prefab_room_id == den_id:
				tile.prefab_room_id = -1
				tile.prefab_room_kind = ""
	queue_redraw()

func prefab_room_tiles(prefab_id: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if prefab_id == -1:
		return coords
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var coord := Vector2i(x, y)
			if get_tile(coord).prefab_room_id == prefab_id:
				coords.append(coord)
	return coords

func remove_prefab_room(prefab_id: int) -> bool:
	var coords := prefab_room_tiles(prefab_id)
	if coords.is_empty():
		return false
	begin_tilemap_batch()
	for coord in coords:
		get_tile(coord).set_stone()
		_mark_tilemap_layers_dirty(coord)
	end_tilemap_batch()
	return true

func would_expand_prefab_room(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	if not tile.is_diggable():
		return false
	for neighbor in get_cardinal_neighbors(coord):
		if is_in_bounds(neighbor) and get_tile(neighbor).prefab_room_id != -1:
			return true
	return false

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

func den_anchor_for_id(den_id: int) -> Vector2i:
	for coord in den_tiles(den_id):
		if get_tile(coord).den_anchor:
			return coord
	return Vector2i(-1, -1)

func set_den_order(den_id: int, order: String, target: Vector2i) -> bool:
	var tiles_for_den := den_tiles(den_id)
	if tiles_for_den.is_empty():
		return false
	for coord in tiles_for_den:
		var tile: DungeonTileData = get_tile(coord)
		tile.den_order = order
		tile.den_target = target
	queue_redraw()
	return true

func room_tiles_from(start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_in_bounds(start):
		return result
	var start_tile: DungeonTileData = get_tile(start)
	if not start_tile.is_walkable() or start_tile.structure == "door":
		return result
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		result.append(current)
		for neighbor in walkable_neighbors(current):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			if get_tile(neighbor).structure == "door":
				continue
			frontier.append(neighbor)
	return result

func room_center_tile(start: Vector2i) -> Vector2i:
	var room := room_tiles_from(start)
	if room.is_empty():
		return start
	var sum := Vector2.ZERO
	for coord in room:
		sum += Vector2(coord.x, coord.y)
	var average := sum / float(room.size())
	var best: Vector2i = room[0]
	var best_distance := 999999.0
	for coord in room:
		var distance := Vector2(coord.x, coord.y).distance_squared_to(average)
		if distance < best_distance:
			best = coord
			best_distance = distance
	return best

func room_profile_from(start: Vector2i) -> Dictionary:
	var room := room_tiles_from(start)
	var profile := {
		"identity": "none",
		"label": "None",
		"size": room.size(),
		"door_count": 0,
		"treasure_count": 0,
		"trap_count": 0,
		"den_count": 0,
		"heart_count": 0,
		"avg_magic": 0.0,
	}
	if room.is_empty():
		return profile
	var doors := {}
	var magic_total := 0.0
	for coord in room:
		var tile: DungeonTileData = get_tile(coord)
		magic_total += tile.magic
		if tile.structure == "treasure":
			profile["treasure_count"] += 1
		elif tile.structure == "trap" or tile.structure == "poison_trap":
			profile["trap_count"] += 1
		elif tile.structure == "monster_den" and tile.den_anchor:
			profile["den_count"] += 1
		elif tile.structure == "heart":
			profile["heart_count"] += 1
		for neighbor in get_cardinal_neighbors(coord):
			if is_in_bounds(neighbor) and get_tile(neighbor).structure == "door":
				doors[neighbor] = true
	profile["door_count"] = doors.size()
	profile["avg_magic"] = magic_total / float(room.size())
	var identity := "chamber"
	var label := "Chamber"
	if int(profile["heart_count"]) > 0:
		identity = "heart_chamber"
		label = "Heart chamber"
	elif int(profile["den_count"]) > 0 and int(profile["door_count"]) > 0 and float(profile["avg_magic"]) >= 42.0:
		identity = "research_chamber"
		label = "Research chamber"
	elif int(profile["trap_count"]) >= 2:
		identity = "trap_hall"
		label = "Trap hall"
	elif int(profile["treasure_count"]) > 0:
		identity = "treasure_vault"
		label = "Treasure vault"
	elif int(profile["den_count"]) > 0:
		identity = "hatchery"
		label = "Hatchery"
	elif room.size() <= 5:
		identity = "corridor"
		label = "Corridor"
	profile["identity"] = identity
	profile["label"] = label
	return profile

func nearest_room_door(start: Vector2i) -> Vector2i:
	var room := room_tiles_from(start)
	var best := Vector2i(-1, -1)
	var best_distance := 999999.0
	for coord in room:
		for neighbor in get_cardinal_neighbors(coord):
			if is_in_bounds(neighbor) and get_tile(neighbor).structure == "door":
				var distance := start.distance_squared_to(neighbor)
				if distance < best_distance:
					best = neighbor
					best_distance = distance
	return best

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
	return shortest_path_length_avoiding(from_coord, to_coord, {})

func shortest_path_length_avoiding(from_coord: Vector2i, to_coord: Vector2i, blocked_coords: Dictionary) -> int:
	if not is_in_bounds(from_coord) or not is_in_bounds(to_coord):
		return -1
	if blocked_coords.has(from_coord) or blocked_coords.has(to_coord):
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
			if blocked_coords.has(neighbor) or distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			frontier.append(neighbor)
	return -1

func find_path(from_coord: Vector2i, to_coord: Vector2i) -> Array[Vector2i]:
	return _find_path_internal(from_coord, to_coord, {})

func find_path_for_crawler(from_coord: Vector2i, to_coord: Vector2i, discovered_secret_tunnels: Dictionary = {}) -> Array[Vector2i]:
	return _find_path_internal(from_coord, to_coord, discovered_secret_tunnels, true)

func _find_path_internal(from_coord: Vector2i, to_coord: Vector2i, discovered_secret_tunnels: Dictionary = {}, avoid_secret_tunnels: bool = false) -> Array[Vector2i]:
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
			if avoid_secret_tunnels and get_tile(neighbor).secret_tunnel and not discovered_secret_tunnels.has(neighbor):
				continue
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
	if tilemap_layers_dirty:
		_refresh_tilemap_layers()
	shimmer_time += delta
	var current_hover: Vector2i = world_to_tile(get_global_mouse_position())
	if current_hover != hovered_tile:
		hovered_tile = current_hover
		hovered_tile_changed.emit(hovered_tile)
		queue_redraw()
	if overlay_mode == "heat" or overlay_mode == "magic":
		queue_redraw()
	elif find_structure("heart") != Vector2i(-1, -1):
		queue_redraw()

func _draw() -> void:
	if tiles.is_empty():
		return
	_ensure_tilesets_loaded()
	if tilemap_layers_dirty:
		_refresh_tilemap_layers()
	var drawn_tiles: Dictionary = {}
	for draw_bounds in _manual_draw_tile_rects():
		for x in range(draw_bounds.position.x, draw_bounds.end.x):
			for y in range(draw_bounds.position.y, draw_bounds.end.y):
				var coord := Vector2i(x, y)
				if drawn_tiles.has(coord):
					continue
				drawn_tiles[coord] = true
				var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
				var tilemap_base := _tilemap_covers_base(coord)
				if not tilemap_base:
					draw_rect(rect, _tile_color(coord), true)
				if not tilemap_base:
					_draw_tile_texture(coord, rect)
				if get_tile(coord).is_walkable():
					var grid_alpha := 0.22 if overlay_mode == "normal" else 0.10
					draw_rect(rect, Color(0.78, 0.70, 0.55, grid_alpha), false, 1.0)
				_draw_tile_effects(coord, rect)
	_draw_chunk_influence_overlays()
	_draw_drag_preview_tiles()
	_draw_placement_preview_tiles()
	if placement_preview_tiles.is_empty() and is_in_bounds(hovered_tile):
		draw_rect(Rect2(hovered_tile.x * TILE_SIZE, hovered_tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE), Color(0.8, 0.95, 0.75, 0.45), false, 2.0)

func _manual_draw_tile_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for chunk in unlocked_chunks.keys():
		var origin := chunk_origin(chunk)
		var start := Vector2i(maxi(0, origin.x - 2), maxi(0, origin.y - 2))
		var end := Vector2i(mini(GRID_SIZE, origin.x + CHUNK_SIZE + 2), mini(GRID_SIZE, origin.y + CHUNK_SIZE + 2))
		rects.append(Rect2i(start, end - start))
	return rects

func _draw_chunk_influence_overlays() -> void:
	var chunk_pixels := CHUNK_SIZE * TILE_SIZE
	for chunk_x in range(CHUNKS_PER_AXIS):
		for chunk_y in range(CHUNKS_PER_AXIS):
			var chunk := Vector2i(chunk_x, chunk_y)
			var rect := Rect2(chunk_x * chunk_pixels, chunk_y * chunk_pixels, chunk_pixels, chunk_pixels)
			if not is_chunk_unlocked(chunk):
				draw_rect(rect, Color(0.0, 0.0, 0.0, 0.24), true)
				draw_rect(rect, Color(0.28, 0.20, 0.13, 0.45), false, 2.0)
			else:
				draw_rect(rect, Color(0.52, 0.84, 0.55, 0.42), false, 2.0)

func _draw_drag_preview_tiles() -> void:
	for coord in drag_preview_tiles.keys():
		if is_in_bounds(coord):
			var rect := Rect2(coord.x * TILE_SIZE, coord.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, Color(0.72, 0.92, 0.72, 0.22), true)
			draw_rect(rect, Color(0.88, 1.0, 0.74, 0.82), false, 2.0)

func _draw_placement_preview_tiles() -> void:
	var fill_color := Color(0.42, 0.86, 0.62, 0.24) if placement_preview_valid else Color(0.95, 0.22, 0.18, 0.18)
	var line_color := Color(0.66, 1.0, 0.70, 0.88) if placement_preview_valid else Color(1.0, 0.25, 0.18, 0.82)
	for coord in placement_preview_tiles.keys():
		if is_in_bounds(coord):
			var rect := Rect2(coord.x * TILE_SIZE, coord.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, fill_color, true)
			draw_rect(rect, line_color, false, 2.0)

func _tilemap_covers_base(coord: Vector2i) -> bool:
	if overlay_mode != "normal":
		return false
	var tile: DungeonTileData = get_tile(coord)
	return tile.is_walkable() or _is_wall_terrain_cell(coord)

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
	if tile.kind == DungeonTileScript.Kind.WALL:
		var solid_wall_texture := _wall_texture(coord)
		if solid_wall_texture != null:
			draw_texture_rect(solid_wall_texture, rect, false, _wall_tint(coord, true))
			_draw_wall_overlays(coord, rect, true)
		elif dungeon_wall_tileset != null:
			draw_texture_rect_region(dungeon_wall_tileset, rect, OUTER_WALL_REGION, Color(0.82, 0.78, 0.72, 0.95))
	elif tile.kind == DungeonTileScript.Kind.STONE:
		var stone_texture := _wall_texture(coord)
		if stone_texture != null:
			draw_texture_rect(stone_texture, rect, false, _wall_tint(coord, false))
			_draw_wall_overlays(coord, rect, false)
	elif tile.is_walkable():
		var floor_texture := _floor_texture(coord)
		if floor_texture != null:
			draw_texture_rect(floor_texture, rect, false, Color(0.88, 0.86, 0.82, 0.96))
		elif dungeon_floor_tileset != null:
			draw_texture_rect_region(dungeon_floor_tileset, rect, _floor_region(coord), Color(0.86, 0.84, 0.82, 0.96))

func _floor_region(coord: Vector2i) -> Rect2:
	return FLOOR_REGIONS[abs((coord.x * 19 + coord.y * 31) % FLOOR_REGIONS.size())]

func _stone_region(coord: Vector2i) -> Rect2:
	return STONE_REGIONS[abs((coord.x * 23 + coord.y * 13) % STONE_REGIONS.size())]

func _floor_texture(coord: Vector2i) -> Texture2D:
	if dungeon_floor_textures.is_empty():
		return null
	var hash: int = abs(coord.x * 19 + coord.y * 31)
	var roll: int = hash % 20
	var index: int = roll % 3
	if roll >= 15:
		index = 3 + (hash % 5)
	return dungeon_floor_textures[index]

func _wall_texture(coord: Vector2i) -> Texture2D:
	var sprite_name := _wall_sprite_name_for_coord(coord)
	if sprite_name == "" or not dungeon_wall_textures.has(sprite_name):
		return null
	return dungeon_wall_textures[sprite_name]

func _draw_wall_overlays(coord: Vector2i, rect: Rect2, solid_border: bool) -> void:
	for sprite_name in _wall_overlay_sprite_names_for_coord(coord):
		if dungeon_wall_textures.has(sprite_name) and dungeon_wall_textures[sprite_name] != null:
			draw_texture_rect(dungeon_wall_textures[sprite_name], rect, false, _wall_tint(coord, solid_border))

func _wall_overlay_sprite_names_for_coord(coord: Vector2i) -> Array[String]:
	if not is_in_bounds(coord):
		return []
	var tile: DungeonTileData = get_tile(coord)
	if tile.is_walkable():
		return []
	var overlays: Array[String] = []
	var open_above := _is_layout_floor(coord + Vector2i.UP)
	if open_above:
		var floor_above_left := _is_layout_floor(coord + Vector2i.UP + Vector2i.LEFT)
		var floor_above_right := _is_layout_floor(coord + Vector2i.UP + Vector2i.RIGHT)
		overlays.append(_horizontal_wall_sprite(floor_above_left, floor_above_right, "wall_top_left", "wall_top_mid", "wall_top_right"))
	return overlays

func _wall_sprite_name_for_coord(coord: Vector2i) -> String:
	if not is_in_bounds(coord):
		return ""
	var tile: DungeonTileData = get_tile(coord)
	if tile.is_walkable():
		return ""
	var open_above := _is_layout_floor(coord + Vector2i.UP)
	var open_below := _is_layout_floor(coord + Vector2i.DOWN)
	var open_left := _is_layout_floor(coord + Vector2i.LEFT)
	var open_right := _is_layout_floor(coord + Vector2i.RIGHT)
	var floor_above_left := _is_layout_floor(coord + Vector2i.UP + Vector2i.LEFT)
	var floor_above_right := _is_layout_floor(coord + Vector2i.UP + Vector2i.RIGHT)
	var floor_below_left := _is_layout_floor(coord + Vector2i.DOWN + Vector2i.LEFT)
	var floor_below_right := _is_layout_floor(coord + Vector2i.DOWN + Vector2i.RIGHT)
	var floor_two_below := _is_layout_floor(coord + Vector2i.DOWN * 2)
	var floor_two_below_left := _is_layout_floor(coord + Vector2i.DOWN * 2 + Vector2i.LEFT)
	var floor_two_below_right := _is_layout_floor(coord + Vector2i.DOWN * 2 + Vector2i.RIGHT)
	if floor_two_below and not open_below:
		return _horizontal_wall_sprite(floor_two_below_left, floor_two_below_right, "wall_top_left", "wall_top_mid", "wall_top_right")
	if floor_above_right and not floor_above_left and not open_above and not open_below and not open_left and not open_right:
		return "wall_edge_bottom_left"
	if floor_above_left and not floor_above_right and not open_above and not open_below and not open_left and not open_right:
		return "wall_edge_bottom_right"
	if floor_below_right and not floor_below_left and not open_above and not open_below and not open_left and not open_right:
		return "wall_edge_mid_right"
	if floor_below_left and not floor_below_right and not open_above and not open_below and not open_left and not open_right:
		return "wall_edge_mid_left"
	if not open_above and not open_below and not open_left and not open_right:
		return ""
	if open_below:
		return _horizontal_wall_sprite(floor_below_left, floor_below_right, "wall_left", "wall_mid", "wall_right")
	if open_above:
		return _horizontal_wall_sprite(floor_above_left, floor_above_right, "wall_left", "wall_mid", "wall_right")
	if open_right:
		var floor_right_up := _is_layout_floor(coord + Vector2i.RIGHT + Vector2i.UP)
		var floor_right_down := _is_layout_floor(coord + Vector2i.RIGHT + Vector2i.DOWN)
		return _vertical_wall_sprite(floor_right_up, floor_right_down, "wall_outer_top_left", "wall_outer_mid_left", "wall_outer_front_left")
	if open_left:
		var floor_left_up := _is_layout_floor(coord + Vector2i.LEFT + Vector2i.UP)
		var floor_left_down := _is_layout_floor(coord + Vector2i.LEFT + Vector2i.DOWN)
		return _vertical_wall_sprite(floor_left_up, floor_left_down, "wall_outer_top_right", "wall_outer_mid_right", "wall_outer_front_right")
	return "wall_mid"

func _horizontal_wall_sprite(floor_left: bool, floor_right: bool, left_sprite: String, mid_sprite: String, right_sprite: String) -> String:
	if not floor_left and floor_right:
		return left_sprite
	if floor_left and not floor_right:
		return right_sprite
	return mid_sprite

func _vertical_wall_sprite(floor_up: bool, floor_down: bool, top_sprite: String, mid_sprite: String, bottom_sprite: String) -> String:
	if not floor_up and floor_down:
		return top_sprite
	if floor_up and not floor_down:
		return bottom_sprite
	return mid_sprite

func _is_layout_floor(coord: Vector2i) -> bool:
	if not is_in_bounds(coord):
		return false
	var tile: DungeonTileData = get_tile(coord)
	return tile.is_walkable()

func _wall_tint(coord: Vector2i, solid_border: bool) -> Color:
	var hash: int = abs(coord.x * 47 + coord.y * 17)
	var shade := 0.92 + float(hash % 7) * 0.018
	var base := Color(0.58, 0.48, 0.38, 0.78)
	if solid_border:
		base = Color(0.68, 0.60, 0.50, 0.92)
	return Color(base.r * shade, base.g * shade, base.b * shade, base.a)

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
	if tile.poison_cloud_ticks > 0:
		draw_circle(center, 13.0 + sin(shimmer_time * 5.0 + coord.x) * 1.4, Color(0.36, 0.95, 0.22, 0.20))
	if tile.magic_field_ticks > 0:
		draw_circle(center, 12.0, Color(0.70, 0.28, 1.0, 0.22))
		draw_circle(center + Vector2(sin(shimmer_time * 4.0 + coord.x) * 5.0, cos(shimmer_time * 3.0 + coord.y) * 5.0), 2.2, Color(0.92, 0.65, 1.0, 0.55))
	if tile.secret_tunnel:
		draw_circle(center, 6.5, Color(0.12, 0.06, 0.02, 0.72))
		draw_circle(center, 3.0 + sin(shimmer_time * 4.0) * 0.8, Color(0.56, 0.38, 0.20, 0.42))
	_draw_structure(tile, center)

func _draw_structure(tile: DungeonTileData, center: Vector2) -> void:
	match tile.structure:
		"monster_den":
			draw_rect(Rect2(center - Vector2(13, 13), Vector2(26, 26)), Color(0.18, 0.09, 0.20, 0.92), true)
			draw_rect(Rect2(center - Vector2(10, 10), Vector2(20, 20)), Color(0.54, 0.28, 0.72, 0.75), false, 1.4)
			if tile.den_anchor:
				draw_circle(center, 4.0 + sin(shimmer_time * 3.0) * 1.0, Color(0.72, 0.96, 0.42, 0.85))
		"heart":
			_draw_heart_structure(center)
			if tile.heart_hp < 120:
				var bar_rect := Rect2(center + Vector2(-14, -22), Vector2(28, 4))
				var fill_width := 28.0 * clampf(float(tile.heart_hp) / 120.0, 0.0, 1.0)
				draw_rect(bar_rect, Color(0.08, 0.0, 0.0, 0.85), true)
				draw_rect(Rect2(bar_rect.position, Vector2(fill_width, 4)), Color(1.0, 0.12, 0.18, 0.95), true)
				draw_rect(bar_rect, Color(1.0, 0.75, 0.75, 0.65), false, 1.0)
		"treasure":
			if dungeon_treasure_texture != null:
				draw_texture_rect(dungeon_treasure_texture, Rect2(center - Vector2(12, 12), Vector2(24, 24)), false)
		"trap":
			if dungeon_spike_textures.size() == 4:
				var frame := int(floor(shimmer_time * 5.0)) % dungeon_spike_textures.size()
				draw_texture_rect(dungeon_spike_textures[frame], Rect2(center - Vector2(14, 14), Vector2(28, 28)), false)
			else:
				for i in range(3):
					var x := -7.0 + i * 7.0
					draw_polygon(PackedVector2Array([center + Vector2(x, 6), center + Vector2(x + 3, -6), center + Vector2(x + 6, 6)]), PackedColorArray([Color(0.78, 0.78, 0.72), Color(0.78, 0.78, 0.72), Color(0.78, 0.78, 0.72)]))
		"poison_trap":
			draw_rect(Rect2(center - Vector2(11, 11), Vector2(22, 22)), Color(0.12, 0.28, 0.08, 0.42), true)
			for i in range(3):
				var angle := shimmer_time * 1.8 + float(i) * TAU / 3.0
				draw_circle(center + Vector2(cos(angle), sin(angle)) * 6.5, 2.5, Color(0.38, 0.95, 0.22, 0.72))
		"door":
			if dungeon_door_texture != null:
				draw_texture_rect(dungeon_door_texture, Rect2(center - Vector2(16, 19), Vector2(32, 32)), false)
			if tile.locked_door:
				draw_rect(Rect2(center - Vector2(9, 12), Vector2(18, 22)), Color(0.96, 0.78, 0.34, 0.32), false, 2.0)
				draw_circle(center + Vector2(0, -2), 3.0, Color(0.95, 0.78, 0.32, 0.9))

func _draw_heart_structure(center: Vector2) -> void:
	var pulse := (sin(shimmer_time * 2.8) + 1.0) * 0.5
	var outer_radius := 17.0 + pulse * 3.0
	var inner_radius := 10.0 + pulse * 1.8
	draw_circle(center, outer_radius, Color(0.95, 0.08, 0.20, 0.16 + pulse * 0.08))
	draw_circle(center, inner_radius, Color(1.0, 0.22, 0.36, 0.18))
	for i in range(3):
		var angle := shimmer_time * 1.35 + float(i) * TAU / 3.0
		var mote_pos := center + Vector2(cos(angle), sin(angle)) * (16.0 + pulse * 2.0)
		draw_circle(mote_pos, 2.0, Color(1.0, 0.42, 0.58, 0.48))
	if action_icon_atlas != null:
		var src_rect := _heart_icon_region()
		draw_texture_rect_region(action_icon_atlas, Rect2(center - Vector2(16, 16), Vector2(32, 32)), src_rect)
	else:
		draw_circle(center, 10.0, Color(0.92, 0.08, 0.22, 0.95))
		draw_circle(center, 5.0 + sin(shimmer_time * 4.0) * 1.2, Color(1.0, 0.36, 0.44, 0.95))

func _heart_icon_region() -> Rect2:
	return Rect2(
		Vector2((HEART_ICON_INDEX % 5) * ACTION_ICON_SIZE, int(HEART_ICON_INDEX / 5) * ACTION_ICON_SIZE),
		Vector2(ACTION_ICON_SIZE, ACTION_ICON_SIZE)
	)
