class_name ProjectileWeapon
extends Weapon

@export var projectile_scene: PackedScene
@export var allowed_base_damage_types: Array[StringName] = [DamageTypeIds.PHYSICAL]
@export_range(0.0, 100.0, 0.05, "or_greater") var added_damage_multiplier: float = 1.0
@export_range(0.0, 1000000.0, 1.0, "or_greater") var damage: float = 25.0
@export_range(1, 32, 1) var pellet_count: int = 1
@export_range(0.0, 120.0, 1.0) var spread_degrees: float = 0.0
@export_range(0.0, 120.0, 1.0) var spread_randomness_degrees: float = 0.0
@export var conversions: Array[DamageConversion] = []
@export_range(0, 512, 1, "or_greater") var max_pooled_projectiles: int = 96
@export_category("Projectile Behaviors")
@export_range(0, 100, 1, "or_greater") var pierce: int = 0
@export_range(0, 10, 1, "or_greater") var fork: int = 0
@export_range(0.0, 180.0, 1.0) var fork_angle_degrees: float = 36.0
@export_range(0.0, 2.0, 0.05, "or_greater") var fork_damage_multiplier: float = 0.7
@export_range(0, 100, 1, "or_greater") var chain: int = 0
@export_range(0.0, 2000.0, 8.0, "or_greater") var chain_radius: float = 420.0
@export_category("Status Delivery")
@export_range(0.0, 100.0, 1.0) var slow_chance: float = 0.0
@export_range(0.0, 100.0, 1.0) var slow_magnitude: float = 0.0
@export_range(0.0, 20.0, 0.1) var slow_duration: float = 0.0

@onready var projectile_origin: Marker2D = $ProjectileOrigin

var _random := RandomNumberGenerator.new()
var _projectile_pool: Array[Projectile] = []
var active_skill_aim_jitter_degrees: float = 0.0
var active_skill_force_single_projectile: bool = false

func _ready() -> void:
	_random.randomize()
	super._ready()

func perform_basic_attack(target_node: Node2D) -> void:
	if projectile_scene == null:
		return

	var projectile_parent := get_tree().get_first_node_in_group(&"projectiles_container")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene

	var attack_tags := get_attack_tags()
	var resolved_conversions := conversions.duplicate()
	resolved_conversions.append_array(_get_actor_damage_conversions())
	var packet := DamageResolver.build_outgoing_packet(
		stat_component,
		actor_stat_component,
		resolved_conversions,
		attack_tags,
		_get_actor_source(),
		allowed_base_damage_types,
		added_damage_multiplier
	)
	if packet.slices.is_empty():
		packet.slices = [DamageSlice.new(damage, _get_fallback_damage_type())]

	var projectile_speed := stat_component.get_stat(
		StatIds.PROJECTILE_SPEED,
		attack_tags,
		StatModifier.Scope.LOCAL
	)
	var base_direction := (
		active_skill_forced_attack_direction.normalized()
		if not active_skill_forced_attack_direction.is_zero_approx()
		else projectile_origin.global_position.direction_to(
			target_node.global_position
		)
	)
	var clamped_pellet_count: int = 1 if active_skill_force_single_projectile else maxi(pellet_count, 1)
	var resolved_spread_degrees := 0.0 if active_skill_force_single_projectile else spread_degrees
	var resolved_spread_randomness := (
		0.0
		if active_skill_force_single_projectile
		else spread_randomness_degrees
	)
	var spread_radians := deg_to_rad(resolved_spread_degrees)
	for pellet_index: int in range(clamped_pellet_count):
		var projectile := _acquire_projectile(projectile_parent)
		if projectile == null:
			push_warning("Projectile weapon scene must have a Projectile root.")
			return
		projectile.global_position = projectile_origin.global_position
		var t := (
			0.5
			if clamped_pellet_count == 1
			else float(pellet_index) / float(clamped_pellet_count - 1)
		)
		var angle_offset := lerpf(
			-spread_radians * 0.5,
			spread_radians * 0.5,
			t
		)
		if resolved_spread_randomness > 0.0:
			angle_offset += deg_to_rad(
				_random.randf_range(
					-resolved_spread_randomness,
					resolved_spread_randomness
				)
			)
		if active_skill_aim_jitter_degrees > 0.0:
			angle_offset += deg_to_rad(
				_random.randf_range(
					-active_skill_aim_jitter_degrees,
					active_skill_aim_jitter_degrees
				)
			)
		projectile.setup(
			base_direction.rotated(angle_offset),
			_clone_damage_packet(packet),
			projectile_speed,
			active_skill_debug_prints,
			active_skill_last_projectile_debug_label,
			_get_projectile_behavior()
		)

func _exit_tree() -> void:
	for projectile in _projectile_pool:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_projectile_pool.clear()

func _acquire_projectile(projectile_parent: Node) -> Projectile:
	while not _projectile_pool.is_empty():
		var pooled := _projectile_pool.pop_back() as Projectile
		if not is_instance_valid(pooled):
			continue
		projectile_parent.add_child(pooled)
		return pooled

	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		return null
	projectile.enable_pool_recycling()
	projectile.recycle_requested.connect(_on_projectile_recycle_requested)
	projectile_parent.add_child(projectile)
	return projectile

func _on_projectile_recycle_requested(projectile: Projectile) -> void:
	call_deferred("_recycle_projectile_deferred", projectile)

func _recycle_projectile_deferred(projectile: Projectile) -> void:
	if not is_instance_valid(projectile):
		return
	projectile.reset_for_pool()
	var parent := projectile.get_parent()
	if parent != null:
		parent.remove_child(projectile)
	if _projectile_pool.size() >= max_pooled_projectiles:
		projectile.queue_free()
		return
	_projectile_pool.append(projectile)

func _get_actor_damage_conversions() -> Array[DamageConversion]:
	var result: Array[DamageConversion] = []
	var actor := _get_actor_source()
	if actor == null:
		return result
	var inventory := actor.get_node_or_null(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	if is_instance_valid(inventory):
		result.append_array(inventory.get_damage_conversions())
	return result

func _get_projectile_behavior() -> Dictionary:
	return {
		&"projectile_scene": projectile_scene,
		&"target_group": target_group,
		&"damage_modifiers": _get_projectile_damage_modifiers(),
		&"pierce": _get_projectile_behavior_count(StatIds.PROJECTILE_PIERCE, pierce),
		&"fork": _get_projectile_behavior_count(StatIds.PROJECTILE_FORK, fork),
		&"fork_angle_degrees": fork_angle_degrees,
		&"fork_damage_multiplier": fork_damage_multiplier,
		&"chain": _get_projectile_behavior_count(StatIds.PROJECTILE_CHAIN, chain),
		&"chain_radius": _get_projectile_behavior_value(
			StatIds.PROJECTILE_CHAIN_RADIUS,
			chain_radius
		),
		&"slow_chance": _get_projectile_behavior_value(
			StatIds.SLOW_CHANCE,
			slow_chance
		),
		&"slow_magnitude": _get_projectile_behavior_value(
			StatIds.SLOW_MAGNITUDE,
			slow_magnitude
		),
		&"slow_duration": _get_projectile_behavior_value(
			StatIds.SLOW_DURATION,
			slow_duration
		)
	}

func _get_projectile_behavior_count(stat_id: StringName, base_value: int) -> int:
	return maxi(roundi(_get_projectile_behavior_value(stat_id, float(base_value))), 0)

func _get_projectile_behavior_value(stat_id: StringName, base_value: float) -> float:
	if not is_instance_valid(stat_component):
		return base_value
	return maxf(base_value + stat_component.get_stat(stat_id, get_attack_tags()), 0.0)

func _get_projectile_damage_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	if not is_instance_valid(stat_component):
		return result
	var tags := get_attack_tags()
	if not tags.has(&"forked"):
		tags.append(&"forked")
	for modifier in stat_component.get_applicable_modifiers(
		[StatIds.DAMAGE],
		tags,
		StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
	):
		if (
			modifier.required_all_tags.has(&"forked")
			or modifier.required_any_tags.has(&"forked")
		):
			result.append(modifier)
	return result

func _get_fallback_damage_type() -> StringName:
	if allowed_base_damage_types != null and not allowed_base_damage_types.is_empty():
		return allowed_base_damage_types[0]
	return DamageTypeIds.PHYSICAL

func _clone_damage_packet(packet: DamagePacket) -> DamagePacket:
	var clone := DamagePacket.new()
	clone.source = packet.source
	clone.tags = packet.tags.duplicate()
	for slice in packet.slices:
		clone.slices.append(
			DamageSlice.new(
				slice.amount,
				slice.current_type,
				slice.ancestry_types
			)
		)
	return clone

func _get_actor_source() -> Node:
	var mount := get_parent()
	return mount.get_parent() if mount != null else null
