extends SceneTree

func _initialize() -> void:
	var director := WaveDirector.new()
	director.monster_base_health_increase_per_wave = 10.0
	director.wave_definitions = [
		WaveDefinition.new(),
		WaveDefinition.new(),
		WaveDefinition.new()
	]

	if not _assert_wave_multiplier(director, 1, 1.0):
		return
	if not _assert_wave_multiplier(director, 3, 1.2):
		return
	if not _assert_wave_multiplier(director, 4, 1.3):
		return
	if not await _assert_spawned_health_stacks_from_scaled_base(director):
		return
	if not await _assert_natural_wave_defenses():
		return

	director.free()
	print("wave_health_scaling_smoke_test: PASS")
	quit(0)

func _assert_wave_multiplier(
	director: WaveDirector,
	wave_number: int,
	expected_multiplier: float
) -> bool:
	var definition := director._get_prepared_definition_for_wave(wave_number)
	if definition == null:
		return _fail("Wave %d did not produce a prepared definition." % wave_number)
	if not is_equal_approx(
		definition.monster_base_health_multiplier,
		expected_multiplier
	):
		return _fail(
			"Wave %d expected %.2fx base health, got %.2fx."
			% [
				wave_number,
				expected_multiplier,
				definition.monster_base_health_multiplier
			]
		)
	return true

func _assert_spawned_health_stacks_from_scaled_base(
	director: WaveDirector
) -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemies := Node2D.new()
	world.add_child(enemies)

	var spawn_director := SpawnDirector.new()
	spawn_director.enemy_container = enemies
	spawn_director.forced_monster_rarity = SpawnDirector.MONSTER_RARITY_NORMAL
	world.add_child(spawn_director)

	var entry := load(
		"res://Data/Waves/Enemies/chasing_enemy_entry.tres"
	) as EnemySpawnEntry
	var bountiful := load(
		"res://Data/Content/Variants/bountiful.tres"
	) as ContentVariantDefinition
	var definition := director._get_prepared_definition_for_wave(3)
	definition.enemy_pool = [entry]
	definition.monster_modifier_sets.append(bountiful.inherent_modifier_set)

	spawn_director.begin_wave(definition, 3)
	spawn_director.spawn_bonus_enemy(entry, Vector2.ZERO, [&"rift"])
	await process_frame

	if enemies.get_child_count() != 1:
		return _fail("Expected one spawned enemy for wave health scaling test.")
	var enemy := enemies.get_child(0) as Enemy
	var stats := enemy.get_node("StatComponent") as StatComponent
	var health := enemy.get_node("HealthComponent") as HealthComponent

	if not is_equal_approx(stats.get_base_stat(StatIds.MAXIMUM_HEALTH), 108.0):
		return _fail("Wave scaling did not rewrite spawned enemy base health.")
	if not is_equal_approx(health.maximum_health, 135.0):
		return _fail("Increased health did not multiply wave-scaled base health.")
	if not is_equal_approx(health.current_health, 135.0):
		return _fail("Spawned enemy did not fill to wave-scaled maximum health.")

	world.queue_free()
	await process_frame
	current_scene = null
	return true

func _assert_natural_wave_defenses() -> bool:
	var wave_expectations := {
		4: [0.0, 0.0],
		5: [25.0, 0.0],
		10: [50.0, 10.0],
		40: [200.0, 40.0]
	}
	for wave_number in wave_expectations:
		var expected: Array = wave_expectations[wave_number]
		var enemy := await _spawn_wave_defense_enemy(int(wave_number))
		if enemy == null:
			return false
		var stats := enemy.get_node("StatComponent") as StatComponent
		var rating := float(expected[0])
		var resistance := float(expected[1])
		if not is_equal_approx(stats.get_stat(StatIds.ARMOUR), rating):
			return _fail("Wave %d natural armour expected %.1f." % [wave_number, rating])
		if not is_equal_approx(stats.get_stat(StatIds.EVASION), rating):
			return _fail("Wave %d natural evasion expected %.1f." % [wave_number, rating])
		if not is_equal_approx(stats.get_stat(StatIds.PHYSICAL_RESISTANCE), resistance):
			return _fail("Wave %d natural physical resistance expected %.1f." % [wave_number, resistance])
		if not is_equal_approx(stats.get_stat(StatIds.ELEMENTAL_RESISTANCE), resistance):
			return _fail("Wave %d natural elemental resistance expected %.1f." % [wave_number, resistance])
	return true

func _spawn_wave_defense_enemy(wave_number: int) -> Enemy:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemies := Node2D.new()
	world.add_child(enemies)

	var spawn_director := SpawnDirector.new()
	spawn_director.enemy_container = enemies
	spawn_director.forced_monster_rarity = SpawnDirector.MONSTER_RARITY_NORMAL
	world.add_child(spawn_director)

	var entry := load(
		"res://Data/Waves/Enemies/chasing_enemy_entry.tres"
	) as EnemySpawnEntry
	var definition := WaveDefinition.new()
	definition.enemy_pool = [entry]
	definition.spawn_budget = entry.cost
	definition.spawn_cutoff_before_end = 0.0

	spawn_director.begin_wave(definition, wave_number)
	spawn_director.spawn_bonus_enemy(entry, Vector2.ZERO)
	await process_frame

	if enemies.get_child_count() != 1:
		_fail("Expected one spawned enemy for wave defense test.")
		return null
	var enemy := enemies.get_child(0) as Enemy
	world.remove_child(enemies)
	root.add_child(enemies)
	world.queue_free()
	await process_frame
	return enemy

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
