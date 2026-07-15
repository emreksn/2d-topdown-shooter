class_name BossDirector
extends Node

signal boss_spawned(boss: Enemy)

@export var wave_director: WaveDirector
@export var spawn_director: SpawnDirector
@export var default_boss_entry: EnemySpawnEntry
@export_range(1, 1000, 1, "or_greater") var milestone_interval: int = 10
@export_range(0, 20, 1) var default_boss_spawn_count: int = 1
@export_range(0.0, 60.0, 0.1, "or_greater") var default_spawn_delay: float = 2.0
@export_range(0.0, 10.0, 0.1, "or_greater") var default_warning_duration: float = 1.25
@export_range(0.0, 1000.0, 0.5, "or_greater") var default_reward_multiplier: float = 20.0

var _wave_token: int = 0
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	call_deferred("_initialize")

func _initialize() -> void:
	if not is_instance_valid(wave_director):
		wave_director = get_tree().get_first_node_in_group(
			&"wave_director"
		) as WaveDirector
	if not is_instance_valid(spawn_director):
		spawn_director = get_node_or_null("../SpawnDirector") as SpawnDirector
	if is_instance_valid(wave_director):
		wave_director.wave_started.connect(_on_wave_started)
	else:
		push_warning("BossDirector has no WaveDirector.")
	if not is_instance_valid(spawn_director):
		push_warning("BossDirector has no SpawnDirector.")
	elif not spawn_director.enemy_spawned.is_connected(_on_enemy_spawned):
		spawn_director.enemy_spawned.connect(_on_enemy_spawned)

func _on_wave_started(wave_number: int, definition: WaveDefinition) -> void:
	_wave_token += 1
	if definition == null or not is_instance_valid(spawn_director):
		return
	var spawn_count := _get_boss_spawn_count(wave_number, definition)
	if spawn_count <= 0:
		return
	_schedule_bosses(wave_number, definition, spawn_count, _wave_token)

func _get_boss_spawn_count(wave_number: int, definition: WaveDefinition) -> int:
	var content_count := maxi(definition.boss_spawn_count, 0)
	if _is_milestone_wave(wave_number):
		return maxi(default_boss_spawn_count, 1)
	return content_count

func _is_milestone_wave(wave_number: int) -> bool:
	return milestone_interval > 0 and wave_number > 0 and wave_number % milestone_interval == 0

func _schedule_bosses(
	wave_number: int,
	definition: WaveDefinition,
	spawn_count: int,
	token: int
) -> void:
	var delay := (
		definition.boss_spawn_delay
		if definition.boss_spawn_delay > 0.0
		else default_spawn_delay
	)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if token != _wave_token:
		return
	for index: int in range(spawn_count):
		_spawn_boss(wave_number, definition, index)

func _spawn_boss(
	wave_number: int,
	definition: WaveDefinition,
	index: int
) -> void:
	var entry := definition.boss_entry if definition.boss_entry != null else default_boss_entry
	if entry == null:
		push_warning("BossDirector has no boss entry.")
		return
	var warning_duration := (
		definition.boss_warning_duration
		if definition.boss_warning_duration > 0.0
		else default_warning_duration
	)
	var reward_multiplier := (
		definition.boss_reward_multiplier
		if definition.boss_reward_multiplier > 0.0
		else default_reward_multiplier
	)
	var spawn_position := spawn_director.get_bonus_spawn_position(160.0 + float(index) * 40.0)
	var tags: Array[StringName] = [&"boss"]
	if _is_milestone_wave(wave_number):
		tags.append(&"milestone_boss")
	else:
		tags.append(&"content_boss")
	var rarity_roll := spawn_director.build_specific_monster_rarity_roll(
		SpawnDirector.MONSTER_RARITY_RARE
	)
	spawn_director.spawn_bonus_enemy(
		entry,
		spawn_position,
		tags,
		warning_duration,
		rarity_roll,
		reward_multiplier
	)

func _on_enemy_spawned(enemy_node: Node2D) -> void:
	var enemy := enemy_node as Enemy
	if enemy != null and enemy.spawn_tags.has(&"boss"):
		boss_spawned.emit(enemy)
