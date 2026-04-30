class_name DungeonTileData
extends RefCounted

enum Kind {
	FLOOR,
	WALL,
	STONE,
	ENTRANCE
}

var kind: int = Kind.STONE
var temperature: float = 24.0
var moisture: float = 18.0
var magic: float = 6.0
var darkness: float = 96.0
var biomass: float = 0.0

var heat_source: bool = false
var moisture_source: bool = false
var magic_source: bool = false
var spore_seed: bool = false
var corpse_mass: float = 0.0
var structure: String = ""
var heart_hp: int = 0
var trap_damage: int = 0
var locked_door: bool = false
var den_id: int = -1
var den_anchor: bool = false
var den_spawn_progress: int = 0
var planning_floor_cost: int = 0
var planning_structure_cost: int = 0

func _init(initial_kind: int = Kind.STONE) -> void:
	kind = initial_kind
	if kind == Kind.WALL:
		temperature = 18.0
		moisture = 8.0
		magic = 0.0
		darkness = 100.0
	elif kind == Kind.STONE:
		temperature = 22.0
		moisture = 18.0
		magic = 4.0
		darkness = 100.0
	else:
		temperature = 25.0
		moisture = 28.0
		magic = 8.0
		darkness = 92.0

func is_walkable() -> bool:
	return kind == Kind.FLOOR or kind == Kind.ENTRANCE

func is_diggable() -> bool:
	return kind == Kind.STONE

func tile_name() -> String:
	if structure == "heart":
		return "dungeon heart"
	if structure == "treasure":
		return "treasure cache"
	if structure == "trap":
		return "spike trap"
	if structure == "door":
		return "dungeon door"
	match kind:
		Kind.FLOOR:
			return "cave floor"
		Kind.WALL:
			return "outer wall"
		Kind.STONE:
			return "diggable stone"
		Kind.ENTRANCE:
			return "dungeon entrance"
	return "unknown"

func set_floor() -> void:
	kind = Kind.FLOOR
	darkness = max(darkness, 88.0)
	moisture = max(moisture, 24.0)

func set_stone() -> void:
	kind = Kind.STONE
	structure = ""
	heart_hp = 0
	trap_damage = 0
	locked_door = false
	den_id = -1
	den_anchor = false
	den_spawn_progress = 0
	planning_floor_cost = 0
	planning_structure_cost = 0
	heat_source = false
	moisture_source = false
	magic_source = false
	spore_seed = false

func snapshot() -> Dictionary:
	return {
		"kind": kind,
		"temperature": temperature,
		"moisture": moisture,
		"magic": magic,
		"darkness": darkness,
		"biomass": biomass,
		"heat_source": heat_source,
		"moisture_source": moisture_source,
		"magic_source": magic_source,
		"spore_seed": spore_seed,
		"corpse_mass": corpse_mass,
		"structure": structure,
		"heart_hp": heart_hp,
		"trap_damage": trap_damage,
		"locked_door": locked_door,
		"den_id": den_id,
		"den_anchor": den_anchor,
		"den_spawn_progress": den_spawn_progress,
		"planning_floor_cost": planning_floor_cost,
		"planning_structure_cost": planning_structure_cost,
	}

func restore(snapshot_data: Dictionary) -> void:
	kind = int(snapshot_data["kind"])
	temperature = float(snapshot_data["temperature"])
	moisture = float(snapshot_data["moisture"])
	magic = float(snapshot_data["magic"])
	darkness = float(snapshot_data["darkness"])
	biomass = float(snapshot_data["biomass"])
	heat_source = bool(snapshot_data["heat_source"])
	moisture_source = bool(snapshot_data["moisture_source"])
	magic_source = bool(snapshot_data["magic_source"])
	spore_seed = bool(snapshot_data["spore_seed"])
	corpse_mass = float(snapshot_data["corpse_mass"])
	structure = String(snapshot_data["structure"])
	heart_hp = int(snapshot_data["heart_hp"])
	trap_damage = int(snapshot_data["trap_damage"])
	locked_door = bool(snapshot_data["locked_door"])
	den_id = int(snapshot_data.get("den_id", -1))
	den_anchor = bool(snapshot_data.get("den_anchor", false))
	den_spawn_progress = int(snapshot_data.get("den_spawn_progress", 0))
	planning_floor_cost = int(snapshot_data["planning_floor_cost"])
	planning_structure_cost = int(snapshot_data["planning_structure_cost"])

func clamp_values() -> void:
	temperature = clampf(temperature, 0.0, 100.0)
	moisture = clampf(moisture, 0.0, 100.0)
	magic = clampf(magic, 0.0, 100.0)
	darkness = clampf(darkness, 0.0, 100.0)
	biomass = clampf(biomass, 0.0, 100.0)
	corpse_mass = clampf(corpse_mass, 0.0, 100.0)
