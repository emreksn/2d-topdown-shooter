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
	var new_ancestry := ancestry_types.duplicate()
	if not new_ancestry.has(current_type):
		new_ancestry.append(current_type)
	return DamageSlice.new(new_amount, new_type, new_ancestry)

func get_applicable_types() -> Array[StringName]:
	var result := ancestry_types.duplicate()
	if not result.has(current_type):
		result.append(current_type)
	return result
