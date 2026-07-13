class_name SpawnIndicator
extends Node2D

@export var fill_color := Color(0.95, 0.18, 0.12, 0.2)
@export var ring_color := Color(1.0, 0.3, 0.18, 0.95)
@export_range(1.0, 200.0, 1.0) var radius: float = 24.0
@export_range(1.0, 12.0, 0.5) var ring_width: float = 3.0

var _duration: float = 1.5
var _elapsed: float = 0.0

func configure(duration: float) -> void:
	_duration = maxf(duration, 0.001)
	_elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, _duration)
	var progress := _elapsed / _duration
	var pulse := 0.92 + sin(_elapsed * 12.0) * 0.08
	scale = Vector2.ONE * pulse
	modulate.a = lerpf(0.55, 1.0, progress)
	queue_redraw()

func _draw() -> void:
	var progress := _elapsed / _duration
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(
		Vector2.ZERO,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		48,
		ring_color,
		ring_width,
		true
	)
