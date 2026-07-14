class_name DamageNumber
extends Node2D

@export_range(0.1, 3.0, 0.05) var duration: float = 0.65
@export_range(0.0, 200.0, 1.0) var rise_distance: float = 48.0
@export_range(0.0, 100.0, 1.0) var horizontal_scatter: float = 18.0

@onready var label: Label = $Label

func display(
	amount: float,
	color: Color = Color.WHITE,
	size_multiplier: float = 1.0
) -> void:
	_play_text(
		str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount,
		color,
		size_multiplier
	)

func display_text(
	text: String,
	color: Color = Color.WHITE,
	size_multiplier: float = 1.0
) -> void:
	_play_text(text, color, size_multiplier)

func _play_text(
	text: String,
	color: Color,
	size_multiplier: float
) -> void:
	label.text = text
	label.modulate = color
	scale = Vector2.ONE * size_multiplier

	var drift := Vector2(
		randf_range(-horizontal_scatter, horizontal_scatter),
		-rise_distance
	)
	var target_scale := Vector2.ONE * size_multiplier * 1.15
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + drift, duration)
	tween.tween_property(self, "scale", target_scale, duration * 0.35)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(duration * 0.35)
	tween.chain().tween_callback(queue_free)
