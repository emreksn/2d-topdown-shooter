class_name TargetingComponent
extends Node

signal target_changed(new_target: Node2D)

@export var target_group: StringName = &"player"
@export_range(0.0, 60.0, 0.05, "or_greater") var refresh_interval: float = 0.25

var _target: Node2D
var _refresh_time_remaining: float = 0.0

func _ready() -> void:
	_acquire_target()

func _process(delta: float) -> void:
	_refresh_time_remaining -= delta
	if _refresh_time_remaining <= 0.0:
		_refresh_time_remaining = refresh_interval
		_acquire_target()

func get_target() -> Node2D:
	if not is_instance_valid(_target):
		_acquire_target()
	return _target

func set_target(new_target: Node2D) -> void:
	if _target == new_target:
		return

	_target = new_target
	target_changed.emit(_target)

func clear_target() -> void:
	set_target(null)

func _acquire_target() -> void:
	var origin := get_parent() as Node2D
	if not is_instance_valid(origin):
		clear_target()
		return

	var nearest_target: Node2D
	var nearest_distance_squared := INF

	for candidate_node in get_tree().get_nodes_in_group(target_group):
		var candidate := candidate_node as Node2D
		if not is_instance_valid(candidate):
			continue

		var distance_squared := origin.global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = candidate

	set_target(nearest_target)
