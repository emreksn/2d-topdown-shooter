class_name RangedRingBehavior
extends MovementBehavior

@export_range(32.0, 2000.0, 8.0) var minimum_attack_range: float = 260.0
@export_range(32.0, 2000.0, 8.0) var maximum_attack_range: float = 420.0

func get_movement_direction(
	actor: CharacterBody2D,
	target: Node2D,
	_delta: float
) -> Vector2:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return Vector2.ZERO

	var attack := _find_ranged_attack(actor)
	if attack != null and attack.is_charging():
		return Vector2.ZERO

	var offset := target.global_position - actor.global_position
	var distance := offset.length()
	if distance <= 0.001:
		return Vector2.RIGHT

	if distance > maximum_attack_range:
		return offset / distance
	if distance < minimum_attack_range:
		return -offset / distance
	return Vector2.ZERO

func is_in_attack_ring(actor: Node2D, target: Node2D) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return false
	var distance_squared := actor.global_position.distance_squared_to(
		target.global_position
	)
	return (
		distance_squared >= minimum_attack_range * minimum_attack_range
		and distance_squared <= maximum_attack_range * maximum_attack_range
	)

func _find_ranged_attack(actor: Node) -> RangedAttackComponent:
	for child in actor.get_children():
		if child is RangedAttackComponent:
			return child
	return null
