class_name ContentDefinition
extends Resource

enum ContentKind {
	RIFT,
	BOSS
}

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: ContentKind = ContentKind.RIFT

@export_category("Rift")
@export_range(0, 20, 1) var rift_portal_count: int = 3
@export_range(1, 20, 1) var rift_monsters_per_portal: int = 3

@export_category("Boss")
@export var boss_entry: EnemySpawnEntry
@export_range(0, 10, 1) var boss_spawn_count: int = 1
@export_range(0.0, 60.0, 0.1, "or_greater") var boss_spawn_delay: float = 2.0
@export_range(0.0, 10.0, 0.1, "or_greater") var boss_warning_duration: float = 1.25
@export_range(0.0, 1000.0, 0.5, "or_greater") var boss_reward_multiplier: float = 20.0

func apply_to_wave(definition: WaveDefinition) -> void:
	if definition == null:
		return
	match kind:
		ContentKind.RIFT:
			definition.rift_portal_count += rift_portal_count
			definition.rift_monsters_per_portal = maxi(
				definition.rift_monsters_per_portal,
				rift_monsters_per_portal
			)
		ContentKind.BOSS:
			definition.boss_spawn_count = maxi(
				definition.boss_spawn_count,
				boss_spawn_count
			)
			if boss_entry != null:
				definition.boss_entry = boss_entry
			definition.boss_spawn_delay = boss_spawn_delay
			definition.boss_warning_duration = boss_warning_duration
			definition.boss_reward_multiplier = boss_reward_multiplier
