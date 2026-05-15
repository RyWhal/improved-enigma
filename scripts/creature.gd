class_name DungeonCreature
extends Node2D

signal clicked(creature: DungeonCreature)
signal log_event(message: String)

const TILE_SIZE := DungeonGrid.TILE_SIZE
const TILESET_ROOT := "res://assets/tilesets/0x72_DungeonTilesetII_v1.7"
const VISUAL_MOVE_SECONDS := 0.34
const BOSS_PATROL_RADIUS := 4.0
const BOSS_PATROL_STEP_INTERVAL := 3

var species: String = "carrion_mite"
var tile_pos: Vector2i = Vector2i.ZERO
var hp: float = 8.0
var max_hp: float = 8.0
var age: int = 0
var traits: Array[String] = []
var mutation_pressure: Dictionary = {}
var move_cooldown: int = 0
var anim_time: float = 0.0
var big_demon_frames: Array[Texture2D] = []
var goblin_run_frames: Array[Texture2D] = []
var skeleton_run_frames: Array[Texture2D] = []
var visual_start_position: Vector2 = Vector2.ZERO
var visual_target_position: Vector2 = Vector2.ZERO
var visual_move_elapsed: float = VISUAL_MOVE_SECONDS
var den_id: int = -1
var den_order: String = ""
var home_tile: Vector2i = Vector2i(-1, -1)
var command_target: Vector2i = Vector2i(-1, -1)
var attack_bonus: float = 0.0
var magic_field_bonus: float = 0.0
var magic_field_ticks: int = 0
var lifesteal_chance: float = 0.0
var boss_can_evolve: bool = false

var species_data := {
	"spore_root": {"hp": 12.0, "color": Color(0.35, 1.0, 0.43), "traits": ["producer", "stationary", "fungal"]},
	"carrion_mite": {"hp": 7.0, "color": Color(0.78, 0.62, 0.42), "traits": ["scavenger", "wanders"]},
	"bloat_mite": {"hp": 15.0, "color": Color(0.36, 0.85, 0.56), "traits": ["swollen", "damp-adapted"]},
	"ember_mite": {"hp": 9.0, "color": Color(1.0, 0.42, 0.10), "traits": ["heated", "ash-biter"]},
	"gloom_slug": {"hp": 10.0, "color": Color(0.18, 0.72, 0.46), "traits": ["herbivore", "damp-dark"]},
	"oracle_slug": {"hp": 11.0, "color": Color(0.78, 0.38, 1.0), "traits": ["herbivore", "omens", "magic-sense"]},
	"needle_bat": {"hp": 8.0, "color": Color(0.68, 0.68, 0.78), "traits": ["predator", "hunter"]},
	"goblin": {"hp": 10.0, "color": Color(0.54, 0.82, 0.38), "traits": ["den-born", "guard"]},
	"skeleton_servitor": {"hp": 14.0, "color": Color(0.88, 0.84, 0.70), "traits": ["den-born", "bone-bound"]},
	"hex_goblin": {"hp": 11.0, "color": Color(0.70, 0.36, 1.0), "traits": ["den-born", "hexed"]},
	"ember_imp": {"hp": 9.0, "color": Color(1.0, 0.34, 0.08), "traits": ["den-born", "heated"]},
	"bog_mite": {"hp": 13.0, "color": Color(0.32, 0.78, 0.48), "traits": ["den-born", "damp"]},
	"cinder_witch": {"hp": 12.0, "color": Color(1.0, 0.30, 0.78), "traits": ["den-born", "magic-heat"]},
	"heart_larva": {"hp": 85.0, "color": Color(0.95, 0.10, 0.28), "traits": ["boss", "larva", "heartbound"]},
	"heart_juvenile": {"hp": 160.0, "color": Color(1.0, 0.20, 0.34), "traits": ["boss", "juvenile", "heartbound"]},
}

func _ready() -> void:
	_ensure_sprite_frames_loaded()

func initialize(new_species: String, new_tile_pos: Vector2i) -> void:
	species = new_species
	tile_pos = new_tile_pos
	var data: Dictionary = species_data.get(species, species_data["carrion_mite"])
	hp = float(data["hp"])
	max_hp = hp
	traits.assign(data["traits"])
	mutation_pressure.clear()
	_snap_world_position()
	queue_redraw()

func _process(delta: float) -> void:
	anim_time += delta
	_update_visual_position(delta)
	queue_redraw()

func _ensure_sprite_frames_loaded() -> void:
	if big_demon_frames.size() == 4 and goblin_run_frames.size() == 4 and skeleton_run_frames.size() == 4:
		return
	if big_demon_frames.is_empty():
		for frame_index in range(4):
			big_demon_frames.append(_load_texture("%s/frames/big_demon_idle_anim_f%s.png" % [TILESET_ROOT, frame_index]))
	if goblin_run_frames.is_empty():
		for frame_index in range(4):
			goblin_run_frames.append(_load_texture("%s/frames/goblin_run_anim_f%s.png" % [TILESET_ROOT, frame_index]))
	if skeleton_run_frames.is_empty():
		for frame_index in range(4):
			skeleton_run_frames.append(_load_texture("%s/frames/skelet_run_anim_f%s.png" % [TILESET_ROOT, frame_index]))

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

func _tile_world_position(coord: Vector2i) -> Vector2:
	return Vector2(coord.x * TILE_SIZE + TILE_SIZE * 0.5, coord.y * TILE_SIZE + TILE_SIZE * 0.5)

func _snap_world_position() -> void:
	visual_target_position = _tile_world_position(tile_pos)
	visual_start_position = visual_target_position
	visual_move_elapsed = VISUAL_MOVE_SECONDS
	position = visual_target_position

func _update_world_position() -> void:
	var target_position := _tile_world_position(tile_pos)
	if position.distance_to(target_position) < 0.01:
		visual_start_position = target_position
		visual_target_position = target_position
		visual_move_elapsed = VISUAL_MOVE_SECONDS
		position = target_position
		return
	visual_start_position = position
	visual_target_position = target_position
	visual_move_elapsed = 0.0

func _update_visual_position(delta: float) -> void:
	if visual_move_elapsed >= VISUAL_MOVE_SECONDS:
		position = visual_target_position
		return
	visual_move_elapsed = min(visual_move_elapsed + delta, VISUAL_MOVE_SECONDS)
	var t := visual_move_elapsed / VISUAL_MOVE_SECONDS
	var eased_t := t * t * (3.0 - 2.0 * t)
	position = visual_start_position.lerp(visual_target_position, eased_t)

func simulate_step(grid: DungeonGrid, all_creatures: Array, adventurers: Array = [], resources: DungeonResources = null) -> void:
	age += 1
	_update_temporary_buffs()
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
	elif _command_step(grid, all_creatures):
		pass
	else:
		_forager_step(grid, all_creatures, resources)
	_update_mutation(tile)
	if hp <= 0.0:
		tile.corpse_mass += 8.0
		if resources != null:
			resources.add("bone", 1)
		queue_free()

func _forager_step(grid: DungeonGrid, all_creatures: Array, resources: DungeonResources) -> void:
	move_cooldown -= 1
	var tile: DungeonTileData = grid.get_tile(tile_pos)
	if tile.biomass > 3.0:
		var eaten: float = min(tile.biomass, 4.5)
		tile.biomass -= eaten
		if resources != null:
			resources.add("biomass", 1 if eaten > 3.0 and species.begins_with("carrion") else 0)
	if tile.corpse_mass > 1.0 and species.contains("mite"):
		var corpse_eaten: float = min(tile.corpse_mass, 5.0)
		tile.corpse_mass -= corpse_eaten
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
	_move_to_if_open(grid, next, all_creatures)

func _predator_step(grid: DungeonGrid, all_creatures: Array, resources: DungeonResources) -> void:
	var prey = _nearest_prey(all_creatures, 8)
	if prey == null:
		_wander(grid, all_creatures)
		return
	if tile_pos.distance_to(prey.tile_pos) <= 1.1:
		prey.hp -= 3.0
		if resources != null:
			resources.add("fear", 1)
	else:
		_move_to_if_open(grid, _step_toward(grid, prey.tile_pos, all_creatures), all_creatures)

func _boss_step(grid: DungeonGrid, adventurers: Array) -> void:
	if species == "heart_larva" and boss_can_evolve and age >= 180:
		var evolution_heart := grid.find_structure("heart")
		_grow_boss(grid, evolution_heart if evolution_heart != Vector2i(-1, -1) else tile_pos)
		return
	var heart := grid.find_structure("heart")
	if heart == Vector2i(-1, -1):
		return
	if tile_pos.distance_to(heart) > BOSS_PATROL_RADIUS:
		_move_to_if_open(grid, _step_toward(grid, heart, []), [])
		return
	var attacked := false
	for adventurer in adventurers:
		if not is_instance_valid(adventurer):
			continue
		if tile_pos.distance_to(adventurer.tile_pos) <= 1.1 or adventurer.tile_pos == heart:
			adventurer.hp -= attack_damage()
			log_event.emit("%s pulses against a crawler near the Heart." % species.replace("_", " ").capitalize())
			attacked = true
			break
	if not attacked:
		_boss_idle_patrol(grid, heart)

func _boss_idle_patrol(grid: DungeonGrid, heart: Vector2i) -> void:
	if age % BOSS_PATROL_STEP_INTERVAL != 0:
		return
	var candidates: Array[Vector2i] = []
	for neighbor in grid.walkable_neighbors(tile_pos):
		if neighbor == heart:
			continue
		if neighbor.distance_to(heart) <= BOSS_PATROL_RADIUS:
			candidates.append(neighbor)
	if candidates.is_empty():
		if tile_pos.distance_to(heart) > 1.5:
			_move_to_if_open(grid, _step_toward(grid, heart, []), [])
		return
	var current_distance := tile_pos.distance_to(heart)
	if current_distance > BOSS_PATROL_RADIUS - 1.0:
		var inward := _step_toward(grid, heart, [])
		if inward != heart and inward.distance_to(heart) <= BOSS_PATROL_RADIUS:
			_move_to_if_open(grid, inward, [])
			return
	var index := int(age / BOSS_PATROL_STEP_INTERVAL + tile_pos.x + tile_pos.y) % candidates.size()
	_move_to_if_open(grid, candidates[index], [])

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
		adventurer.hp -= attack_damage()
		_try_lifesteal()
		log_event.emit("Spore root lashes a crawler with choking spores.")
	elif distance <= 1.1:
		adventurer.hp -= attack_damage()
		_try_lifesteal()
		log_event.emit("%s bites a crawler." % species.replace("_", " "))
	else:
		_move_to_if_open(grid, _step_toward(grid, adventurer.tile_pos, []), [])
	if adventurer.hp <= 0.0:
		var tile: DungeonTileData = grid.get_tile(adventurer.tile_pos)
		tile.corpse_mass += 12.0
		if resources != null:
			resources.add("fear", 2)
			resources.add("biomass", 3)
			resources.add("essence", 1)
			resources.add("magic", 1)
			var looted := int(adventurer.get("looted_essence"))
			var recovered_loot := resources.recovered_looted_essence(looted)
			if recovered_loot > 0:
				resources.add("essence", recovered_loot)
		log_event.emit("%s killed a crawler." % species.replace("_", " ").capitalize())
		adventurer.queue_free()

func _try_lifesteal() -> void:
	if lifesteal_chance > 0.0 and randf() < lifesteal_chance:
		hp += 1.5
		log_event.emit("%s drinks vitality from a crawler." % species.replace("_", " ").capitalize())

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

func _command_step(grid: DungeonGrid, all_creatures: Array) -> bool:
	if den_order == "" or species == "spore_root" or species.begins_with("heart_"):
		return false
	var target := command_target
	if den_order == "guard_heart":
		target = grid.find_structure("heart")
	if target == Vector2i(-1, -1):
		target = home_tile
	if den_order == "research":
		if home_tile != Vector2i(-1, -1) and tile_pos.distance_to(home_tile) > 1.2:
			_move_to_if_open(grid, _step_toward(grid, home_tile, all_creatures), all_creatures)
		elif _is_occupied_by_other_creature(tile_pos, all_creatures):
			_wander(grid, all_creatures)
		return true
	var desired_distance := 2.0
	if den_order == "ambush_door":
		desired_distance = 1.0
	elif den_order == "patrol":
		desired_distance = 5.0
	if den_order == "patrol" and home_tile != Vector2i(-1, -1) and tile_pos.distance_to(home_tile) <= desired_distance:
		_wander(grid, all_creatures)
		return true
	if target != Vector2i(-1, -1) and tile_pos.distance_to(target) > desired_distance:
		_move_to_if_open(grid, _step_toward(grid, target, all_creatures), all_creatures)
		return true
	if _is_occupied_by_other_creature(tile_pos, all_creatures):
		_wander(grid, all_creatures)
	return true

func _wander(grid: DungeonGrid, all_creatures: Array = []) -> void:
	var choices := _unoccupied_neighbors(grid, all_creatures)
	if choices.size() > 0:
		tile_pos = choices.pick_random()
		_update_world_position()

func _step_toward(grid: DungeonGrid, target: Vector2i, all_creatures: Array = []) -> Vector2i:
	var path := grid.find_path(tile_pos, target)
	if path.size() >= 2:
		if not _is_occupied_by_other_creature(path[1], all_creatures):
			return path[1]
		return _best_unoccupied_neighbor_toward(grid, target, all_creatures)
	return _best_unoccupied_neighbor_toward(grid, target, all_creatures)

func _best_unoccupied_neighbor_toward(grid: DungeonGrid, target: Vector2i, all_creatures: Array) -> Vector2i:
	var choices := _unoccupied_neighbors(grid, all_creatures)
	if choices.is_empty():
		return tile_pos
	var best: Vector2i = choices[0]
	var best_score := -999999.0
	for coord in choices:
		var score := -coord.distance_to(target) + randf_range(-0.05, 0.05)
		if score > best_score:
			best = coord
			best_score = score
	return best

func _unoccupied_neighbors(grid: DungeonGrid, all_creatures: Array) -> Array[Vector2i]:
	var choices: Array[Vector2i] = []
	for coord in grid.walkable_neighbors(tile_pos):
		if not _is_occupied_by_other_creature(coord, all_creatures):
			choices.append(coord)
	return choices

func _move_to_if_open(grid: DungeonGrid, next: Vector2i, all_creatures: Array) -> void:
	if next == tile_pos:
		if _is_occupied_by_other_creature(tile_pos, all_creatures):
			_wander(grid, all_creatures)
		return
	if grid.is_in_bounds(next) and grid.get_tile(next).is_walkable() and not _is_occupied_by_other_creature(next, all_creatures):
		tile_pos = next
		_update_world_position()
	elif _is_occupied_by_other_creature(tile_pos, all_creatures):
		_wander(grid, all_creatures)

func _is_occupied_by_other_creature(coord: Vector2i, all_creatures: Array) -> bool:
	for other in all_creatures:
		if other == self or not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		if other.tile_pos == coord:
			return true
	return false

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

func attack_damage() -> float:
	var base_damage := 0.0
	if species == "spore_root":
		base_damage = 1.4
	elif species == "needle_bat":
		base_damage = 3.0
	elif species == "heart_larva":
		base_damage = 8.0
	elif species == "heart_juvenile":
		base_damage = 14.0
	elif species in ["goblin", "skeleton_servitor", "hex_goblin", "ember_imp", "bog_mite", "cinder_witch"]:
		base_damage = 2.2
	elif species.contains("mite"):
		base_damage = 2.2
	return base_damage + attack_bonus + magic_field_bonus

func apply_magic_field_bonus(ticks: int = 4, bonus: float = 2.0) -> void:
	magic_field_ticks = max(magic_field_ticks, ticks)
	magic_field_bonus = max(magic_field_bonus, bonus)
	if not traits.has("magic-field"):
		traits.append("magic-field")

func _update_temporary_buffs() -> void:
	if magic_field_ticks <= 0:
		return
	magic_field_ticks -= 1
	if magic_field_ticks <= 0:
		magic_field_bonus = 0.0
		traits.erase("magic-field")

func status_summary() -> String:
	if species.begins_with("heart_"):
		return "bound to Heart"
	if species == "spore_root":
		return "rooted producer"
	if den_order == "research":
		return "researching"
	if den_order != "":
		return den_order.replace("_", " ")
	if species == "needle_bat":
		return "hunting prey"
	if species.contains("slug"):
		return "grazing damp dark tiles"
	if species.contains("mite"):
		return "scavenging biomass and corpses"
	return "wandering"

func _draw() -> void:
	_ensure_sprite_frames_loaded()
	var data: Dictionary = species_data.get(species, species_data["carrion_mite"])
	var color: Color = data["color"]
	var bob := sin(anim_time * 5.0 + tile_pos.x) * 1.8
	var radius := 7.0
	if species.begins_with("heart_") and big_demon_frames.size() == 4:
		var frame := int(floor(anim_time * 5.0)) % big_demon_frames.size()
		var scale := 1.35 if species == "heart_juvenile" else 1.1
		var size := Vector2(32, 36) * scale
		draw_texture_rect(big_demon_frames[frame], Rect2(Vector2(-size.x * 0.5, -size.y + 11.0 + bob), size), false)
	elif species == "goblin" and goblin_run_frames.size() == 4:
		var frame := int(floor(anim_time * 8.0 + tile_pos.x + tile_pos.y)) % goblin_run_frames.size()
		draw_texture_rect(goblin_run_frames[frame], Rect2(Vector2(-13, -18 + bob), Vector2(26, 26)), false)
	elif species == "skeleton_servitor" and skeleton_run_frames.size() == 4:
		var frame := int(floor(anim_time * 8.0 + tile_pos.x + tile_pos.y)) % skeleton_run_frames.size()
		draw_texture_rect(skeleton_run_frames[frame], Rect2(Vector2(-12, -17 + bob), Vector2(24, 24)), false)
	elif species == "hex_goblin" and goblin_run_frames.size() == 4:
		var frame := int(floor(anim_time * 8.0 + tile_pos.x + tile_pos.y)) % goblin_run_frames.size()
		draw_texture_rect(goblin_run_frames[frame], Rect2(Vector2(-13, -18 + bob), Vector2(26, 26)), false, Color(0.86, 0.58, 1.0, 1.0))
	elif species == "spore_root":
		draw_circle(Vector2(0, bob), 7.0, color.darkened(0.25))
		draw_circle(Vector2(-5, -4 + bob), 4.0, Color(0.65, 1.0, 0.52, 0.9))
		draw_circle(Vector2(5, -3 + bob), 3.2, Color(0.48, 1.0, 0.74, 0.75))
	elif species.contains("slug"):
		_draw_ellipse(Rect2(-10, -5 + bob, 20, 11), color)
		draw_circle(Vector2(7, -3 + bob), 3.2, color.lightened(0.25))
		if species == "oracle_slug":
			draw_circle(Vector2(3, -3 + bob), 2.2, Color(0.95, 0.78, 1.0))
	elif species.contains("mite"):
		if skeleton_run_frames.size() == 4:
			var frame := int(floor(anim_time * 8.0 + tile_pos.x + tile_pos.y)) % skeleton_run_frames.size()
			var tint := Color(1, 1, 1, 1)
			if species == "bloat_mite" or species == "bog_mite":
				tint = Color(0.62, 1.0, 0.70, 1.0)
			elif species == "ember_mite":
				tint = Color(1.0, 0.58, 0.34, 1.0)
			draw_texture_rect(skeleton_run_frames[frame], Rect2(Vector2(-12, -17 + bob), Vector2(24, 24)), false, tint)
		else:
			radius = 8.0 if species == "bloat_mite" else 6.5
			draw_circle(Vector2(0, bob), radius, color)
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
