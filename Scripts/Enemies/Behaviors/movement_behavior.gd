class_name MovementBehavior
extends Node

func get_movement_direction(
	_actor: CharacterBody2D,
	_target: Node2D,
	_delta: float
) -> Vector2:
	return Vector2.ZERO
