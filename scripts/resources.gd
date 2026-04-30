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
	changed.emit(values.duplicate())
