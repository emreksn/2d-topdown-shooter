class_name DamagePacket
extends RefCounted

var slices: Array[DamageSlice] = []
var source: Node
var tags: Array[StringName] = []

func get_total_damage() -> float:
	var total: float = 0.0
	for slice in slices:
		total += slice.amount
	return total

func get_damage_by_type(damage_type: StringName) -> float:
	var total: float = 0.0
	for slice in slices:
		if slice.current_type == damage_type:
			total += slice.amount
	return total
