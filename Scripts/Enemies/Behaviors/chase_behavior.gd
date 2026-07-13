class_name ChaseBehavior
extends MovementBehavior

@export_range(0.0, 10000.0, 1.0, "or_greater") var stopping_distance: float = 0.0

func get_movement_direction(
	actor: CharacterBody2D,
	target: Node2D,
	_delta: float
) -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO

	var offset := target.global_position - actor.global_position
	if offset.length_squared() <= stopping_distance * stopping_distance:
		return Vector2.ZERO

	return offset.normalized()
