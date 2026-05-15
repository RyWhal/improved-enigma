class_name DungeonResources
extends Node

signal changed(values: Dictionary)

var values: Dictionary = {
	"essence": 140,
	"biomass": 20,
	"magic": 0,
	"bone": 0,
	"fear": 0,
	"knowledge": 0,
}
var initial_values: Dictionary = values.duplicate()
var looted_spoils_rank: int = 0
var fearful_reclamation_rank: int = 0

func add(resource_name: String, amount: int) -> void:
	values[resource_name] = int(values.get(resource_name, 0)) + amount
	changed.emit(values.duplicate())

func spend(resource_name: String, amount: int) -> bool:
	if int(values.get(resource_name, 0)) < amount:
		return false
	values[resource_name] = int(values[resource_name]) - amount
	changed.emit(values.duplicate())
	return true

func get_amount(resource_name: String) -> int:
	return int(values.get(resource_name, 0))

func set_amount(resource_name: String, amount: int) -> void:
	values[resource_name] = amount
	changed.emit(values.duplicate())

func snapshot() -> Dictionary:
	return values.duplicate()

func reset() -> void:
	values = initial_values.duplicate()
	looted_spoils_rank = 0
	fearful_reclamation_rank = 0
	changed.emit(values.duplicate())

func set_looted_spoils_rank(rank: int) -> void:
	looted_spoils_rank = max(rank, 0)

func set_fearful_reclamation_rank(rank: int) -> void:
	fearful_reclamation_rank = max(rank, 0)

func recovered_looted_essence(looted_amount: int) -> int:
	if looted_amount <= 0 or looted_spoils_rank <= 0:
		return 0
	var recovered := looted_amount
	if looted_spoils_rank == 1:
		recovered = ceili(float(looted_amount) * 0.5)
	if fearful_reclamation_rank > 0 and recovered < looted_amount:
		recovered = min(looted_amount, recovered + max(1, int(values.get("fear", 0)) / 20))
	return recovered
