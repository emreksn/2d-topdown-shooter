class_name Projectile
extends Area2D

signal recycle_requested(projectile: Projectile)

@export_range(0.0, 5000.0, 10.0, "or_greater") var speed: float = 650.0
@export var arena_bounds := Rect2(-800.0, -500.0, 1600.0, 1000.0)
@export_range(0.0, 1000.0, 1.0, "or_greater") var arena_exit_margin: float = 96.0
@export_range(0.1, 60.0, 0.1, "or_greater") var failsafe_lifetime: float = 10.0

var _direction := Vector2.RIGHT
var _damage_packet: DamagePacket
var _has_hit: bool = false
var _debug_enabled: bool = false
var _debug_label: String = ""
var _initial_failsafe_lifetime: float = 10.0
var _pooled_recycle_enabled := false
var _projectile_scene: PackedScene
var _target_group: StringName = &"enemies"
var _damage_modifiers: Array[StatModifier] = []
var _pierce_remaining: int = 0
var _fork_remaining: int = 0
var _fork_angle_radians: float = deg_to_rad(36.0)
var _fork_damage_multiplier: float = 0.7
var _chain_remaining: int = 0
var _chain_radius: float = 420.0
var _slow_chance: float = 0.0
var _slow_magnitude: float = 0.0
var _slow_duration: float = 0.0
var _hit_actor_ids: Dictionary = {}
var _despawn_requested: bool = false

func _ready() -> void:
	_initial_failsafe_lifetime = failsafe_lifetime
	_resolve_arena_bounds()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(
	direction: Vector2,
	damage_packet: DamagePacket,
	resolved_speed: float,
	debug_enabled: bool = false,
	debug_label: String = "",
	behavior: Dictionary = {}
) -> void:
	_direction = direction.normalized()
	_damage_packet = damage_packet
	speed = resolved_speed
	rotation = _direction.angle()
	_debug_enabled = debug_enabled
	_debug_label = debug_label
	_has_hit = false
	_despawn_requested = false
	failsafe_lifetime = _initial_failsafe_lifetime
	_projectile_scene = behavior.get(&"projectile_scene") as PackedScene
	_target_group = behavior.get(&"target_group", _target_group) as StringName
	_damage_modifiers.clear()
	_damage_modifiers.assign(behavior.get(&"damage_modifiers", []))
	var legacy_damage_multiplier := float(behavior.get(&"damage_multiplier", 1.0))
	if not is_equal_approx(legacy_damage_multiplier, 1.0):
		_damage_modifiers.append(_make_more_damage_modifier(
			(legacy_damage_multiplier - 1.0) * 100.0
		))
	_pierce_remaining = maxi(int(behavior.get(&"pierce", 0)), 0)
	_fork_remaining = maxi(int(behavior.get(&"fork", 0)), 0)
	_fork_angle_radians = deg_to_rad(
		maxf(float(behavior.get(&"fork_angle_degrees", 36.0)), 0.0)
	)
	_fork_damage_multiplier = maxf(
		float(behavior.get(&"fork_damage_multiplier", 0.7)),
		0.0
	)
	_chain_remaining = maxi(int(behavior.get(&"chain", 0)), 0)
	_chain_radius = maxf(float(behavior.get(&"chain_radius", 420.0)), 0.0)
	_slow_chance = clampf(float(behavior.get(&"slow_chance", 0.0)), 0.0, 100.0)
	_slow_magnitude = maxf(float(behavior.get(&"slow_magnitude", 0.0)), 0.0)
	_slow_duration = maxf(float(behavior.get(&"slow_duration", 0.0)), 0.0)
	_hit_actor_ids.clear()
	monitoring = true
	monitorable = true
	visible = true
	set_physics_process(true)

func enable_pool_recycling() -> void:
	_pooled_recycle_enabled = true

func reset_for_pool() -> void:
	_damage_packet = null
	_has_hit = false
	_despawn_requested = false
	_debug_enabled = false
	_debug_label = ""
	_projectile_scene = null
	_damage_modifiers.clear()
	_pierce_remaining = 0
	_fork_remaining = 0
	_chain_remaining = 0
	_slow_chance = 0.0
	_slow_magnitude = 0.0
	_slow_duration = 0.0
	_hit_actor_ids.clear()
	monitoring = false
	monitorable = false
	visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	failsafe_lifetime -= delta
	if failsafe_lifetime <= 0.0:
		_print_debug_result("MISS lifetime")
		_despawn()
	elif _is_outside_arena():
		_print_debug_result("MISS arena")
		_despawn()

func _resolve_arena_bounds() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var arena := scene.find_child("Arena", true, false) as Polygon2D
	if arena == null or arena.polygon.is_empty():
		return
	var first_point: Vector2 = arena.global_transform * arena.polygon[0]
	var resolved := Rect2(first_point, Vector2.ZERO)
	for point in arena.polygon:
		resolved = resolved.expand(arena.global_transform * point)
	arena_bounds = resolved

func _is_outside_arena() -> bool:
	return not arena_bounds.grow(arena_exit_margin).has_point(global_position)

func _on_area_entered(area: Area2D) -> void:
	if _has_hit or not area is Hurtbox:
		return

	var hurtbox := area as Hurtbox
	var actor := hurtbox.get_parent()
	var actor_id := actor.get_instance_id() if actor != null else hurtbox.get_instance_id()
	if _hit_actor_ids.has(actor_id):
		return

	_hit_actor_ids[actor_id] = true
	hurtbox.receive_damage(_get_modified_damage_packet())
	_try_apply_slow(actor)
	_print_debug_result("HIT %s" % hurtbox.name)
	_resolve_post_hit(actor)

func _resolve_post_hit(hit_actor: Node) -> void:
	if _pierce_remaining > 0:
		_pierce_remaining -= 1
		return

	_has_hit = true
	if _fork_remaining > 0:
		_queue_spawn_forks()
		_despawn()
		return
	if _chain_remaining > 0 and _redirect_to_chain_target(hit_actor):
		_has_hit = false
		return
	_despawn()

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		_print_debug_result("MISS wall")
		_despawn()

func _print_debug_result(result: String) -> void:
	if not _debug_enabled:
		return
	var label := _debug_label if not _debug_label.is_empty() else "Projectile"
	print("%s | %s" % [label, result])

func _get_modified_damage_packet() -> DamagePacket:
	if _damage_modifiers.is_empty():
		return _damage_packet
	var clone := DamagePacket.new()
	clone.source = _damage_packet.source
	clone.tags = _damage_packet.tags.duplicate()
	if not clone.tags.has(&"forked"):
		clone.tags.append(&"forked")
	for slice in _damage_packet.slices:
		clone.slices.append(
			DamageSlice.new(
				_apply_damage_modifiers(slice.amount, clone.tags),
				slice.current_type,
				slice.ancestry_types
			)
		)
	return clone

func _apply_damage_modifiers(amount: float, tags: Array[StringName]) -> float:
	var increased := 0.0
	var more_multiplier := 1.0
	for modifier in _damage_modifiers:
		if (
			modifier == null
			or modifier.stat_id != StatIds.DAMAGE
			or not modifier.applies_to(
				&"weapon",
				tags,
				StatModifier.Scope.LOCAL | StatModifier.Scope.GLOBAL
			)
		):
			continue
		match modifier.operation:
			StatModifier.Operation.FLAT:
				amount += modifier.value
			StatModifier.Operation.INCREASED:
				increased += modifier.value
			StatModifier.Operation.MORE:
				more_multiplier *= maxf(0.0, 1.0 + modifier.value / 100.0)
	return amount * (1.0 + increased / 100.0) * more_multiplier

func _queue_spawn_forks() -> void:
	if _projectile_scene == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var payload := {
		&"parent": parent,
		&"position": global_position,
		&"direction": _direction,
		&"damage_packet": _damage_packet,
		&"speed": speed,
		&"debug_enabled": _debug_enabled,
		&"debug_label": _debug_label,
		&"behavior": _make_child_behavior(),
		&"hit_actor_ids": _hit_actor_ids.duplicate(),
		&"fork_angle_radians": _fork_angle_radians
	}
	_spawn_forks_deferred.call_deferred(payload)

func _spawn_forks_deferred(payload: Dictionary) -> void:
	var parent: Node = payload[&"parent"] as Node
	if not is_instance_valid(parent):
		return
	var projectile_scene: PackedScene = _projectile_scene
	var behavior: Dictionary = payload[&"behavior"]
	if behavior.has(&"projectile_scene"):
		projectile_scene = behavior[&"projectile_scene"] as PackedScene
	if projectile_scene == null:
		return
	var spawn_position: Vector2 = payload[&"position"]
	var direction: Vector2 = payload[&"direction"]
	var damage_packet: DamagePacket = payload[&"damage_packet"] as DamagePacket
	var resolved_speed: float = float(payload[&"speed"])
	var debug_enabled: bool = bool(payload[&"debug_enabled"])
	var debug_label: String = str(payload[&"debug_label"])
	var hit_actor_ids: Dictionary = payload[&"hit_actor_ids"]
	var fork_angle_radians: float = float(payload[&"fork_angle_radians"])
	for angle_offset: float in [-fork_angle_radians * 0.5, fork_angle_radians * 0.5]:
		var fork := projectile_scene.instantiate() as Projectile
		if fork == null:
			continue
		parent.add_child(fork)
		fork.global_position = spawn_position + direction.rotated(angle_offset) * 10.0
		fork.setup(
			direction.rotated(angle_offset),
			damage_packet,
			resolved_speed,
			debug_enabled,
			debug_label,
			behavior
		)
		fork._hit_actor_ids = hit_actor_ids.duplicate()

func _redirect_to_chain_target(hit_actor: Node) -> bool:
	var target := _find_chain_target(hit_actor)
	if not is_instance_valid(target):
		return false
	_chain_remaining -= 1
	_direction = global_position.direction_to(target.global_position)
	if _direction.is_zero_approx():
		return false
	rotation = _direction.angle()
	global_position += _direction * 10.0
	return true

func _find_chain_target(hit_actor: Node) -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null

	var best_target: Node2D
	var best_distance_squared := _chain_radius * _chain_radius
	for candidate_node in tree.get_nodes_in_group(_target_group):
		var candidate := candidate_node as Node2D
		if not is_instance_valid(candidate):
			continue
		if candidate == hit_actor:
			continue
		if _hit_actor_ids.has(candidate.get_instance_id()):
			continue
		var distance_squared := global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared <= best_distance_squared:
			best_distance_squared = distance_squared
			best_target = candidate
	return best_target

func _make_child_behavior() -> Dictionary:
	return {
		&"projectile_scene": _projectile_scene,
		&"target_group": _target_group,
		&"damage_modifiers": _get_child_damage_modifiers(),
		&"pierce": _pierce_remaining,
		&"fork": maxi(_fork_remaining - 1, 0),
		&"fork_angle_degrees": rad_to_deg(_fork_angle_radians),
		&"fork_damage_multiplier": _fork_damage_multiplier,
		&"chain": _chain_remaining,
		&"chain_radius": _chain_radius,
		&"slow_chance": _slow_chance,
		&"slow_magnitude": _slow_magnitude,
		&"slow_duration": _slow_duration
	}

func _get_child_damage_modifiers() -> Array[StatModifier]:
	var modifiers := _damage_modifiers.duplicate()
	modifiers.append(_make_more_damage_modifier((_fork_damage_multiplier - 1.0) * 100.0))
	return modifiers

func _make_more_damage_modifier(value: float) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = StatIds.DAMAGE
	modifier.operation = StatModifier.Operation.MORE
	modifier.value = value
	modifier.scope = StatModifier.Scope.LOCAL
	modifier.target_domain = &"weapon"
	modifier.required_all_tags = [&"forked"]
	return modifier

func _try_apply_slow(actor: Node) -> void:
	if (
		not is_instance_valid(actor)
		or _slow_chance <= 0.0
		or _slow_magnitude <= 0.0
		or _slow_duration <= 0.0
		or randf() * 100.0 > _slow_chance
	):
		return
	var statuses := actor.get_node_or_null("StatusEffectComponent") as StatusEffectComponent
	if is_instance_valid(statuses):
		statuses.apply_slow(_slow_magnitude, _slow_duration)

func _despawn() -> void:
	if _despawn_requested:
		return
	_despawn_requested = true
	set_physics_process(false)
	visible = false
	if _pooled_recycle_enabled:
		recycle_requested.emit(self)
	else:
		queue_free()
