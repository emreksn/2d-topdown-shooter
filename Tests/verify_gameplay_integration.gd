extends SceneTree

func _initialize() -> void:
	if not await _test_pistol_and_melee_damage():
		return
	if not await _test_spawn_effectiveness_context():
		return
	if not await _test_rift_bonus_spawning():
		return
	if not await _test_spawn_tracking_reconciliation():
		return
	if not _test_player_progression():
		return
	if not _test_shop_inventory_and_rarity():
		return
	if not await _test_monster_rewards():
		return
	quit(0)

func _test_pistol_and_melee_damage() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var player := load("res://Scenes/player.tscn").instantiate() as CharacterBody2D
	var enemy := load("res://Scenes/Enemies/chasing_enemy.tscn").instantiate() as Enemy
	world.add_child(player)
	world.add_child(enemy)
	_equip_common_weapon(player, "res://Data/Weapons/pistol.tres")
	player.position = Vector2.ZERO
	enemy.position = Vector2(90.0, 0.0)
	enemy.movement_speed = 0.0

	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	var player_health := player.get_node("HealthComponent") as HealthComponent
	if not is_equal_approx(enemy_health.maximum_health, 90.0):
		return _fail("Enemy maximum health baseline changed.")

	await create_timer(1.5).timeout
	if not is_equal_approx(enemy_health.current_health, 60.0):
		return _fail(
			"Common pistol expected 60 health, received %f."
			% enemy_health.current_health
		)

	enemy.position = player.position
	await create_timer(0.3).timeout
	if not is_equal_approx(player_health.current_health, 90.0):
		return _fail("Stat-driven melee damage did not deal exactly 10 damage.")

	world.queue_free()
	await process_frame
	return true

func _test_spawn_effectiveness_context() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemies := Node2D.new()
	world.add_child(enemies)
	var registry := RuntimeModifierRegistry.new()
	world.add_child(registry)
	var spawn_director := SpawnDirector.new()
	spawn_director.enemy_container = enemies
	spawn_director.runtime_modifier_registry = registry
	world.add_child(spawn_director)

	var effectiveness_modifier := StatModifier.new()
	effectiveness_modifier.stat_id = StatIds.MONSTER_EFFECTIVENESS
	effectiveness_modifier.operation = StatModifier.Operation.FLAT
	effectiveness_modifier.value = 20.0
	effectiveness_modifier.target_domain = &"monster"
	var health_modifier := StatModifier.new()
	health_modifier.stat_id = StatIds.MAXIMUM_HEALTH
	health_modifier.operation = StatModifier.Operation.INCREASED
	health_modifier.value = 25.0
	health_modifier.target_domain = &"monster"
	health_modifier.required_all_tags = [&"rift"]
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [effectiveness_modifier, health_modifier]
	registry.add_modifier_source(&"test:rift", modifier_set)

	var entry := load(
		"res://Data/Waves/Enemies/wandering_enemy_entry.tres"
	) as EnemySpawnEntry
	var test_wave := WaveDefinition.new()
	test_wave.duration = 1.0
	test_wave.spawn_budget = entry.cost
	test_wave.spawn_cutoff_before_end = 0.0
	test_wave.spawn_warning_duration = 0.01
	test_wave.enemy_pool = [entry]
	test_wave.minimum_pack_size = 1
	test_wave.maximum_pack_size = 1
	test_wave.context_tags = [&"rift"]

	spawn_director.begin_wave(test_wave, 1)
	spawn_director.spawn_bonus_enemy(entry, Vector2.ZERO)
	await process_frame

	var spawned_enemies: Array[Node] = enemies.get_children()
	if spawned_enemies.size() != 1:
		return _fail(
			"Context test expected one enemy, received %d (active=%d, container=%s)."
			% [
				spawned_enemies.size(),
				spawn_director.active_enemy_count,
				spawn_director.enemy_container.get_path()
				if is_instance_valid(spawn_director.enemy_container)
				else "null"
			]
		)
	var stats := spawned_enemies[0].get_node("StatComponent") as StatComponent
	var health := spawned_enemies[0].get_node("HealthComponent") as HealthComponent
	if not is_equal_approx(
		stats.get_stat(StatIds.MONSTER_EFFECTIVENESS),
		20.0
	):
		return _fail("Runtime Effectiveness source was not applied before spawn.")
	if not is_equal_approx(health.maximum_health, 112.5):
		return _fail("Runtime maximum health source was not applied before spawn.")
	if not is_equal_approx(health.current_health, 112.5):
		return _fail("Spawned enemy was not filled to its modified maximum health.")

	var scaling := (
		spawned_enemies[0].get_node("MonsterScalingComponent")
		as MonsterScalingComponent
	)
	if not is_equal_approx(scaling.get_combined_toughness(), 20.0):
		return _fail("Spawned enemy combined toughness is incorrect.")
	registry.remove_modifier_source(&"test:rift")
	await process_frame
	if not is_equal_approx(
		stats.get_stat(StatIds.MONSTER_EFFECTIVENESS),
		0.0
	):
		return _fail("Live enemy did not remove a runtime Effectiveness source.")
	if not is_equal_approx(health.maximum_health, 90.0):
		return _fail("Live enemy did not remove a runtime maximum health source.")

	world.queue_free()
	await process_frame
	return true

func _test_rift_bonus_spawning() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemies := Node2D.new()
	world.add_child(enemies)
	var spawn_director := SpawnDirector.new()
	spawn_director.enemy_container = enemies
	world.add_child(spawn_director)

	var entry := load(
		"res://Data/Waves/Enemies/wandering_enemy_entry.tres"
	) as EnemySpawnEntry
	var definition := WaveDefinition.new()
	definition.spawn_budget = 7
	definition.enemy_pool = [entry]
	definition.minimum_pack_size = 1
	definition.maximum_pack_size = 1
	var bountiful := load(
		"res://Data/Content/Variants/bountiful.tres"
	) as ContentVariantDefinition
	definition.monster_modifier_sets = [bountiful.inherent_modifier_set]
	spawn_director.begin_wave(definition, 1)
	spawn_director.stop_spawning()
	var budget_before := spawn_director._remaining_budget

	var portal := load(
		"res://Scenes/Content/rift_portal.tscn"
	).instantiate() as RiftPortal
	portal.opening_duration = 0.0
	portal.spawn_interval = 0.0
	portal.spawn_warning_duration = 0.01
	portal.closing_duration = 0.0
	world.add_child(portal)
	portal.activate(spawn_director, [entry, entry, entry])
	await create_timer(0.05).timeout

	if enemies.get_child_count() != 3:
		return _fail(
			"Rift expected 3 bonus monsters, received %d."
			% enemies.get_child_count()
		)
	if spawn_director._remaining_budget != budget_before:
		return _fail("Rift bonus monsters consumed the normal wave budget.")
	for enemy in enemies.get_children():
		if not (enemy as Enemy).spawn_tags.has(&"rift"):
			return _fail("Rift bonus monster did not receive the rift tag.")
		var health := enemy.get_node("HealthComponent") as HealthComponent
		if not is_equal_approx(health.maximum_health, 112.5):
			return _fail("Rift bonus monster did not receive modified maximum health.")
		if not is_equal_approx(health.current_health, 112.5):
			return _fail("Rift bonus monster did not spawn at modified current health.")

	world.queue_free()
	await process_frame
	return true

func _test_spawn_tracking_reconciliation() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var director := SpawnDirector.new()
	world.add_child(director)
	var stale_enemy := Node2D.new()
	world.add_child(stale_enemy)
	director._active_enemy_ids[stale_enemy.get_instance_id()] = stale_enemy
	stale_enemy.queue_free()
	await physics_frame
	await physics_frame

	if director.active_enemy_count != 0:
		return _fail("SpawnDirector retained a removed enemy in its active count.")

	world.queue_free()
	await process_frame
	return true

func _test_player_progression() -> bool:
	var progression := PlayerProgressionComponent.new()
	progression.base_experience_to_level = 100.0
	progression.level_experience_exponent = 1.0
	progression.add_gold(17)
	progression.add_experience(125.0)
	if progression.gold != 17:
		progression.free()
		return _fail("Player progression did not retain added gold.")
	if progression.level != 2:
		progression.free()
		return _fail("Player progression did not level up.")
	if not is_equal_approx(progression.experience, 25.0):
		progression.free()
		return _fail("Player progression did not retain overflow experience.")
	progression.free()
	return true

func _test_shop_inventory_and_rarity() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var progression := player.get_node(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	var inventory := player.get_node(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	var stats := player.get_node("StatComponent") as StatComponent
	var shoes := load("res://Data/Items/running_shoes.tres") as ItemDefinition
	var notes := load("res://Data/Items/study_notes.tres") as ItemDefinition
	var locket := load("res://Data/Items/last_breath_locket.tres") as ItemDefinition
	var compass := load("res://Data/Items/rift_compass.tres") as ItemDefinition

	progression.add_gold(200)
	var wave_director := WaveDirector.new()
	wave_director.state = WaveDirector.State.SHOP
	var shop := ShopDirector.new()
	shop.wave_director = wave_director
	shop.progression = progression
	shop.inventory = inventory
	shop.player_stats = stats
	var offers: Array[ItemDefinition] = [shoes, locket, compass]
	var prices: Array[int] = [10, 10, 10]
	var locks: Array[bool] = [false, false, false]
	shop.current_offers = offers
	shop.current_prices = prices
	shop.current_locks = locks

	if not shop.buy_offer(0):
		return _fail("Shop purchase failed with enough gold.")
	if progression.gold != 190:
		return _fail("Shop purchase did not spend gold.")
	if not is_equal_approx(stats.get_stat(StatIds.MOVEMENT_SPEED), 108.0):
		return _fail("Purchased inventory item did not apply its stat modifier.")
	if not shop.buy_offer(1):
		return _fail("Shop did not equip a purchased Survival Relic.")
	if inventory.get_active_relic(ItemDefinition.RelicSlot.SURVIVAL) != locket:
		return _fail("Purchased Relic was not equipped into its slot.")
	if not shop.buy_offer(2):
		return _fail("Shop did not equip a purchased Wave Relic.")
	if inventory.get_active_relic(ItemDefinition.RelicSlot.WAVE) != compass:
		return _fail("Second Relic was not equipped into its own slot.")
	if not inventory.sell_item(locket, progression):
		return _fail("Active Relic could not be sold.")
	if inventory.get_active_relic(ItemDefinition.RelicSlot.SURVIVAL) != null:
		return _fail("Sold active Relic stayed equipped.")

	var manager := ItemRarityManager.new()
	manager.common_weight = 0.0
	manager.uncommon_weight = 0.0
	manager.rare_weight = 1.0
	manager.legendary_weight = 0.0
	manager.tradeoff_weight = 0.0
	manager.unique_weight = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pool: Array[ItemDefinition] = [shoes, notes]
	var chosen := manager.choose_item(pool, rng, 1.0)
	if chosen != notes:
		return _fail("Item rarity manager did not choose from the rolled rarity.")

	shop.free()
	player.queue_free()
	return true

func _test_monster_rewards() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var drops := Node2D.new()
	drops.add_to_group(&"drops_container")
	world.add_child(drops)
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	world.add_child(player)
	var enemy := load("res://Scenes/Enemies/chasing_enemy.tscn").instantiate() as Enemy
	enemy.configure_spawn_reward(2)
	world.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(10.0, 0.0)

	var health := enemy.get_node("HealthComponent") as HealthComponent
	var rewards := enemy.get_node(
		"MonsterRewardComponent"
	) as MonsterRewardComponent
	if not is_instance_valid(rewards.health_component):
		return _fail("Monster reward has no HealthComponent.")
	if not is_equal_approx(
		rewards.monster_stats.get_stat(StatIds.GOLD_GRANTED_MULTIPLIER),
		1.0
	):
		return _fail("Monster gold multiplier did not resolve to 1.0.")
	health.take_damage(health.current_health, player)
	if drops.get_child_count() != 2:
		return _fail(
			"Monster death expected 2 reward pickups, received %d."
			% drops.get_child_count()
		)
	await physics_frame
	await physics_frame

	var progression := player.get_node(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	if progression.gold <= 0:
		return _fail("Monster reward did not grant collected gold.")
	if progression.experience <= 0.0:
		return _fail("Monster reward did not grant collected experience.")

	world.queue_free()
	await process_frame
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false

func _equip_common_weapon(player: Node, definition_path: String) -> void:
	var loadout := player.get_node_or_null(
		"WeaponLoadoutComponent"
	) as WeaponLoadoutComponent
	var definition := load(definition_path) as WeaponDefinition
	if loadout == null or definition == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	loadout.equip_offer(
		WeaponOffer.create(
			definition,
			ItemDefinition.Rarity.COMMON,
			rng
		)
	)
