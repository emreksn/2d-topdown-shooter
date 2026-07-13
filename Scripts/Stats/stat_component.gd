class_name StatComponent
extends Node

signal stat_changed(stat_id: StringName)
signal modifiers_changed

@export var domain: StringName
@export var default_context_tags: Array[StringName] = []
@export var catalog: StatCatalog
@export var base_profile: StatProfile

var _modifier_sources: Dictionary = {}
var _cache: Dictionary = {}

func add_modifier_source(source_id: StringName, modifier_set: ModifierSet) -> void:
	if source_id == &"":
		push_warning("Stat modifier sources require a non-empty source ID.")
		return
	if modifier_set == null:
		remove_modifier_source(source_id)
		return
	var affected_stats := _get_set_stat_ids(
		_modifier_sources.get(source_id) as ModifierSet
	)
	for stat_id in _get_set_stat_ids(modifier_set):
		affected_stats[stat_id] = true
	_modifier_sources[source_id] = modifier_set
	_invalidate(affected_stats)

func remove_modifier_source(source_id: StringName) -> void:
	var affected_stats := _get_set_stat_ids(
		_modifier_sources.get(source_id) as ModifierSet
	)
	if not _modifier_sources.erase(source_id):
		return
	_invalidate(affected_stats)

func clear_modifier_sources() -> void:
	if _modifier_sources.is_empty():
		return
	var affected_stats: Dictionary = {}
	for modifier_set in _modifier_sources.values():
		for stat_id in _get_set_stat_ids(modifier_set):
			affected_stats[stat_id] = true
	_modifier_sources.clear()
	_invalidate(affected_stats)

func get_modifier_source(source_id: StringName) -> ModifierSet:
	return _modifier_sources.get(source_id) as ModifierSet

func get_stat(
	stat_id: StringName,
	context_tags: Array[StringName] = [],
	scope_mask: int = StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
) -> float:
	var resolved_context_tags := _resolve_context_tags(context_tags)
	var cache_key := _make_cache_key(stat_id, resolved_context_tags, scope_mask)
	if _cache.has(cache_key):
		return float(_cache[cache_key])

	var definition := catalog.get_definition(stat_id) if catalog != null else null
	var default_value := definition.default_value if definition != null else 0.0
	var base := (
		base_profile.get_base_value(stat_id, default_value)
		if base_profile != null
		else default_value
	)
	var flat: float = 0.0
	var increased: float = 0.0
	var more_multiplier: float = 1.0

	for modifier_set in _modifier_sources.values():
		if modifier_set == null:
			continue
		for modifier in modifier_set.modifiers:
			if (
				modifier == null
				or modifier.stat_id != stat_id
				or not modifier.applies_to(domain, resolved_context_tags, scope_mask)
			):
				continue
			match modifier.operation:
				StatModifier.Operation.FLAT:
					flat += modifier.value
				StatModifier.Operation.INCREASED:
					increased += modifier.value
				StatModifier.Operation.MORE:
					more_multiplier *= maxf(0.0, 1.0 + modifier.value / 100.0)

	var result := (base + flat) * (1.0 + increased / 100.0) * more_multiplier
	if definition != null:
		result = definition.clamp_value(result)
		_cache[cache_key] = result
	return result

func get_base_stat(stat_id: StringName) -> float:
	var definition := catalog.get_definition(stat_id) if catalog != null else null
	var default_value := definition.default_value if definition != null else 0.0
	return (
		base_profile.get_base_value(stat_id, default_value)
		if base_profile != null
		else default_value
	)

func get_known_stat_ids() -> Array[StringName]:
	var stat_ids: Array[StringName] = []
	if base_profile != null:
		stat_ids.append_array(base_profile.get_stat_ids())
	for modifier_set in _modifier_sources.values():
		if modifier_set == null:
			continue
		for modifier in modifier_set.modifiers:
			if modifier != null and not stat_ids.has(modifier.stat_id):
				stat_ids.append(modifier.stat_id)
	return stat_ids

func create_snapshot(
	context_tags: Array[StringName] = [],
	scope_mask: int = StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
) -> Dictionary:
	var resolved_context_tags := _resolve_context_tags(context_tags)
	var stat_ids := get_known_stat_ids()

	var snapshot := {}
	for stat_id in stat_ids:
		snapshot[stat_id] = get_stat(stat_id, resolved_context_tags, scope_mask)
	return snapshot

func get_flat_modifier_total(
	stat_id: StringName,
	context_tags: Array[StringName] = [],
	scope_mask: int = StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
) -> float:
	var total: float = 0.0
	for modifier in get_applicable_modifiers(
		[stat_id],
		context_tags,
		scope_mask
	):
		if modifier.operation == StatModifier.Operation.FLAT:
			total += modifier.value
	return total

func get_applicable_modifiers(
	stat_ids: Array[StringName],
	context_tags: Array[StringName] = [],
	scope_mask: int = StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
) -> Array[StatModifier]:
	var resolved_context_tags := _resolve_context_tags(context_tags)
	var result: Array[StatModifier] = []
	var seen: Dictionary = {}
	for modifier_set in _modifier_sources.values():
		if modifier_set == null:
			continue
		for modifier in modifier_set.modifiers:
			if (
				modifier == null
				or not stat_ids.has(modifier.stat_id)
				or not modifier.applies_to(domain, resolved_context_tags, scope_mask)
			):
				continue
			var modifier_id: int = modifier.get_instance_id()
			if seen.has(modifier_id):
				continue
			seen[modifier_id] = true
			result.append(modifier)
	return result

func set_default_context_tags(context_tags: Array[StringName]) -> void:
	default_context_tags = context_tags.duplicate()
	_cache.clear()

func _make_cache_key(
	stat_id: StringName,
	context_tags: Array[StringName],
	scope_mask: int
) -> String:
	var sorted_tags := context_tags.duplicate()
	sorted_tags.sort()
	var tag_text := PackedStringArray()
	for tag in sorted_tags:
		tag_text.append(String(tag))
	return "%s|%d|%s" % [stat_id, scope_mask, ",".join(tag_text)]

func _resolve_context_tags(context_tags: Array[StringName]) -> Array[StringName]:
	if context_tags.is_empty() and not default_context_tags.is_empty():
		return default_context_tags
	return context_tags

func _get_set_stat_ids(modifier_set: ModifierSet) -> Dictionary:
	var result: Dictionary = {}
	if modifier_set == null:
		return result
	for modifier in modifier_set.modifiers:
		if modifier != null:
			result[modifier.stat_id] = true
	return result

func _invalidate(affected_stats: Dictionary) -> void:
	_cache.clear()
	modifiers_changed.emit()
	for stat_id in affected_stats:
		stat_changed.emit(stat_id)
