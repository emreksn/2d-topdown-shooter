class_name DamageTypeIds
extends RefCounted

const PHYSICAL := &"physical"
const LIGHTNING := &"lightning"
const COLD := &"cold"
const FIRE := &"fire"

const ORDER: Array[StringName] = [
	PHYSICAL,
	LIGHTNING,
	COLD,
	FIRE
]

static func get_index(damage_type: StringName) -> int:
	return ORDER.find(damage_type)

static func is_forward_conversion(
	source_type: StringName,
	destination_type: StringName
) -> bool:
	var source_index := get_index(source_type)
	var destination_index := get_index(destination_type)
	return source_index >= 0 and destination_index > source_index

static func get_damage_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		PHYSICAL:
			return StatIds.PHYSICAL_DAMAGE
		LIGHTNING:
			return StatIds.LIGHTNING_DAMAGE
		COLD:
			return StatIds.COLD_DAMAGE
		FIRE:
			return StatIds.FIRE_DAMAGE
	return &""

static func get_resistance_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		PHYSICAL:
			return StatIds.PHYSICAL_RESISTANCE
		LIGHTNING:
			return StatIds.LIGHTNING_RESISTANCE
		COLD:
			return StatIds.COLD_RESISTANCE
		FIRE:
			return StatIds.FIRE_RESISTANCE
	return &""

static func get_maximum_resistance_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		PHYSICAL:
			return StatIds.MAXIMUM_PHYSICAL_RESISTANCE
		LIGHTNING:
			return StatIds.MAXIMUM_LIGHTNING_RESISTANCE
		COLD:
			return StatIds.MAXIMUM_COLD_RESISTANCE
		FIRE:
			return StatIds.MAXIMUM_FIRE_RESISTANCE
	return &""
