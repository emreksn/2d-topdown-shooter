class_name EnemySpawnEntry
extends Resource

@export var enemy_scene: PackedScene
@export_range(1, 1000000, 1, "or_greater") var cost: int = 1
@export_range(0.0, 1000.0, 0.05, "or_greater") var weight: float = 1.0
@export_range(1, 1000000, 1, "or_greater") var minimum_wave: int = 1
@export var tags: Array[StringName] = []

func is_available(wave_number: int, remaining_budget: int) -> bool:
	return (
		enemy_scene != null
		and weight > 0.0
		and wave_number >= minimum_wave
		and cost <= remaining_budget
	)
