extends SceneTree

func _initialize() -> void:
	if not await _test_forced_rarity_packages():
		return
	if not _test_rarity_chance_gates_and_multiplier():
		return
	if not _test_budgeted_natural_rarity_and_player_upgrade():
		return
	if not _test_rare_modifier_counts():
		return
	print("monster_rarity_smoke_test: PASS")
	quit(0)

func _test_forced_rarity_packages() -> bool:
	var normal := await _spawn_forced_enemy(1, SpawnDirector.MONSTER_RARITY_NORMAL)
	if normal == null:
		return false
	if not normal.spawn_tags.has(&"normal"):
		return _fail("Normal monster did not receive normal tag.")
	if normal.monster_rarity != Enemy.MonsterRarity.NORMAL:
		return _fail("Normal monster metadata is incorrect.")
	if not _expect_health(normal, 90.0, "normal health"):
		return false
	if not _expect_reward_multiplier(normal, 1.0, "normal reward multiplier"):
		return false

	var uncommon := await _spawn_forced_enemy(3, SpawnDirector.MONSTER_RARITY_UNCOMMON)
	if uncommon == null:
		return false
	if not uncommon.spawn_tags.has(&"uncommon"):
		return _fail("Uncommon monster did not receive uncommon tag.")
	if uncommon.get_inspection_name() != "Uncommon Chasing Enemy":
		return _fail("Uncommon inspection name is incorrect.")
	if not _expect_health(uncommon, 112.5, "uncommon health"):
		return false
	if not _expect_stat(uncommon, StatIds.ARMOUR, 50.0, "uncommon armour"):
		return false
	if not _expect_stat(uncommon, StatIds.EVASION, 50.0, "uncommon evasion"):
		return false
	if not _expect_stat(uncommon, StatIds.PHYSICAL_RESISTANCE, 15.0, "uncommon physical resistance"):
		return false
	if not _expect_stat(uncommon, StatIds.ELEMENTAL_RESISTANCE, 15.0, "uncommon elemental resistance"):
		return false
	if not _expect_reward_multiplier(uncommon, 1.35, "uncommon reward multiplier"):
		return false

	var rare := await _spawn_forced_enemy(
		13,
		SpawnDirector.MONSTER_RARITY_RARE,
		1,
		[&"armoured", &"armoured", &"elusive"]
	)
	if rare == null:
		return false
	if not rare.spawn_tags.has(&"rare"):
		return _fail("Rare monster did not receive rare tag.")
	if rare.get_inspection_name() != "Rare Chasing Enemy":
		return _fail("Rare inspection name is incorrect.")
	if rare.rare_modifier_names.size() != 1 or rare.rare_modifier_names[0] != "Armoured":
		return _fail("Rare forced duplicate modifier handling is incorrect.")
	if not _expect_health(rare, 135.0, "rare health"):
		return false
	if not _expect_stat(rare, StatIds.PHYSICAL_RESISTANCE, 25.0, "rare physical resistance"):
		return false
	if not _expect_stat(rare, StatIds.ELEMENTAL_RESISTANCE, 25.0, "rare elemental resistance"):
		return false
	if not _expect_stat(rare, StatIds.EVASION, 150.0, "rare evasion"):
		return false
	if not _expect_stat(rare, StatIds.ARMOUR, 300.0, "rare base armour plus natural and armoured modifier"):
		return false
	if not _expect_reward_multiplier(rare, 2.0, "rare reward multiplier"):
		return false

	var early_rare := await _spawn_forced_enemy(
		6,
		SpawnDirector.MONSTER_RARITY_RARE,
		0
	)
	if early_rare == null:
		return false
	if not early_rare.rare_modifier_names.is_empty():
		return _fail("Early rare monster should be able to roll zero modifiers.")
	return true

func _test_rarity_chance_gates_and_multiplier() -> bool:
	var director := SpawnDirector.new()
	root.add_child(director)
	director._wave_number = 2
	var chances := director.get_monster_rarity_chances()
	if not is_equal_approx(float(chances[&"uncommon"]), 0.0):
		return _fail("Uncommon chance should be zero before Wave 3.")
	director._wave_number = 5
	chances = director.get_monster_rarity_chances()
	if not is_equal_approx(float(chances[&"rare"]), 0.0):
		return _fail("Rare chance should be zero before Wave 6.")

	var player := Node2D.new()
	var stats := _make_stats({StatIds.MONSTER_RARITY_MULTIPLIER: 2.0})
	player.add_child(stats)
	root.add_child(player)
	director.spawn_focus = player
	director._wave_number = 6
	chances = director.get_monster_rarity_chances()
	if not is_equal_approx(float(chances[&"rare"]), 2.0):
		return _fail("Monster rarity multiplier should not change natural rare chance.")
	if not is_equal_approx(float(chances[&"upgrade_multiplier"]), 2.0):
		return _fail("Monster rarity multiplier should be exposed as an effective upgrade multiplier.")
	var upgrade_weights: Dictionary = chances[&"normal_upgrade_weights"]
	if not is_equal_approx(float(upgrade_weights[SpawnDirector.MONSTER_RARITY_NORMAL]), 70.0):
		return _fail("Monster rarity upgrade stay weight should match item rarity common weight.")
	if not is_equal_approx(float(upgrade_weights[SpawnDirector.MONSTER_RARITY_UNCOMMON]), 22.0):
		return _fail("Monster rarity upgrade uncommon weight should match item rarity uncommon weight.")
	if not is_equal_approx(float(upgrade_weights[SpawnDirector.MONSTER_RARITY_RARE]), 12.0):
		return _fail("Monster rarity upgrade rare weight should use rarity-index scaling.")
	player.queue_free()

	player = Node2D.new()
	player.add_child(_make_stats({StatIds.MONSTER_RARITY_MULTIPLIER: 99.0}))
	root.add_child(player)
	director.spawn_focus = player
	chances = director.get_monster_rarity_chances()
	if not is_equal_approx(float(chances[&"upgrade_multiplier"]), 3.0):
		return _fail("Monster rarity multiplier should use the same 3x effective cap as item rarity.")
	director.queue_free()
	player.queue_free()
	return true

func _test_budgeted_natural_rarity_and_player_upgrade() -> bool:
	var director := SpawnDirector.new()
	root.add_child(director)
	director._wave_number = 6
	director._enemy_pool = [
		load("res://Data/Waves/Enemies/wandering_enemy_entry.tres") as EnemySpawnEntry
	]
	director.forced_monster_rarity = SpawnDirector.MONSTER_RARITY_RARE
	var planned := director._plan_spawns_for_budget(10)
	if planned.size() != 2:
		return _fail("Rare natural budget cost should produce two 5x-cost spawns from budget 10.")
	for spawn in planned:
		var rarity_roll: Dictionary = spawn["rarity_roll"]
		if int(rarity_roll["rarity"]) != SpawnDirector.MONSTER_RARITY_RARE:
			return _fail("Forced rare natural spawn did not stay rare.")
		if int(spawn["budget_cost"]) != 5:
			return _fail("Rare natural spawn did not spend 5x budget.")

	director.forced_monster_rarity = SpawnDirector.MONSTER_RARITY_NORMAL
	director.forced_monster_rarity_upgrade = SpawnDirector.MONSTER_RARITY_RARE
	var player := Node2D.new()
	player.add_child(_make_stats({StatIds.MONSTER_RARITY_MULTIPLIER: 3.0}))
	root.add_child(player)
	director.spawn_focus = player
	planned = director._plan_spawns_for_budget(2)
	if planned.size() != 2:
		return _fail("Player rarity upgrades should not change budgeted spawn count.")
	for spawn in planned:
		var rarity_roll: Dictionary = spawn["rarity_roll"]
		if int(rarity_roll["rarity"]) != SpawnDirector.MONSTER_RARITY_RARE:
			return _fail("Player Monster Rarity upgrade pass should be able to upgrade normal spawns to rare.")
		if int(spawn["budget_cost"]) != 1:
			return _fail("Player rarity upgrade should not retroactively increase budget cost.")
	director.queue_free()
	player.queue_free()
	return true

func _test_rare_modifier_counts() -> bool:
	var director := SpawnDirector.new()
	root.add_child(director)
	director._wave_number = 13
	if director._roll_rare_modifier_count() != 1:
		return _fail("Wave 13 rare modifier count should be guaranteed 1.")
	director._wave_number = 22
	if director._roll_rare_modifier_count() != 2:
		return _fail("Wave 22 rare modifier count should be guaranteed 2.")
	director.queue_free()
	return true

func _spawn_forced_enemy(
	wave_number: int,
	rarity: int,
	rare_modifier_count: int = -1,
	rare_modifier_ids: Array[StringName] = []
) -> Enemy:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemies := Node2D.new()
	world.add_child(enemies)

	var director := SpawnDirector.new()
	director.enemy_container = enemies
	director.forced_monster_rarity = rarity
	director.forced_rare_modifier_count = rare_modifier_count
	director.forced_rare_modifier_ids = rare_modifier_ids
	world.add_child(director)

	var entry := load("res://Data/Waves/Enemies/chasing_enemy_entry.tres") as EnemySpawnEntry
	var definition := WaveDefinition.new()
	definition.enemy_pool = [entry]
	definition.spawn_budget = entry.cost
	definition.spawn_cutoff_before_end = 0.0
	director.begin_wave(definition, wave_number)
	director.spawn_bonus_enemy(entry, Vector2.ZERO)
	await process_frame

	if enemies.get_child_count() != 1:
		_fail("Forced rarity spawn did not create exactly one enemy.")
		return null
	var enemy := enemies.get_child(0) as Enemy
	return enemy

func _make_stats(values: Dictionary) -> StatComponent:
	var stats := StatComponent.new()
	stats.catalog = load("res://Data/Stats/stat_catalog.tres") as StatCatalog
	stats.domain = &"player"
	var profile := StatProfile.new()
	for stat_id in values:
		var entry := StatValue.new()
		entry.stat_id = stat_id
		entry.value = float(values[stat_id])
		profile.values.append(entry)
	stats.base_profile = profile
	return stats

func _expect_health(enemy: Enemy, expected: float, label: String) -> bool:
	var health := enemy.get_node("HealthComponent") as HealthComponent
	if not is_equal_approx(health.maximum_health, expected):
		return _fail("%s expected %f, got %f." % [label, expected, health.maximum_health])
	if not is_equal_approx(health.current_health, expected):
		return _fail("%s current expected %f, got %f." % [label, expected, health.current_health])
	return true

func _expect_stat(
	enemy: Enemy,
	stat_id: StringName,
	expected: float,
	label: String
) -> bool:
	var stats := enemy.get_node("StatComponent") as StatComponent
	var actual := stats.get_stat(stat_id)
	if not is_equal_approx(actual, expected):
		return _fail("%s expected %f, got %f." % [label, expected, actual])
	return true

func _expect_reward_multiplier(enemy: Enemy, expected: float, label: String) -> bool:
	var rewards := enemy.get_node("MonsterRewardComponent") as MonsterRewardComponent
	if not is_equal_approx(rewards.rarity_reward_multiplier, expected):
		return _fail(
			"%s expected %f, got %f."
			% [label, expected, rewards.rarity_reward_multiplier]
		)
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
