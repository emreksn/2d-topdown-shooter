class_name WaveDefinition
extends Resource

@export_range(1.0, 3600.0, 1.0, "or_greater") var duration: float = 30.0
@export_range(1, 1000000, 1, "or_greater") var spawn_budget: int = 20
@export_range(0.0, 10.0, 0.1, "or_greater") var spawn_warning_duration: float = 1.5
@export var enemy_pool: Array[EnemySpawnEntry] = []
@export var context_tags: Array[StringName] = []
@export var monster_modifier_sets: Array[ModifierSet] = []
@export_range(0.0, 1000.0, 0.01, "or_greater") var monster_base_health_multiplier: float = 1.0
@export_range(0.0, 3600.0, 0.5) var spawn_cutoff_before_end: float = 5.0
@export_range(1.0, 120.0, 0.5, "or_greater") var spawn_window_duration: float = 5.0

@export_category("Rift")
@export_range(0, 20, 1) var rift_portal_count: int = 0
@export_range(1, 20, 1) var rift_monsters_per_portal: int = 3

@export_category("Packs")
@export_range(1, 100, 1, "or_greater") var minimum_pack_size: int = 2
@export_range(1, 100, 1, "or_greater") var maximum_pack_size: int = 4
@export_range(0.0, 1000.0, 1.0, "or_greater") var pack_spread: float = 70.0
@export var mix_enemy_types_within_pack: bool = false
