class_name PlayerProgressionHUD
extends Control

@export var progression: PlayerProgressionComponent

@onready var gold_label: Label = %GoldLabel
@onready var experience_bar: ProgressBar = %ExperienceBar
@onready var experience_label: Label = %ExperienceLabel

func _ready() -> void:
	UiPresentation.apply_heading(gold_label, 16)
	gold_label.add_theme_color_override("font_color", UiPresentation.GOLD)
	UiPresentation.apply_body_label(experience_label, false, 12)
	UiPresentation.apply_progress_bar_style(experience_bar, Color(0.28, 0.62, 1.0, 1.0))
	if not is_instance_valid(progression):
		progression = _find_progression()
	if not is_instance_valid(progression):
		push_warning("PlayerProgressionHUD has no PlayerProgressionComponent.")
		return

	progression.gold_changed.connect(_on_gold_changed)
	progression.experience_changed.connect(_on_experience_changed)
	_on_gold_changed(progression.gold)
	_on_experience_changed(
		progression.experience,
		progression.experience_to_next_level,
		progression.level
	)

func _find_progression() -> PlayerProgressionComponent:
	var player := get_parent().get_parent()
	if player == null:
		return null
	return player.get_node_or_null(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent

func _on_gold_changed(total_gold: int) -> void:
	gold_label.text = "GOLD  %d" % total_gold

func _on_experience_changed(
	current_experience: float,
	experience_to_next_level: float,
	level: int
) -> void:
	experience_bar.max_value = experience_to_next_level
	experience_bar.value = current_experience
	experience_label.text = "LV %d    XP %d / %d" % [
		level,
		floori(current_experience),
		ceili(experience_to_next_level)
	]
