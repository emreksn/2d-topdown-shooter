class_name RuntimeModifierRegistry
extends Node

signal sources_changed

var _sources: Dictionary = {}

func add_modifier_source(source_id: StringName, modifier_set: ModifierSet) -> void:
	if source_id == &"":
		push_warning("Runtime modifier sources require a non-empty source ID.")
		return
	if modifier_set == null:
		remove_modifier_source(source_id)
		return
	_sources[source_id] = modifier_set
	sources_changed.emit()

func remove_modifier_source(source_id: StringName) -> void:
	if _sources.erase(source_id):
		sources_changed.emit()

func get_applicable_sources(
	domain: StringName,
	context_tags: Array[StringName]
) -> Dictionary:
	var result := {}
	for source_id in _sources:
		var modifier_set := _sources[source_id] as ModifierSet
		if _set_can_apply(modifier_set, domain, context_tags):
			result[source_id] = modifier_set
	return result

func _set_can_apply(
	modifier_set: ModifierSet,
	domain: StringName,
	context_tags: Array[StringName]
) -> bool:
	if modifier_set == null:
		return false
	for modifier in modifier_set.modifiers:
		if (
			modifier != null
			and modifier.applies_to(
				domain,
				context_tags,
				StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
			)
		):
			return true
	return false
