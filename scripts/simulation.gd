class_name DungeonSimulation
extends Node

signal log_event(message: String)

const DungeonTileScript = preload("res://scripts/tile_data.gd")

var grid: DungeonGrid
var resources: DungeonResources
var tick_count: int = 0

func configure(new_grid: DungeonGrid, new_resources: DungeonResources) -> void:
	grid = new_grid
	resources = new_resources

func step(creatures: Array, adventurers: Array) -> void:
	if grid == null:
		return
	tick_count += 1
	_diffuse_environment()
	_update_tile_growth()
	_collect_background_resources()
	for creature in creatures:
		if is_instance_valid(creature):
			creature.simulate_step(grid, creatures, adventurers, resources)
	for adventurer in adventurers:
		if is_instance_valid(adventurer):
			adventurer.simulate_step(grid, creatures, resources)
	grid.queue_redraw()

func _diffuse_environment() -> void:
	var magic_sources := _magic_sources()
	var next_temperature: Array = []
	var next_moisture: Array = []
	var next_magic: Array = []
	var next_darkness: Array = []
	for x in range(DungeonGrid.GRID_SIZE):
		next_temperature.append([])
		next_moisture.append([])
		next_magic.append([])
		next_darkness.append([])
		for y in range(DungeonGrid.GRID_SIZE):
			var coord := Vector2i(x, y)
			var tile: DungeonTileData = grid.get_tile(coord)
			var neighbor_average: Dictionary = _neighbor_averages(coord)
			var heat_rate := 0.12 if tile.is_walkable() else 0.035
			var moisture_rate := 0.045 if tile.is_walkable() else 0.012
			var magic_rate := randf_range(0.02, 0.10) if tile.is_walkable() else randf_range(0.005, 0.03)
			var darkness_rate := 0.035 if tile.is_walkable() else 0.01
			next_temperature[x].append(lerpf(tile.temperature, neighbor_average["temperature"], heat_rate))
			next_moisture[x].append(lerpf(tile.moisture, neighbor_average["moisture"], moisture_rate))
			next_magic[x].append(lerpf(tile.magic, neighbor_average["magic"] + randf_range(-3.0, 4.0), magic_rate))
			next_darkness[x].append(lerpf(tile.darkness, neighbor_average["darkness"], darkness_rate))
	for x in range(DungeonGrid.GRID_SIZE):
		for y in range(DungeonGrid.GRID_SIZE):
			var tile: DungeonTileData = grid.get_tile(Vector2i(x, y))
			tile.temperature = next_temperature[x][y]
			tile.moisture = next_moisture[x][y]
			tile.magic = next_magic[x][y]
			tile.darkness = next_darkness[x][y]
			if tile.heat_source:
				tile.temperature = lerpf(tile.temperature, 94.0, 0.45)
			if tile.moisture_source:
				tile.moisture = lerpf(tile.moisture, 94.0, 0.35)
			if tile.magic_source:
				tile.magic = clampf(tile.magic + randf_range(4.0, 10.0), 0.0, 100.0)
			else:
				_apply_magic_falloff(Vector2i(x, y), tile, magic_sources)
			if tile.kind == DungeonTileScript.Kind.ENTRANCE:
				tile.darkness = lerpf(tile.darkness, 48.0, 0.25)
			elif tile.is_walkable():
				tile.darkness = lerpf(tile.darkness, 92.0, 0.012)
			tile.clamp_values()

func _magic_sources() -> Array[Vector2i]:
	var sources: Array[Vector2i] = []
	for x in range(DungeonGrid.GRID_SIZE):
		for y in range(DungeonGrid.GRID_SIZE):
			var coord := Vector2i(x, y)
			if grid.get_tile(coord).magic_source:
				sources.append(coord)
	return sources

func _apply_magic_falloff(coord: Vector2i, tile: DungeonTileData, magic_sources: Array[Vector2i]) -> void:
	var cap := 10.0
	for source in magic_sources:
		var distance := coord.distance_to(source)
		if distance <= 6.0:
			var local_cap := lerpf(92.0, 18.0, distance / 6.0)
			cap = maxf(cap, local_cap)
	if tile.magic > cap:
		tile.magic = lerpf(tile.magic, cap, 0.45)

func _neighbor_averages(coord: Vector2i) -> Dictionary:
	var total_temperature := 0.0
	var total_moisture := 0.0
	var total_magic := 0.0
	var total_darkness := 0.0
	var count := 0.0
	for neighbor in grid.get_cardinal_neighbors(coord):
		if grid.is_in_bounds(neighbor):
			var tile: DungeonTileData = grid.get_tile(neighbor)
			total_temperature += tile.temperature
			total_moisture += tile.moisture
			total_magic += tile.magic
			total_darkness += tile.darkness
			count += 1.0
	if count <= 0.0:
		var own: DungeonTileData = grid.get_tile(coord)
		return {"temperature": own.temperature, "moisture": own.moisture, "magic": own.magic, "darkness": own.darkness}
	return {
		"temperature": total_temperature / count,
		"moisture": total_moisture / count,
		"magic": total_magic / count,
		"darkness": total_darkness / count,
	}

func _update_tile_growth() -> void:
	for x in range(DungeonGrid.GRID_SIZE):
		for y in range(DungeonGrid.GRID_SIZE):
			var tile: DungeonTileData = grid.get_tile(Vector2i(x, y))
			if not tile.is_walkable():
				continue
			var damp_dark: float = min(tile.moisture, tile.darkness)
			if damp_dark > 58.0:
				tile.biomass += (damp_dark - 55.0) * 0.009
			if tile.spore_seed:
				tile.biomass += 0.28
				tile.moisture = min(tile.moisture + 0.25, 100.0)
			if tile.temperature > 82.0:
				tile.biomass -= (tile.temperature - 78.0) * 0.035
			if tile.corpse_mass > 0.0:
				tile.biomass += min(tile.corpse_mass, 1.5) * 0.045
				tile.corpse_mass *= 0.985
			tile.clamp_values()

func _collect_background_resources() -> void:
	if resources == null:
		return
	if tick_count % 18 == 0:
		resources.add("essence", 1)
		log_event.emit("The dungeon slowly condenses 1 essence.")
	if tick_count % 24 != 0:
		return
	var total_biomass := 0.0
	var total_magic := 0.0
	for x in range(grid.start_center.x - 12, grid.start_center.x + 13):
		for y in range(grid.start_center.y - 12, grid.start_center.y + 13):
			var coord := Vector2i(x, y)
			if grid.is_in_bounds(coord):
				var tile: DungeonTileData = grid.get_tile(coord)
				total_biomass += tile.biomass
				total_magic += tile.magic
	resources.add("biomass", int(total_biomass / 900.0))
	resources.add("essence", int(total_magic / 1800.0))
