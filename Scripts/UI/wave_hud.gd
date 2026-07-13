class_name WaveHUD
extends CanvasLayer

@export var wave_director: WaveDirector

@onready var wave_label: Label = %WaveLabel
@onready var timer_label: Label = %TimerLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	if not is_instance_valid(wave_director):
		wave_director = _find_wave_director()

	if not is_instance_valid(wave_director):
		push_warning("WaveHUD has no WaveDirector.")
		return

	wave_director.preparation_started.connect(_on_preparation_started)
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.wave_completed.connect(_on_wave_completed)
	wave_director.shop_started.connect(_on_shop_started)
	wave_director.wave_time_changed.connect(_on_wave_time_changed)
	wave_director.remaining_enemies_changed.connect(_on_remaining_enemies_changed)
	wave_director.run_completed.connect(_on_run_completed)

func _find_wave_director() -> WaveDirector:
	var nodes := get_tree().get_nodes_in_group(&"wave_director")
	if not nodes.is_empty():
		return nodes.front() as WaveDirector
	return null

func _on_preparation_started(next_wave_number: int, _duration: float) -> void:
	wave_label.text = "NEXT WAVE %d" % next_wave_number
	status_label.text = "PREPARATION"

func _on_wave_started(wave_number: int, _definition: WaveDefinition) -> void:
	wave_label.text = "WAVE %d" % wave_number
	status_label.text = "WAVE ACTIVE"

func _on_wave_completed(wave_number: int) -> void:
	status_label.text = "WAVE %d CLEARED" % wave_number

func _on_shop_started(_completed_wave_number: int, next_wave_number: int) -> void:
	wave_label.text = "SHOP"
	status_label.text = "PREPARE FOR WAVE %d" % next_wave_number

func _on_wave_time_changed(remaining: float) -> void:
	timer_label.text = "%02d" % ceili(remaining)

func _on_remaining_enemies_changed(count: int) -> void:
	enemies_label.text = "ENEMIES: %d" % count

func _on_run_completed() -> void:
	status_label.text = "RUN COMPLETE"
