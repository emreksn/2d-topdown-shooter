class_name WanderBehavior
extends MovementBehavior

@export_range(0.0, 20.0, 0.1) var minimum_wander_time: float = 1.0
@export_range(0.0, 20.0, 0.1) var maximum_wander_time: float = 3.0
@export_range(0.0, 20.0, 0.1) var minimum_pause_time: float = 0.25
@export_range(0.0, 20.0, 0.1) var maximum_pause_time: float = 1.0
@export_range(32.0, 2000.0, 8.0) var player_perimeter_radius: float = 340.0
@export_range(8.0, 1000.0, 8.0) var perimeter_band: float = 110.0
@export_range(0.0, 4.0, 0.05) var radial_correction_strength: float = 1.25

var _random := RandomNumberGenerator.new()
var _direction := Vector2.ZERO
var _time_remaining: float = 0.0
var _is_wandering: bool = false

func _ready() -> void:
	_random.randomize()

func get_movement_direction(
	actor: CharacterBody2D,
	target: Node2D,
	delta: float
) -> Vector2:
	_time_remaining -= delta

	if _time_remaining <= 0.0:
		if _is_wandering:
			_begin_pause()
		else:
			_begin_wander()

	if is_instance_valid(actor) and is_instance_valid(target) and _is_wandering:
		return _get_perimeter_direction(actor, target)
	return _direction

func _begin_wander() -> void:
	_is_wandering = true
	_direction = Vector2.from_angle(_random.randf_range(0.0, TAU))
	_time_remaining = _random.randf_range(
		minf(minimum_wander_time, maximum_wander_time),
		maxf(minimum_wander_time, maximum_wander_time)
	)

func _begin_pause() -> void:
	_is_wandering = false
	_direction = Vector2.ZERO
	_time_remaining = _random.randf_range(
		minf(minimum_pause_time, maximum_pause_time),
		maxf(minimum_pause_time, maximum_pause_time)
	)

func _get_perimeter_direction(actor: CharacterBody2D, target: Node2D) -> Vector2:
	var from_player := actor.global_position - target.global_position
	if from_player.is_zero_approx():
		from_player = Vector2.RIGHT.rotated(_random.randf_range(0.0, TAU))
	var distance := from_player.length()
	var radial := from_player / maxf(distance, 0.001)
	var tangent := radial.orthogonal()
	if _direction.dot(tangent) < 0.0:
		tangent = -tangent

	var desired_offset := distance - player_perimeter_radius
	var correction := Vector2.ZERO
	if absf(desired_offset) > perimeter_band * 0.35:
		correction = -radial * signf(desired_offset) * radial_correction_strength

	return (tangent + correction).normalized()
