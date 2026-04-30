class_name DungeonAdventurer
extends Node2D

signal log_event(message: String)

const TILE_SIZE := DungeonGrid.TILE_SIZE

var role: String = "looter"
var tile_pos: Vector2i = Vector2i.ZERO
var hp: float = 18.0
var nerve: float = 100.0
var anim_time: float = 0.0
var target: Vector2i = Vector2i.ZERO
var debug_path: Array[Vector2i] = []
var is_attacking: bool = false
var door_delay: int = 0
var explored_doors: Dictionary = {}
var previous_tile_pos: Vector2i = Vector2i(-1, -1)
var committed_door_target: Vector2i = Vector2i(-1, -1)

var role_data := {
	"looter": {"color": Color(0.95, 0.80, 0.38), "traits": ["seeks treasure", "steals essence"]},
	"torchbearer": {"color": Color(1.0, 0.48, 0.12), "traits": ["burns fungus", "reduces darkness"]},
	"hunter": {"color": Color(0.78, 0.84, 0.94), "traits": ["attacks creatures", "keeps nerve"]},
}

func initialize(new_role: String, start_tile: Vector2i, target_tile: Vector2i) -> void:
	role = new_role
	tile_pos = start_tile
	target = target_tile
	_update_world_position()

func share_exploration_memory(memory: Dictionary) -> void:
	explored_doors = memory

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func simulate_step(grid: DungeonGrid, creatures: Array, resources: DungeonResources) -> void:
	is_attacking = false
	var tile: DungeonTileData = grid.get_tile(tile_pos)
	if tile.structure == "trap":
		hp -= tile.trap_damage
		grid.clear_structure(tile_pos)
		log_event.emit("%s triggered a spike trap." % role.capitalize())
		if hp <= 0.0:
			_die(tile, resources)
			return
	if tile.structure == "door" and door_delay <= 0:
		explored_doors[tile_pos] = true
		if committed_door_target == tile_pos:
			committed_door_target = Vector2i(-1, -1)
		door_delay = 1
		is_attacking = true
		target = _choose_target(grid, creatures)
		debug_path = grid.find_path(tile_pos, target)
		return
	if tile.structure == "door":
		explored_doors[tile_pos] = true
		door_delay -= 1
	if tile.structure == "heart":
		is_attacking = true
		tile.heart_hp -= 4
		log_event.emit("%s tears at the dungeon Heart. Heart HP: %s." % [role.capitalize(), tile.heart_hp])
		debug_path = []
		return
	nerve -= _nearby_fear(creatures) * 0.45
	if tile.structure == "treasure":
		resources.spend("essence", 1)
		grid.clear_structure(tile_pos)
		log_event.emit("%s looted treasure and stole 1 essence." % role.capitalize())
	if tile.magic_source or tile.heat_source or tile.moisture_source:
		var disrupted: Array[String] = []
		if tile.magic_source:
			tile.magic_source = false
			tile.magic = max(tile.magic - 35.0, 0.0)
			disrupted.append("magic seep")
		if tile.heat_source:
			tile.heat_source = false
			tile.temperature = max(tile.temperature - 28.0, 0.0)
			disrupted.append("heat vent")
		if tile.moisture_source:
			tile.moisture_source = false
			tile.moisture = max(tile.moisture - 28.0, 0.0)
			disrupted.append("moisture source")
		log_event.emit("%s disrupted a %s." % [role.capitalize(), " and ".join(disrupted)])
	target = _choose_target(grid, creatures)
	debug_path = grid.find_path(tile_pos, target)
	var target_creature = _creature_at_coord(creatures, target)
	if target_creature != null and tile_pos.distance_to(target_creature.tile_pos) <= 1.1:
		_attack_creature(target_creature, grid)
		debug_path = []
		return
	if role == "torchbearer":
		tile.darkness = max(tile.darkness - 7.0, 0.0)
		tile.temperature = min(tile.temperature + 3.0, 100.0)
		tile.biomass = max(tile.biomass - 3.5, 0.0)
	elif role == "hunter":
		var hunter_target = _nearest_creature(creatures, 5)
		if hunter_target != null and tile_pos.distance_to(hunter_target.tile_pos) <= 1.1:
			_attack_creature(hunter_target, grid)
			return
		elif hunter_target != null:
			target = hunter_target.tile_pos
			debug_path = grid.find_path(tile_pos, target)
			tile_pos = _step_toward(grid, target)
			_update_world_position()
			return
	if nerve <= 0.0 or hp <= 0.0:
		_die(tile, resources)
		return
	var next_tile := _step_toward(grid, target)
	previous_tile_pos = tile_pos
	tile_pos = next_tile
	_update_world_position()

func _choose_target(grid: DungeonGrid, creatures: Array) -> Vector2i:
	if role == "hunter":
		var target_creature = _nearest_creature(creatures, 8)
		if target_creature != null:
			return target_creature.tile_pos
	var visible_creature = _nearest_visible_creature(grid, creatures, 5)
	if visible_creature != null:
		return visible_creature.tile_pos
	var visible_source := _nearest_visible_source(grid)
	if visible_source != Vector2i(-1, -1):
		return visible_source
	var treasures := grid.visible_structures(tile_pos, "treasure")
	var nearest_treasure := _nearest_reachable(grid, treasures)
	if nearest_treasure != Vector2i(-1, -1):
		return nearest_treasure
	var visible_hearts := grid.visible_structures(tile_pos, "heart")
	if not visible_hearts.is_empty():
		committed_door_target = Vector2i(-1, -1)
		var heart := _nearest_reachable(grid, visible_hearts)
		if heart != Vector2i(-1, -1):
			return heart
	if _is_committed_door_valid(grid):
		return committed_door_target
	var doors := _unexplored_visible_doors(grid)
	if not doors.is_empty():
		committed_door_target = doors.pick_random()
		return committed_door_target
	committed_door_target = Vector2i(-1, -1)
	var global_heart := grid.find_structure("heart")
	if global_heart != Vector2i(-1, -1):
		return global_heart
	return target

func _is_committed_door_valid(grid: DungeonGrid) -> bool:
	if committed_door_target == Vector2i(-1, -1):
		return false
	if explored_doors.has(committed_door_target):
		return false
	if not grid.is_in_bounds(committed_door_target):
		return false
	if grid.get_tile(committed_door_target).structure != "door":
		return false
	return grid.shortest_path_length(tile_pos, committed_door_target) >= 0

func _unexplored_visible_doors(grid: DungeonGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for door in grid.visible_doors(tile_pos):
		if not explored_doors.has(door):
			result.append(door)
	return result

func _nearest_visible_source(grid: DungeonGrid) -> Vector2i:
	var visible: Dictionary = grid.visible_from(tile_pos)
	var best := Vector2i(-1, -1)
	var best_distance := 999999
	for coord in visible["tiles"]:
		var tile: DungeonTileData = grid.get_tile(coord)
		if tile.magic_source or tile.heat_source or tile.moisture_source:
			var distance := grid.shortest_path_length(tile_pos, coord)
			if distance >= 0 and distance < best_distance:
				best = coord
				best_distance = distance
	return best

func _nearest_visible_creature(grid: DungeonGrid, creatures: Array, radius: int):
	var visible: Dictionary = grid.visible_from(tile_pos)
	var visible_tiles: Dictionary = {}
	for coord in visible["tiles"]:
		visible_tiles[coord] = true
	var best = null
	var best_distance := 9999.0
	for creature in creatures:
		if not is_instance_valid(creature) or not visible_tiles.has(creature.tile_pos):
			continue
		var distance := tile_pos.distance_to(creature.tile_pos)
		if distance <= radius and distance < best_distance:
			best = creature
			best_distance = distance
	return best

func _nearest_reachable(grid: DungeonGrid, candidates: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 999999
	for candidate in candidates:
		var distance := grid.shortest_path_length(tile_pos, candidate)
		if distance >= 0 and distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func _die(tile: DungeonTileData, resources: DungeonResources) -> void:
	resources.add("fear", 2)
	resources.add("biomass", 3)
	resources.add("essence", 1)
	resources.add("magic", 1)
	tile.corpse_mass += 15.0
	log_event.emit("A %s dies in the dungeon." % role)
	queue_free()

func _nearby_fear(creatures: Array) -> float:
	var fear := 0.0
	for creature in creatures:
		if is_instance_valid(creature) and tile_pos.distance_to(creature.tile_pos) <= 4.0:
			fear += 1.0
			if creature.species == "needle_bat":
				fear += 2.0
	return fear

func _nearest_creature(creatures: Array, radius: int):
	var best = null
	var best_distance := 9999.0
	for creature in creatures:
		if not is_instance_valid(creature):
			continue
		var distance := tile_pos.distance_to(creature.tile_pos)
		if distance < best_distance and distance <= radius:
				best = creature
				best_distance = distance
	return best

func _creature_at_coord(creatures: Array, coord: Vector2i):
	for creature in creatures:
		if is_instance_valid(creature) and creature.tile_pos == coord:
			return creature
	return null

func _attack_creature(creature, grid: DungeonGrid) -> void:
	is_attacking = true
	var damage := 4.0 if role == "hunter" else 2.5
	creature.hp -= damage
	log_event.emit("%s attacks %s." % [role.capitalize(), creature.species.replace("_", " ")])
	if creature.hp <= 0.0:
		var corpse_tile: DungeonTileData = grid.get_tile(creature.tile_pos)
		corpse_tile.corpse_mass += 8.0
		log_event.emit("%s killed a dungeon %s." % [role.capitalize(), creature.species.replace("_", " ")])
		creature.queue_free()

func _step_toward(grid: DungeonGrid, destination: Vector2i) -> Vector2i:
	var current_tile: DungeonTileData = grid.get_tile(tile_pos)
	if current_tile.structure == "door":
		var exit := _door_exit_neighbor(grid)
		if exit != Vector2i(-1, -1):
			return exit
	var path := grid.find_path(tile_pos, destination)
	if path.size() >= 2:
		return path[1]
	return tile_pos

func _door_exit_neighbor(grid: DungeonGrid) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for neighbor in grid.walkable_neighbors(tile_pos):
		if neighbor != previous_tile_pos:
			candidates.append(neighbor)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var visible_hearts := grid.visible_structures(candidates[0], "heart")
	for candidate in candidates:
		if not grid.visible_structures(candidate, "heart").is_empty():
			return candidate
		if not grid.visible_structures(candidate, "treasure").is_empty():
			return candidate
	if not visible_hearts.is_empty():
		return candidates[0]
	return candidates.pick_random()

func _update_world_position() -> void:
	position = Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5, tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func _draw() -> void:
	var data: Dictionary = role_data.get(role, role_data["looter"])
	var color: Color = data["color"]
	if is_attacking:
		color = Color(1.0, 0.16, 0.10)
	var bob := sin(anim_time * 6.0) * 1.4
	_draw_debug_path()
	draw_circle(Vector2(0, -4 + bob), 4.5, color.lightened(0.18))
	draw_rect(Rect2(-5, 0 + bob, 10, 11), color, true)
	if role == "torchbearer":
		draw_line(Vector2(7, 2 + bob), Vector2(12, -8 + bob), Color(0.98, 0.76, 0.32), 2.0)
		draw_circle(Vector2(13, -10 + bob), 4.0, Color(1.0, 0.34, 0.08, 0.8))
	elif role == "hunter":
		draw_line(Vector2(-11, 7 + bob), Vector2(12, -6 + bob), Color(0.90, 0.94, 1.0), 1.8)
	else:
		draw_circle(Vector2(7, 7 + bob), 3.0, Color(1.0, 0.92, 0.48))

func _draw_debug_path() -> void:
	if debug_path.size() < 2:
		return
	var previous := _tile_to_local(debug_path[0])
	for i in range(1, min(debug_path.size(), 26)):
		var next := _tile_to_local(debug_path[i])
		draw_line(previous, next, Color(0.28, 0.82, 1.0, 0.42), 1.4)
		previous = next

func _tile_to_local(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * TILE_SIZE + TILE_SIZE * 0.5, coord.y * TILE_SIZE + TILE_SIZE * 0.5) - position
