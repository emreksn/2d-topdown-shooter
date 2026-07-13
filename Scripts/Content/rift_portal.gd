class_name RiftPortal
extends Node2D

signal finished

@export_range(0.0, 10.0, 0.1) var opening_duration: float = 0.7
@export_range(0.0, 10.0, 0.1) var spawn_interval: float = 0.25
@export_range(0.0, 10.0, 0.1) var spawn_warning_duration: float = 0.65
@export_range(0.0, 10.0, 0.1) var closing_duration: float = 0.45
@export_range(0.0, 300.0, 1.0) var monster_spread: float = 58.0

@onready var sprite: Sprite2D = $Sprite2D

var _spawn_director: SpawnDirector
var _entries: Array[EnemySpawnEntry] = []
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	scale = Vector2.ZERO

func activate(
	spawn_director: SpawnDirector,
	entries: Array[EnemySpawnEntry]
) -> void:
	_spawn_director = spawn_director
	_entries = entries
	_run()

func _run() -> void:
	var opening := create_tween()
	opening.set_trans(Tween.TRANS_BACK)
	opening.set_ease(Tween.EASE_OUT)
	opening.tween_property(self, "scale", Vector2.ONE, opening_duration)
	await opening.finished

	for entry in _entries:
		if is_instance_valid(_spawn_director) and entry != null:
			var offset := Vector2.from_angle(
				_random.randf_range(0.0, TAU)
			) * _random.randf_range(12.0, monster_spread)
			_spawn_director.spawn_bonus_enemy(
				entry,
				global_position + offset,
				[&"rift"],
				spawn_warning_duration
			)
		if spawn_interval > 0.0:
			await get_tree().create_timer(spawn_interval).timeout

	if spawn_warning_duration > 0.0:
		await get_tree().create_timer(spawn_warning_duration).timeout

	var closing := create_tween()
	closing.set_trans(Tween.TRANS_BACK)
	closing.set_ease(Tween.EASE_IN)
	closing.tween_property(self, "scale", Vector2.ZERO, closing_duration)
	await closing.finished
	finished.emit()
	queue_free()
