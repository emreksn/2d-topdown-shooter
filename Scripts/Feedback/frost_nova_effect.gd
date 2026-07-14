class_name FrostNovaEffect
extends Node2D

@export_range(0.05, 2.0, 0.05) var duration: float = 0.45
@export var core_color := Color(0.72, 0.95, 1.0, 0.34)
@export var ring_color := Color(0.42, 0.86, 1.0, 0.95)
@export var crack_color := Color(0.86, 0.98, 1.0, 0.78)

var radius: float = 260.0
var _elapsed: float = 0.0

func play(resolved_radius: float) -> void:
	radius = maxf(resolved_radius, 1.0)
	_elapsed = 0.0
	scale = Vector2.ONE
	modulate.a = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, duration)
	queue_redraw()
	if _elapsed >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var current_radius := lerpf(radius * 0.18, radius, eased)
	var fade := 1.0 - progress
	var pulse := 1.0 + sin(progress * PI) * 0.12

	draw_circle(
		Vector2.ZERO,
		current_radius * 0.42 * pulse,
		Color(core_color, core_color.a * fade)
	)
	draw_arc(
		Vector2.ZERO,
		current_radius,
		0.0,
		TAU,
		96,
		Color(ring_color, ring_color.a * fade),
		5.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		current_radius * 0.68,
		0.0,
		TAU,
		72,
		Color(ring_color, ring_color.a * fade * 0.55),
		2.0,
		true
	)

	for index: int in range(12):
		var angle := TAU * float(index) / 12.0
		var inner := Vector2.RIGHT.rotated(angle) * current_radius * 0.34
		var outer := Vector2.RIGHT.rotated(angle + sin(float(index)) * 0.08) * current_radius
		draw_line(
			inner,
			outer,
			Color(crack_color, crack_color.a * fade),
			2.0,
			true
		)
