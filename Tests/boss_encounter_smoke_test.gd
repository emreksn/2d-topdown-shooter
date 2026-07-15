extends SceneTree

func _initialize() -> void:
	if not _test_content_offer_gating():
		return
	if not _test_boss_spawn_count_rules():
		return
	if not await _test_boss_spawn_tags_rewards_and_ui():
		return
	if not await _test_charger_brute_state_cycle():
		return
	print("boss_encounter_smoke_test: PASS")
	quit(0)

func _test_content_offer_gating() -> bool:
	var manager := ContentManager.new()
	manager.available_content = [
		load("res://Data/Content/rift.tres") as ContentDefinition,
		load("res://Data/Content/boss_encounter.tres") as ContentDefinition
	]
	manager.available_variants = []
	manager.available_extra_modifiers = []
	manager.offer_count = 4
	root.add_child(manager)

	manager.begin_selection(10)
	if _options_have_content(manager.current_options, &"boss_encounter"):
		return _fail("Boss content should not be offered before wave 11.")

	manager.begin_selection(11)
	if not _options_have_content(manager.current_options, &"boss_encounter"):
		return _fail("Boss content should be offered after completing wave 10.")

	manager.begin_selection(20)
	if _options_have_content(manager.current_options, &"boss_encounter"):
		return _fail("Boss content should be hidden on forced milestone waves.")

	var boss := load("res://Data/Content/boss_encounter.tres") as ContentDefinition
	var definition := WaveDefinition.new()
	boss.apply_to_wave(definition)
	if definition.boss_spawn_count != 1:
		return _fail("Boss content did not apply a boss spawn count.")
	if definition.boss_entry == null:
		return _fail("Boss content did not apply a boss entry.")

	manager.queue_free()
	return true

func _test_boss_spawn_count_rules() -> bool:
	var director := BossDirector.new()
	var definition := WaveDefinition.new()
	if director._get_boss_spawn_count(9, definition) != 0:
		return _fail("Wave 9 should not force a boss.")
	if director._get_boss_spawn_count(10, definition) != 1:
		return _fail("Wave 10 should force one boss.")
	definition.boss_spawn_count = 1
	if director._get_boss_spawn_count(11, definition) != 1:
		return _fail("Boss content should spawn one boss on non-milestone waves.")
	if director._get_boss_spawn_count(20, definition) != 1:
		return _fail("Boss content should not stack with milestone bosses.")
	return true

func _test_boss_spawn_tags_rewards_and_ui() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemies := Node2D.new()
	world.add_child(enemies)

	var director := SpawnDirector.new()
	director.enemy_container = enemies
	world.add_child(director)

	var ui := BossHealthBarUI.new()
	ui.spawn_director = director
	world.add_child(ui)

	var entry := load("res://Data/Waves/Enemies/charger_brute_boss_entry.tres") as EnemySpawnEntry
	var definition := WaveDefinition.new()
	definition.enemy_pool = [entry]
	definition.spawn_budget = entry.cost
	director.begin_wave(definition, 10)
	director.spawn_bonus_enemy(
		entry,
		Vector2.ZERO,
		[&"boss", &"milestone_boss"],
		0.0,
		director.build_specific_monster_rarity_roll(SpawnDirector.MONSTER_RARITY_RARE),
		20.0
	)
	await process_frame
	await process_frame

	if director.active_enemy_count != 1:
		return _fail("Boss should be tracked as an active enemy.")
	var boss := enemies.get_child(0) as Enemy
	if boss == null:
		return _fail("Spawned boss is not an Enemy.")
	if not boss.spawn_tags.has(&"boss") or not boss.spawn_tags.has(&"milestone_boss"):
		return _fail("Boss did not receive expected boss tags.")
	var rewards := boss.get_node("MonsterRewardComponent") as MonsterRewardComponent
	if not is_equal_approx(rewards.rarity_reward_multiplier, 20.0):
		return _fail("Boss reward multiplier was not applied.")
	if not ui._panel.visible:
		return _fail("Boss health bar did not show for spawned boss.")

	var health := boss.get_node("HealthComponent") as HealthComponent
	health.take_damage(999999.0, boss)
	await process_frame
	if ui._panel.visible:
		return _fail("Boss health bar did not hide after boss death.")
	world.queue_free()
	return true

func _test_charger_brute_state_cycle() -> bool:
	var boss := load("res://Scenes/Enemies/charger_brute_boss.tscn").instantiate() as Enemy
	var target := Node2D.new()
	root.add_child(boss)
	root.add_child(target)
	target.global_position = Vector2(300.0, 0.0)
	await process_frame

	var behavior := boss.get_node("MovementBehavior") as ChargerBruteBehavior
	if behavior == null:
		return _fail("Charger Brute is missing its behavior.")
	behavior.get_movement_direction(boss, target, 1.0)
	if behavior.state != ChargerBruteBehavior.State.WINDUP:
		return _fail("Charger Brute did not enter windup.")
	behavior.get_movement_direction(boss, target, 1.1)
	if behavior.state != ChargerBruteBehavior.State.CHARGING:
		return _fail("Charger Brute did not enter charge.")
	behavior.get_movement_direction(boss, target, 0.55)
	if behavior.state != ChargerBruteBehavior.State.RECOVERY:
		return _fail("Charger Brute did not enter recovery.")
	behavior.get_movement_direction(boss, target, 1.2)
	if behavior.state != ChargerBruteBehavior.State.IDLE:
		return _fail("Charger Brute did not return to idle.")

	boss.queue_free()
	target.queue_free()
	return true

func _options_have_content(options: Array, content_id: StringName) -> bool:
	for option in options:
		var offer := option as ContentOffer
		if offer != null and offer.content != null and offer.content.id == content_id:
			return true
	return false

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
