class_name RangedAttackComponent
extends Node2D

@export var projectile_scene: PackedScene
@export var stat_component: StatComponent
@export var movement_behavior: RangedRingBehavior
@export_range(0.0, 1000000.0, 1.0, "or_greater") var damage: float = 8.0
@export_range(0.0, 5000.0, 10.0, "or_greater") var projectile_speed: float = 360.0
@export_range(0.1, 10.0, 0.05, "or_greater") var charge_duration: float = 1.5
@export_range(0.0, 10.0, 0.05, "or_greater") var attack_cooldown: float = 1.0
@export var target_group: StringName = &"player"
@export var projectile_parent_group: StringName = &"projectiles_container"
@export var charge_color := Color(1.0, 0.85, 0.25, 1.0)

var _target: Node2D
var _charge_remaining: float = 0.0
var _cooldown_remaining: float = 0.0
var _is_charging := false
var _base_modulate := Color.WHITE
var _actor: Node2D
var _status_effects: StatusEffectComponent

func _ready() -> void:
	_actor = get_parent() as Node2D
	if is_instance_valid(_actor):
		_base_modulate = _actor.modulate
	if not is_instance_valid(stat_component):
		stat_component = _find_stat_component()
	if not is_instance_valid(movement_behavior):
		movement_behavior = _find_ring_behavior()
	_status_effects = _find_status_effects()

func _process(delta: float) -> void:
	if not is_instance_valid(_actor):
		return
	_target = _get_target()
	if not is_instance_valid(_target):
		_cancel_charge()
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(
			_cooldown_remaining - delta * _get_action_speed_multiplier(),
			0.0
		)
		return

	if _is_charging:
		_charge_remaining = maxf(
			_charge_remaining - delta * _get_action_speed_multiplier(),
			0.0
		)
		_update_charge_feedback()
		if _charge_remaining <= 0.0:
			_fire()
		return

	if _is_target_in_ring():
		_begin_charge()

func is_charging() -> bool:
	return _is_charging

func reset_for_pool_spawn() -> void:
	_charge_remaining = 0.0
	_cooldown_remaining = 0.0
	_is_charging = false
	_target = null
	if is_instance_valid(_actor):
		_actor.modulate = _base_modulate
	set_process(true)

func _begin_charge() -> void:
	_is_charging = true
	_charge_remaining = charge_duration
	_update_charge_feedback()

func _cancel_charge() -> void:
	if not _is_charging:
		return
	_is_charging = false
	if is_instance_valid(_actor):
		_actor.modulate = _base_modulate

func _fire() -> void:
	_is_charging = false
	_cooldown_remaining = attack_cooldown
	if is_instance_valid(_actor):
		_actor.modulate = _base_modulate
	if projectile_scene == null or not is_instance_valid(_target):
		return

	var projectile := projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_warning("Ranged enemy projectile scene must have a Projectile root.")
		return

	var parent := get_tree().get_first_node_in_group(projectile_parent_group)
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(projectile)
	projectile.global_position = global_position
	projectile.setup(
		global_position.direction_to(_target.global_position),
		_build_damage_packet(),
		projectile_speed
	)

func _build_damage_packet() -> DamagePacket:
	return DamageResolver.build_direct_packet(
		damage,
		DamageTypeIds.PHYSICAL,
		stat_component,
		[&"attack", &"projectile", &"ranged", &"monster"],
		_actor
	)

func _update_charge_feedback() -> void:
	if not is_instance_valid(_actor):
		return
	var progress := 1.0 - (_charge_remaining / maxf(charge_duration, 0.001))
	_actor.modulate = _base_modulate.lerp(charge_color, clampf(progress, 0.0, 1.0))

func _is_target_in_ring() -> bool:
	if is_instance_valid(movement_behavior):
		return movement_behavior.is_in_attack_ring(_actor, _target)
	return true

func _get_target() -> Node2D:
	if is_instance_valid(_target):
		return _target
	return get_tree().get_first_node_in_group(target_group) as Node2D

func _find_stat_component() -> StatComponent:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is StatComponent:
			return sibling
	return null

func _find_ring_behavior() -> RangedRingBehavior:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is RangedRingBehavior:
			return sibling
	return null

func _find_status_effects() -> StatusEffectComponent:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is StatusEffectComponent:
			return sibling
	return null

func _get_action_speed_multiplier() -> float:
	return (
		_status_effects.get_action_speed_multiplier()
		if is_instance_valid(_status_effects)
		else 1.0
	)
