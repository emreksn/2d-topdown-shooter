class_name StatCatalog
extends Resource

@export var definitions: Array[StatDefinition] = []

var _by_id: Dictionary = {}

func get_definition(stat_id: StringName) -> StatDefinition:
	if _by_id.is_empty():
		for definition in definitions:
			if definition != null:
				_by_id[definition.id] = definition
	return _by_id.get(stat_id) as StatDefinition

func get_default(stat_id: StringName) -> float:
	var definition := get_definition(stat_id)
	return definition.default_value if definition != null else 0.0
