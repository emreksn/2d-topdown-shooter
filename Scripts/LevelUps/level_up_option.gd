class_name LevelUpOption
extends Resource

@export var display_name: String = "Level Up"
@export var rarity: ItemDefinition.Rarity = ItemDefinition.Rarity.COMMON
@export var modifier: StatModifier

func get_display_text() -> String:
	if modifier == null:
		return display_name
	return ItemDefinition._format_modifier_line(modifier)

func create_modifier_set() -> ModifierSet:
	var _set := ModifierSet.new()
	if modifier != null:
		_set.modifiers = [_clone_modifier(modifier)]
	return _set

func _clone_modifier(source: StatModifier) -> StatModifier:
	var clone := StatModifier.new()
	clone.stat_id = source.stat_id
	clone.operation = source.operation
	clone.value = source.value
	clone.scope = source.scope
	clone.target_domain = source.target_domain
	clone.required_all_tags = source.required_all_tags.duplicate()
	clone.required_any_tags = source.required_any_tags.duplicate()
	clone.excluded_tags = source.excluded_tags.duplicate()
	return clone
