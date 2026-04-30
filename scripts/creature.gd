class_name DungeonCreature
extends Node2D

signal clicked(creature: DungeonCreature)
signal log_event(message: String)

const TILE_SIZE := DungeonGrid.TILE_SIZE

var species: String = "carrion_mite"
var tile_pos: Vector2i = Vector2i.ZERO
var hp: float = 8.0
var hunger: float = 25.0
var age: int = 0
var traits: Array[String] = []
var mutation_pressure: Dictionary = {}
var move_cooldown: int = 0
var anim_time: float = 0.0

var species_data := {
	"spore_root": {"hp": 12.0, "color": Color(0.35, 1.0, 0.43), "traits": ["producer", "stationary", "fungal"]},
	"carrion_mite": {"hp": 7.0, "color": Color(0.78, 0.62, 0.42), "traits": ["scavenger", "wanders"]},
	"bloat_mite": {"hp": 15.0, "color": Color(0.36, 0.85, 0.56), "traits": ["swollen", "damp-adapted"]},
	"ember_mite": {"hp": 9.0, "color": Color(1.0, 0.42, 0.10), "traits": ["heated", "ash-biter"]},
	"gloom_slug": {"hp": 10.0, "color": Color(0.18, 0.72, 0.46), "traits": ["herbivore", "damp-dark"]},
	"oracle_slug": {"hp": 11.0, "color": Color(0.78, 0.38, 1.0), "traits": ["herbivore", "omens", "magic-sense"]},
	"needle_bat": {"hp": 8.0, "color": Color(0.68, 0.68, 0.78), "traits": ["predator", "hunter"]},
	"goblin": {"hp": 10.0, "color": Color(0.54, 0.82, 0.38), "traits": ["den-born", "guard"]},
	"hex_goblin": {"hp": 11.0, "color": Color(0.70, 0.36, 1.0), "traits": ["den-born", "hexed"]},
	"ember_imp": {"hp": 9.0, "color": Color(1.0, 0.34, 0.08), "traits": ["den-born", "heated"]},
	"bog_mite": {"hp": 13.0, "color": Color(0.32, 0.78, 0.48), "traits": ["den-born", "damp"]},
	"cinder_witch": {"hp": 12.0, "color": Color(1.0, 0.30, 0.78), "traits": ["den-born", "magic-heat"]},
	"heart_larva": {"hp": 85.0, "color": Color(0.95, 0.10, 0.28), "traits": ["boss", "larva", "heartbound"]},
	"heart_juvenile": {"hp": 160.0, "color": Color(1.0, 0.20, 0.34), "traits": ["boss", "juvenile", "heartbound"]},
}

func initialize(new_species: String, new_tile_pos: Vector2i) -> void:
	species = new_species
	tile_pos = new_tile_pos
	var data: Dictionary = species_data.get(species, species_data["carrion_mite"])
	hp = float(data["hp"])
	traits.assign(data["traits"])
	mutation_pressure.clear()
	_update_world_position()
	queue_redraw()

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func _update_world_position() -> void:
	position = Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5, tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func simulate_step(grid: DungeonGrid, all_creatures: Array, adventurers: Array = [], resources: DungeonResources = null) -> void:
	age += 1
	hunger = clampf(hunger + 1.1, 0.0, 100.0)
	var tile: DungeonTileData = grid.get_tile(tile_pos)
	if species.begins_with("heart_"):
		_boss_step(grid, adventurers)
		return
	var threat = _nearest_adventurer(adventurers, 4 if species == "spore_root" else 5)
	if threat != null:
		_defend_against(grid, threat, resources)
		if species == "spore_root":
			tile.spore_seed = true
			tile.biomass = min(tile.biomass + 0.55, 100.0)
		return
	if species == "spore_root":
		tile.spore_seed = true
		tile.biomass = min(tile.biomass + 0.55, 100.0)
		return
	if species == "needle_bat":
		_predator_step(grid, all_creatures, resources)
	else:
		_forager_step(grid, resources)
	_update_mutation(tile)
	if hunger >= 100.0:
		hp -= 0.35
	if hp <= 0.0:
		tile.corpse_mass += 8.0
		resources.add("bone", 1)
		queue_free()

func _forager_step(grid: DungeonGrid, resources: DungeonResources) -> void:
	move_cooldown -= 1
	var tile: DungeonTileData = grid.get_tile(tile_pos)
	if tile.biomass > 3.0 and hunger > 30.0:
		var eaten: float = min(tile.biomass, 4.5)
		tile.biomass -= eaten
		hunger = max(hunger - eaten * 4.5, 0.0)
		resources.add("biomass", 1 if eaten > 3.0 and species.begins_with("carrion") else 0)
	if tile.corpse_mass > 1.0 and species.contains("mite"):
		var corpse_eaten: float = min(tile.corpse_mass, 5.0)
		tile.corpse_mass -= corpse_eaten
		hunger = max(hunger - corpse_eaten * 6.0, 0.0)
	if move_cooldown > 0:
		return
	move_cooldown = 2 if species.contains("slug") else 1
	var next := tile_pos
	if species.contains("slug"):
		next = grid.get_best_neighbor(tile_pos, func(coord: Vector2i) -> float:
			var candidate = grid.get_tile(coord)
			return candidate.moisture * 0.45 + candidate.darkness * 0.40 + candidate.biomass * 0.45 - candidate.temperature * 0.18
		)
	else:
		next = grid.get_best_neighbor(tile_pos, func(coord: Vector2i) -> float:
			var candidate = grid.get_tile(coord)
			return candidate.corpse_mass * 1.4 + candidate.biomass * 0.35 + randf_range(-8.0, 8.0)
		)
	tile_pos = next
	_update_world_position()

func _predator_step(grid: DungeonGrid, all_creatures: Array, resources: DungeonResources) -> void:
	var prey = _nearest_prey(all_creatures, 8)
	if prey == null:
		_wander(grid)
		return
	if tile_pos.distance_to(prey.tile_pos) <= 1.1:
		prey.hp -= 3.0
		hunger = max(hunger - 20.0, 0.0)
		resources.add("fear", 1)
	else:
		tile_pos = _step_toward(grid, prey.tile_pos)
		_update_world_position()

func _boss_step(grid: DungeonGrid, adventurers: Array) -> void:
	var heart := grid.find_structure("heart")
	if heart == Vector2i(-1, -1):
		return
	if tile_pos.distance_to(heart) > 2.0:
		tile_pos = _step_toward(grid, heart)
		_update_world_position()
		return
	for adventurer in adventurers:
		if not is_instance_valid(adventurer):
			continue
		if tile_pos.distance_to(adventurer.tile_pos) <= 1.1 or adventurer.tile_pos == heart:
			adventurer.hp -= 8.0 if species == "heart_larva" else 14.0
			log_event.emit("%s pulses against a crawler near the Heart." % species.replace("_", " ").capitalize())
			break
	if species == "heart_larva" and age >= 180:
		_grow_boss(grid, heart)

func _grow_boss(grid: DungeonGrid, heart: Vector2i) -> void:
	_mutate_to("heart_juvenile")
	var totals := {"magic": 0.0, "temperature": 0.0, "moisture": 0.0, "biomass": 0.0}
	var count := 0.0
	for x in range(heart.x - 2, heart.x + 3):
		for y in range(heart.y - 2, heart.y + 3):
			var coord := Vector2i(x, y)
			if not grid.is_in_bounds(coord):
				continue
			var tile: DungeonTileData = grid.get_tile(coord)
			totals["magic"] += tile.magic
			totals["temperature"] += tile.temperature
			totals["moisture"] += tile.moisture
			totals["biomass"] += tile.biomass
			count += 1.0
	if count <= 0.0:
		return
	var dominant_trait := "stone-fed"
	if totals["magic"] / count > 60.0:
		dominant_trait = "arcane-fed"
	if totals["temperature"] / count > 70.0:
		dominant_trait = "ember-fed"
	if min(totals["moisture"] / count, totals["biomass"] / count) > 50.0:
		dominant_trait = "fungal-fed"
	if not traits.has(dominant_trait):
		traits.append(dominant_trait)
	log_event.emit("The Heart larva grows into a %s juvenile." % dominant_trait)

func _nearest_adventurer(adventurers: Array, radius: int):
	var best = null
	var best_distance := 9999.0
	for adventurer in adventurers:
		if not is_instance_valid(adventurer):
			continue
		var distance := tile_pos.distance_to(adventurer.tile_pos)
		if distance < best_distance and distance <= radius:
			best = adventurer
			best_distance = distance
	return best

func _defend_against(grid: DungeonGrid, adventurer, resources: DungeonResources) -> void:
	var distance := tile_pos.distance_to(adventurer.tile_pos)
	if species == "spore_root" and distance <= 4.0:
		adventurer.hp -= 1.4
		log_event.emit("Spore root lashes a crawler with choking spores.")
	elif distance <= 1.1:
		adventurer.hp -= 2.2
		hunger = max(hunger - 8.0, 0.0)
		log_event.emit("%s bites a crawler." % species.replace("_", " "))
	else:
		tile_pos = _step_toward(grid, adventurer.tile_pos)
		_update_world_position()
	if adventurer.hp <= 0.0:
		var tile: DungeonTileData = grid.get_tile(adventurer.tile_pos)
		tile.corpse_mass += 12.0
		if resources != null:
			resources.add("fear", 2)
			resources.add("biomass", 3)
			resources.add("essence", 1)
			resources.add("magic", 1)
		log_event.emit("%s killed a crawler." % species.replace("_", " ").capitalize())
		adventurer.queue_free()

func _nearest_prey(all_creatures: Array, radius: int):
	var best = null
	var best_distance := 9999.0
	for other in all_creatures:
		if other == self or not is_instance_valid(other):
			continue
		if other.species in ["carrion_mite", "bloat_mite", "ember_mite", "gloom_slug", "oracle_slug"]:
			var distance := tile_pos.distance_to(other.tile_pos)
			if distance < best_distance and distance <= radius:
				best = other
				best_distance = distance
	return best

func _wander(grid: DungeonGrid) -> void:
	var choices := grid.walkable_neighbors(tile_pos)
	if choices.size() > 0:
		tile_pos = choices.pick_random()
		_update_world_position()

func _step_toward(grid: DungeonGrid, target: Vector2i) -> Vector2i:
	var path := grid.find_path(tile_pos, target)
	if path.size() >= 2:
		return path[1]
	return grid.get_best_neighbor(tile_pos, func(coord: Vector2i) -> float:
		return -coord.distance_to(target)
	)

func _update_mutation(tile: DungeonTileData) -> void:
	if species == "carrion_mite":
		_accumulate_pressure("bloat_mite", 2.4 if tile.moisture > 68.0 and tile.biomass > 45.0 else -0.8)
		_accumulate_pressure("ember_mite", 2.9 if tile.temperature > 74.0 else -0.7)
	elif species == "gloom_slug":
		_accumulate_pressure("oracle_slug", 2.6 if tile.magic > 66.0 and tile.darkness > 76.0 else -0.6)
	if mutation_pressure.get("bloat_mite", 0.0) >= 100.0:
		_mutate_to("bloat_mite")
	elif mutation_pressure.get("ember_mite", 0.0) >= 100.0:
		_mutate_to("ember_mite")
	elif mutation_pressure.get("oracle_slug", 0.0) >= 100.0:
		_mutate_to("oracle_slug")

func _accumulate_pressure(target_species: String, amount: float) -> void:
	mutation_pressure[target_species] = clampf(float(mutation_pressure.get(target_species, 0.0)) + amount, 0.0, 100.0)

func _mutate_to(target_species: String) -> void:
	species = target_species
	var data: Dictionary = species_data[target_species]
	hp = max(hp, float(data["hp"]) * 0.8)
	traits.assign(data["traits"])
	mutation_pressure.clear()
	queue_redraw()

func mutation_summary() -> String:
	if mutation_pressure.is_empty():
		return "none yet"
	var parts: Array[String] = []
	for key in mutation_pressure.keys():
		parts.append("%s %.0f%%" % [key, mutation_pressure[key]])
	return ", ".join(parts)

func _draw() -> void:
	var data: Dictionary = species_data.get(species, species_data["carrion_mite"])
	var color: Color = data["color"]
	var bob := sin(anim_time * 5.0 + tile_pos.x) * 1.8
	var radius := 7.0
	if species == "spore_root":
		draw_circle(Vector2(0, bob), 7.0, color.darkened(0.25))
		draw_circle(Vector2(-5, -4 + bob), 4.0, Color(0.65, 1.0, 0.52, 0.9))
		draw_circle(Vector2(5, -3 + bob), 3.2, Color(0.48, 1.0, 0.74, 0.75))
	elif species.contains("slug"):
		_draw_ellipse(Rect2(-10, -5 + bob, 20, 11), color)
		draw_circle(Vector2(7, -3 + bob), 3.2, color.lightened(0.25))
		if species == "oracle_slug":
			draw_circle(Vector2(3, -3 + bob), 2.2, Color(0.95, 0.78, 1.0))
	elif species.contains("mite"):
		radius = 8.0 if species == "bloat_mite" else 6.5
		draw_circle(Vector2(0, bob), radius, color)
		for i in range(4):
			var side := -1.0 if i < 2 else 1.0
			var y := -4.0 + float(i % 2) * 8.0 + bob
			draw_line(Vector2(side * 3.0, y), Vector2(side * 10.0, y + sin(anim_time * 8.0 + i) * 2.0), color.lightened(0.25), 1.5)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -10 + bob), Vector2(13, 4 + bob), Vector2(0, 0 + bob), Vector2(-13, 4 + bob)]), color)
		draw_line(Vector2(-5, 1 + bob), Vector2(5, 1 + bob), Color(0.95, 0.95, 1.0, 0.8), 1.2)

func _draw_ellipse(rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var center := rect.get_center()
	var radius := rect.size * 0.5
	for i in range(18):
		var angle := TAU * float(i) / 18.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		colors.append(color)
	draw_polygon(points, colors)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
