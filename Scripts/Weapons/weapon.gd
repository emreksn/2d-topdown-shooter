class_name Weapon
extends Node2D

@export var target_group: StringName = &"enemies"
@export_range(0.1, 20.0, 0.1, "or_greater") var attacks_per_second: float = 2.0
@export_range(0.0, 5000.0, 10.0, "or_greater") var targeting_range: float = 700.0
@export var weapon_definition: WeaponDefinition
@export var stat_component: StatComponent
@export var actor_stat_component: StatComponent

var _cooldown_remaining: float = 0.0
var _target: Node2D

func _ready() -> void:
	if not is_instance_valid(stat_component):
		for child in get_children():
			if child is StatComponent:
				stat_component = child
				break
	if not is_instance_valid(actor_stat_component):
		var ancestor := get_parent()
		while ancestor != null and not is_instance_valid(actor_stat_component):
			for child in ancestor.get_children():
				if child is StatComponent:
					actor_stat_component = child
					break
			ancestor = ancestor.get_parent()

func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_target = _find_nearest_target()

	if not is_instance_valid(_target):
		return

	look_at(_target.global_position)

	if _cooldown_remaining <= 0.0:
		perform_basic_attack(_target)
		var attack_tags := get_attack_tags()
		var attack_rate := (
			stat_component.get_stat(
				StatIds.ATTACK_RATE,
				attack_tags,
				StatModifier.Scope.LOCAL
			)
			if is_instance_valid(stat_component)
			else attacks_per_second
		)
		_cooldown_remaining = 1.0 / maxf(attack_rate, 0.01)

func perform_basic_attack(_target_node: Node2D) -> void:
	pass

func get_attack_tags() -> Array[StringName]:
	var resolved_tags: Array[StringName] = [&"attack"]
	var source_tags: Array[StringName] = []
	if weapon_definition != null:
		source_tags = weapon_definition.tags
	else:
		source_tags.append(&"weapon")
	for tag in source_tags:
		if not resolved_tags.has(tag):
			resolved_tags.append(tag)
	return resolved_tags

func has_weapon_tag(tag: StringName) -> bool:
	return get_attack_tags().has(tag)

func _find_nearest_target() -> Node2D:
	var nearest: Node2D
	var attack_tags := get_attack_tags()
	var resolved_range := (
		stat_component.get_stat(
			StatIds.TARGETING_RANGE,
			attack_tags,
			StatModifier.Scope.LOCAL
		)
		if is_instance_valid(stat_component)
		else targeting_range
	)
	var nearest_distance_squared := resolved_range * resolved_range

	for candidate_node in get_tree().get_nodes_in_group(target_group):
		var candidate := candidate_node as Node2D
		if not is_instance_valid(candidate):
			continue

		var distance_squared := global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = candidate

	return nearest
