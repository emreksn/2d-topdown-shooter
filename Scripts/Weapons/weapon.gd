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
var _targeting_random := RandomNumberGenerator.new()
var active_skill_random_targeting: bool = false
var active_skill_sector_targeting: bool = false
var active_skill_sector_count: int = 12
var active_skill_sector_index: int = 0
var active_skill_sector_bag: Array[int] = []
var active_skill_last_sector_index: int = 0
var active_skill_sector_target_chance: float = 0.5
var active_skill_debug_prints: bool = false
var active_skill_forced_attack_direction := Vector2.ZERO
var active_skill_last_projectile_debug_label: String = ""
var active_skill_use_actor_attack_rate: bool = false

func _ready() -> void:
	_targeting_random.randomize()
	resolve_stat_components()

func resolve_stat_components() -> void:
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
	_target = null if active_skill_sector_targeting else _find_nearest_target()

	if not active_skill_sector_targeting and not is_instance_valid(_target):
		return

	if _cooldown_remaining <= 0.0:
		var attack_target := _choose_attack_target(_target)
		if is_instance_valid(attack_target):
			look_at(attack_target.global_position)
			perform_basic_attack(attack_target)
		elif not active_skill_forced_attack_direction.is_zero_approx():
			rotation = active_skill_forced_attack_direction.angle()
			perform_basic_attack(null)
		var attack_tags := get_attack_tags()
		var attack_rate := _get_attack_rate(attack_tags)
		_cooldown_remaining = 1.0 / maxf(attack_rate, 0.01)
	elif not active_skill_sector_targeting and is_instance_valid(_target):
		look_at(_target.global_position)

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

func _get_attack_rate(attack_tags: Array[StringName]) -> float:
	if active_skill_use_actor_attack_rate and is_instance_valid(actor_stat_component):
		return actor_stat_component.get_stat(
			StatIds.ATTACK_RATE,
			attack_tags,
			StatModifier.Scope.GLOBAL | StatModifier.Scope.LOCAL
		)
	if is_instance_valid(stat_component):
		return stat_component.get_stat(
			StatIds.ATTACK_RATE,
			attack_tags,
			StatModifier.Scope.LOCAL
		)
	return attacks_per_second

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

func _choose_attack_target(fallback_target: Node2D) -> Node2D:
	active_skill_forced_attack_direction = Vector2.ZERO
	if active_skill_sector_targeting:
		return _choose_sector_attack_target()
	if not active_skill_random_targeting:
		return fallback_target

	var valid_targets: Array[Node2D] = []
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
	var range_squared := resolved_range * resolved_range
	for candidate_node in get_tree().get_nodes_in_group(target_group):
		var candidate := candidate_node as Node2D
		if (
			is_instance_valid(candidate)
			and global_position.distance_squared_to(candidate.global_position) <= range_squared
		):
			valid_targets.append(candidate)
	if valid_targets.is_empty():
		return fallback_target
	return valid_targets[
		_targeting_random.randi_range(0, valid_targets.size() - 1)
	]

func _choose_sector_attack_target() -> Node2D:
	var sector_index := _take_random_sector_index()
	active_skill_last_sector_index = sector_index
	var sector_targets := _get_targets_in_sector(sector_index)
	sector_targets.shuffle()
	var selected_target: Node2D
	for candidate in sector_targets:
		if _targeting_random.randf() <= active_skill_sector_target_chance:
			selected_target = candidate
			break
	if selected_target == null:
		active_skill_forced_attack_direction = _get_random_direction_in_sector(
			sector_index
		)
		active_skill_last_projectile_debug_label = (
			"Bulletstorm random sector %d"
			% (sector_index + 1)
		)
		if active_skill_debug_prints:
			print(
				"Bulletstorm random shot | sector=%d | candidates=%d"
				% [sector_index + 1, sector_targets.size()]
			)
	else:
		active_skill_last_projectile_debug_label = (
			"Bulletstorm targeted sector %d"
			% (sector_index + 1)
		)
		if active_skill_debug_prints:
			print(
				"Bulletstorm targeted shot | sector=%d | candidates=%d | target=%s"
				% [sector_index + 1, sector_targets.size(), selected_target.name]
			)
	return selected_target

func _get_targets_in_sector(sector_index: int) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var origin := _get_targeting_origin()
	var center_angle := _get_sector_center_angle(sector_index)
	var half_width := _get_sector_width() * 0.5
	for candidate in _get_targets_in_range():
		var direction := origin.direction_to(candidate.global_position)
		var delta := absf(angle_difference(center_angle, direction.angle()))
		if delta <= half_width:
			result.append(candidate)
	return result

func _get_random_direction_in_sector(sector_index: int) -> Vector2:
	var center_angle := _get_sector_center_angle(sector_index)
	var half_width := _get_sector_width() * 0.5
	return Vector2.RIGHT.rotated(
		center_angle + _targeting_random.randf_range(-half_width, half_width)
	)

func _take_random_sector_index() -> int:
	if active_skill_sector_bag.is_empty():
		_refill_active_skill_sector_bag()
	var bag_index := _targeting_random.randi_range(
		0,
		active_skill_sector_bag.size() - 1
	)
	var sector_index := active_skill_sector_bag[bag_index]
	active_skill_sector_bag.remove_at(bag_index)
	active_skill_sector_index = sector_index
	return sector_index

func _refill_active_skill_sector_bag() -> void:
	active_skill_sector_bag.clear()
	for index in range(maxi(active_skill_sector_count, 1)):
		active_skill_sector_bag.append(index)

func _get_sector_center_angle(sector_index: int) -> float:
	var sector_count := maxi(active_skill_sector_count, 1)
	var step := TAU / float(sector_count)
	return -PI * 0.5 - float(sector_index) * step

func _get_sector_width() -> float:
	return TAU / float(maxi(active_skill_sector_count, 1))

func _get_targets_in_range() -> Array[Node2D]:
	var result: Array[Node2D] = []
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
	var range_squared := resolved_range * resolved_range
	for candidate_node in get_tree().get_nodes_in_group(target_group):
		var candidate := candidate_node as Node2D
		if (
			is_instance_valid(candidate)
			and global_position.distance_squared_to(candidate.global_position) <= range_squared
		):
			result.append(candidate)
	return result

func _get_targeting_origin() -> Vector2:
	var mount := get_parent()
	if mount != null and mount.get_parent() is Node2D:
		return (mount.get_parent() as Node2D).global_position
	return global_position
