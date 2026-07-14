class_name DamageTypeIds
extends RefCounted

const PHYSICAL := &"physical"
const ELEMENTAL := &"elemental"

const ORDER: Array[StringName] = [
	PHYSICAL,
	ELEMENTAL
]

static func get_index(damage_type: StringName) -> int:
	return ORDER.find(damage_type)

static func is_supported(damage_type: StringName) -> bool:
	return ORDER.has(damage_type)

static func is_valid_conversion(
	source_type: StringName,
	destination_type: StringName,
	allow_same_type: bool = false
) -> bool:
	if not is_supported(source_type) or not is_supported(destination_type):
		return false
	return source_type != destination_type or allow_same_type

static func get_damage_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		PHYSICAL:
			return StatIds.PHYSICAL_DAMAGE
		ELEMENTAL:
			return StatIds.ELEMENTAL_DAMAGE
	return &""

static func get_resistance_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		PHYSICAL:
			return StatIds.PHYSICAL_RESISTANCE
		ELEMENTAL:
			return StatIds.ELEMENTAL_RESISTANCE
	return &""

static func get_maximum_resistance_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		PHYSICAL:
			return StatIds.MAXIMUM_PHYSICAL_RESISTANCE
		ELEMENTAL:
			return StatIds.MAXIMUM_ELEMENTAL_RESISTANCE
	return &""
