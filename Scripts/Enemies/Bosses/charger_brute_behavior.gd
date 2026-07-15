class_name ChargerBruteBehavior
extends MovementBehavior

enum State {
	IDLE,
	WINDUP,
	CHARGING,
	RECOVERY
}

@export_range(0.0, 20.0, 0.05, "or_greater") var windup_duration: float = 1.1
@export_range(0.0, 20.0, 0.05, "or_greater") var charge_duration: float = 0.55
@export_range(0.0, 20.0, 0.05, "or_greater") var recovery_duration: float = 1.2
@export_range(0.0, 60.0, 0.05, "or_greater") var charge_cooldown: float = 3.5
@export_range(0.0, 5000.0, 1.0, "or_greater") var charge_distance: float = 520.0
@export_range(1.0, 20.0, 0.1, "or_greater") var charge_speed_multiplier: float = 6.5
@export_range(0.0, 1000.0, 1.0, "or_greater") var stopping_distance: float = 80.0
@export var telegraph_path: NodePath
@export var windup_color := Color(1.0, 0.35, 0.18, 1.0)

var state: State = State.IDLE
var _state_remaining: float = 0.0
var _cooldown_remaining: float = 1.0
var _charge_direction := Vector2.RIGHT
var _charge_distance_remaining: float = 0.0
var _base_modulate := Color.WHITE
var _telegraph: Line2D
var _actor: CharacterBody2D

func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	if is_instance_valid(_actor):
		_base_modulate = _actor.modulate
	_resolve_telegraph()
	_set_telegraph_visible(false)

func get_movement_direction(
	actor: CharacterBody2D,
	target: Node2D,
	delta: float
) -> Vector2:
	_actor = actor
	_tick_state(actor, target, delta)
	match state:
		State.CHARGING:
			return _charge_direction
		State.IDLE:
			if not is_instance_valid(target):
				return Vector2.ZERO
			var offset := target.global_position - actor.global_position
			if offset.length_squared() <= stopping_distance * stopping_distance:
				return Vector2.ZERO
			return offset.normalized()
		_:
			return Vector2.ZERO

func get_speed_multiplier(
	_actor_arg: CharacterBody2D,
	_target: Node2D,
	_delta: float
) -> float:
	return charge_speed_multiplier if state == State.CHARGING else 1.0

func reset_for_pool_spawn() -> void:
	state = State.IDLE
	_state_remaining = 0.0
	_cooldown_remaining = 1.0
	_charge_direction = Vector2.RIGHT
	_charge_distance_remaining = 0.0
	if is_instance_valid(_actor):
		_actor.modulate = _base_modulate
	_set_telegraph_visible(false)

func _tick_state(actor: CharacterBody2D, target: Node2D, delta: float) -> void:
	match state:
		State.IDLE:
			_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
			if _cooldown_remaining <= 0.0 and is_instance_valid(target):
				_begin_windup(actor, target)
		State.WINDUP:
			_state_remaining = maxf(_state_remaining - delta, 0.0)
			if _state_remaining <= 0.0:
				_begin_charge()
		State.CHARGING:
			var speed := _get_actor_speed(actor) * charge_speed_multiplier
			_charge_distance_remaining -= speed * delta
			_state_remaining = maxf(_state_remaining - delta, 0.0)
			if _state_remaining <= 0.0 or _charge_distance_remaining <= 0.0:
				_begin_recovery()
		State.RECOVERY:
			_state_remaining = maxf(_state_remaining - delta, 0.0)
			if _state_remaining <= 0.0:
				_begin_idle()

func _begin_windup(actor: CharacterBody2D, target: Node2D) -> void:
	state = State.WINDUP
	_state_remaining = windup_duration
	var direction := actor.global_position.direction_to(target.global_position)
	_charge_direction = direction if not direction.is_zero_approx() else Vector2.RIGHT
	_charge_distance_remaining = charge_distance
	if is_instance_valid(actor):
		actor.modulate = windup_color
	_update_telegraph()
	_set_telegraph_visible(true)

func _begin_charge() -> void:
	state = State.CHARGING
	_state_remaining = charge_duration
	_set_telegraph_visible(false)

func _begin_recovery() -> void:
	state = State.RECOVERY
	_state_remaining = recovery_duration
	if is_instance_valid(_actor):
		_actor.modulate = _base_modulate.lerp(windup_color, 0.25)
	_set_telegraph_visible(false)

func _begin_idle() -> void:
	state = State.IDLE
	_cooldown_remaining = charge_cooldown
	if is_instance_valid(_actor):
		_actor.modulate = _base_modulate
	_set_telegraph_visible(false)

func _get_actor_speed(actor: CharacterBody2D) -> float:
	if actor == null:
		return 0.0
	var enemy := actor as Enemy
	if enemy != null and is_instance_valid(enemy.stat_component):
		return enemy.stat_component.get_stat(StatIds.MOVEMENT_SPEED, enemy.spawn_tags)
	return 0.0

func _resolve_telegraph() -> void:
	if not String(telegraph_path).is_empty():
		_telegraph = get_node_or_null(telegraph_path) as Line2D
	if _telegraph == null and get_parent() != null:
		_telegraph = get_parent().get_node_or_null("ChargeTelegraph") as Line2D

func _update_telegraph() -> void:
	_resolve_telegraph()
	if _telegraph == null:
		return
	_telegraph.points = PackedVector2Array([
		Vector2.ZERO,
		_charge_direction.normalized() * charge_distance
	])

func _set_telegraph_visible(is_visible: bool) -> void:
	_resolve_telegraph()
	if _telegraph != null:
		_telegraph.visible = is_visible
