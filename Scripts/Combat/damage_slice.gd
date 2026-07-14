class_name DamageSlice
extends RefCounted

var amount: float
var current_type: StringName
var ancestry_types: Array[StringName]

func _init(
	initial_amount: float = 0.0,
	initial_type: StringName = &"",
	initial_ancestry: Array[StringName] = []
) -> void:
	amount = initial_amount
	current_type = initial_type
	ancestry_types = initial_ancestry.duplicate()

func converted_copy(new_type: StringName, new_amount: float) -> DamageSlice:
	return DamageSlice.new(new_amount, new_type)

func get_applicable_types() -> Array[StringName]:
	return [current_type]
