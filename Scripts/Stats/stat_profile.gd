class_name StatProfile
extends Resource

@export var values: Array[StatValue] = []

func get_base_value(stat_id: StringName, fallback: float = 0.0) -> float:
	for entry in values:
		if entry != null and entry.stat_id == stat_id:
			return entry.value
	return fallback

func get_stat_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in values:
		if entry != null and not result.has(entry.stat_id):
			result.append(entry.stat_id)
	return result
