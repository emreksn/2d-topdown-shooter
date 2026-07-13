class_name ArenaCamera2D
extends Camera2D

@export var target: Node2D
@export var arena_bounds := Rect2(-800.0, -500.0, 1600.0, 1000.0)
@export_range(0.0, 30.0, 0.5) var follow_speed: float = 8.0
@export var minimum_zoom := Vector2(0.7, 0.7)

var _base_zoom := Vector2.ONE

func _ready() -> void:
	if not is_instance_valid(target):
		target = get_parent() as Node2D
	_base_zoom = zoom
	minimum_zoom = minimum_zoom.max(_base_zoom)
	top_level = true
	position_smoothing_enabled = false
	_update_camera_shape()
	make_current()
	if is_instance_valid(target):
		global_position = _clamp_camera_center(target.global_position)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired_position := _clamp_camera_center(target.global_position)
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, weight)

func _on_viewport_size_changed() -> void:
	_update_camera_shape()
	if is_instance_valid(target):
		global_position = _clamp_camera_center(target.global_position)

func _update_camera_shape() -> void:
	zoom = _get_safe_zoom()
	limit_left = floori(arena_bounds.position.x)
	limit_top = floori(arena_bounds.position.y)
	limit_right = ceili(arena_bounds.end.x)
	limit_bottom = ceili(arena_bounds.end.y)

func _get_safe_zoom() -> Vector2:
	if arena_bounds.size.x <= 0.0 or arena_bounds.size.y <= 0.0:
		return minimum_zoom
	var viewport_size := get_viewport_rect().size
	var required_zoom := Vector2(
		viewport_size.x / arena_bounds.size.x,
		viewport_size.y / arena_bounds.size.y
	)
	return minimum_zoom.max(required_zoom)

func _clamp_camera_center(center: Vector2) -> Vector2:
	if arena_bounds.size.x <= 0.0 or arena_bounds.size.y <= 0.0:
		return center

	var half_view := _get_world_view_size() * 0.5
	var result := center
	if half_view.x >= arena_bounds.size.x * 0.5:
		result.x = arena_bounds.get_center().x
	else:
		result.x = clampf(
			result.x,
			arena_bounds.position.x + half_view.x,
			arena_bounds.end.x - half_view.x
		)
	if half_view.y >= arena_bounds.size.y * 0.5:
		result.y = arena_bounds.get_center().y
	else:
		result.y = clampf(
			result.y,
			arena_bounds.position.y + half_view.y,
			arena_bounds.end.y - half_view.y
		)
	return result

func _get_world_view_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		viewport_size.x / maxf(zoom.x, 0.001),
		viewport_size.y / maxf(zoom.y, 0.001)
	)
