class_name MonsterScalingComponent
extends Node

@export var stat_component: StatComponent

func _ready() -> void:
	if is_instance_valid(stat_component):
		return
	for sibling in get_parent().get_children():
		if sibling is StatComponent:
			stat_component = sibling
			return

func get_effectiveness_toughness_factor() -> float:
	return maxf(0.01, 1.0 + _get_effectiveness() / 100.0)

func get_experience_multiplier() -> float:
	var base_multiplier := 1.0
	if stat_component != null:
		base_multiplier = stat_component.get_stat(
			StatIds.EXPERIENCE_GRANTED_MULTIPLIER
		)
	return maxf(0.0, base_multiplier * (1.0 + _get_effectiveness() / 200.0))

func get_item_quantity_multiplier() -> float:
	var base_multiplier := 1.0
	if stat_component != null:
		base_multiplier = stat_component.get_stat(
			StatIds.ITEM_QUANTITY_MULTIPLIER
		)
	return maxf(0.0, base_multiplier * (1.0 + _get_effectiveness() / 200.0))

func _get_effectiveness() -> float:
	return (
		stat_component.get_stat(StatIds.MONSTER_EFFECTIVENESS)
		if stat_component != null
		else 0.0
	)
