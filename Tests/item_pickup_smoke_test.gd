extends SceneTree

const STAT_CATALOG := preload("res://Data/Stats/stat_catalog.tres")
const PLAYER_STATS := preload("res://Data/Stats/player_stats.tres")
const ENEMY_STATS := preload("res://Data/Stats/enemy_stats.tres")
const RUNNING_SHOES := preload("res://Data/Items/running_shoes.tres")
const PISTOL := preload("res://Data/Weapons/pistol.tres")
const DASH := preload("res://Data/ActiveSkills/dash.tres")
const ITEM_PICKUP_SCENE := preload("res://Scenes/Rewards/item_pickup.tscn")

func _init() -> void:
	var failures: Array[String] = []

	var drops := Node2D.new()
	drops.add_to_group(&"drops_container")
	root.add_child(drops)

	var player := Node2D.new()
	player.add_to_group(&"player")
	player.name = "Player"
	root.add_child(player)

	var player_stats := StatComponent.new()
	player_stats.name = "StatComponent"
	player_stats.domain = &"player"
	player_stats.catalog = STAT_CATALOG
	player_stats.base_profile = PLAYER_STATS
	player.add_child(player_stats)

	var inventory := PlayerInventoryComponent.new()
	inventory.name = "PlayerInventoryComponent"
	inventory.stat_component = player_stats
	player.add_child(inventory)

	var weapon_loadout := WeaponLoadoutComponent.new()
	weapon_loadout.name = "WeaponLoadoutComponent"
	var weapon_mount := Node2D.new()
	weapon_mount.name = "WeaponMount"
	player.add_child(weapon_mount)
	weapon_loadout.weapon_mount = weapon_mount
	player.add_child(weapon_loadout)

	var skill_loadout := ActiveSkillLoadoutComponent.new()
	skill_loadout.name = "ActiveSkillLoadoutComponent"
	player.add_child(skill_loadout)

	var monster := Node2D.new()
	monster.name = "Monster"
	root.add_child(monster)

	var monster_stats := StatComponent.new()
	monster_stats.name = "StatComponent"
	monster_stats.domain = &"monster"
	monster_stats.catalog = STAT_CATALOG
	monster_stats.base_profile = ENEMY_STATS
	monster.add_child(monster_stats)

	var rewards := MonsterRewardComponent.new()
	rewards.monster_stats = monster_stats
	rewards.item_pickup_scene = ITEM_PICKUP_SCENE
	rewards.item_drop_pool = [RUNNING_SHOES]
	rewards.item_drop_chance_per_spawn_cost = 100.0
	rewards.relic_drop_chance_per_spawn_cost = 0.0
	rewards.maximum_item_drops_per_monster = 1
	rewards.grant_item_drops_directly = false
	monster.add_child(rewards)
	rewards.configure(1, 1.0, 1)
	rewards._roll_item_drops(player, player_stats)

	if drops.get_child_count() != 1:
		failures.append(
			"Expected one item pickup, got %d." % drops.get_child_count()
		)
	else:
		var pickup := drops.get_child(0) as ItemPickup
		if pickup == null:
			failures.append("Expected spawned drop to be an ItemPickup.")
		else:
			pickup.collect_for(player)
			await create_timer(pickup.forced_collection_duration + 0.1).timeout
			if inventory.items.size() != 1:
				failures.append(
					"Expected collected pickup to add one item, got %d."
					% inventory.items.size()
				)
			elif inventory.items[0] != RUNNING_SHOES:
				failures.append("Expected collected pickup to add Running Shoes.")

	var evaluation := ItemEvaluationDirector.new()
	evaluation.inventory = inventory
	evaluation.progression = PlayerProgressionComponent.new()
	evaluation.weapon_loadout = weapon_loadout
	evaluation.active_skill_loadout = skill_loadout
	root.add_child(evaluation)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var weapon_pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
	drops.add_child(weapon_pickup)
	weapon_pickup.setup_weapon(
		WeaponOffer.create(PISTOL, ItemDefinition.Rarity.COMMON, rng),
		player
	)
	weapon_pickup.collect_for(player)
	await create_timer(weapon_pickup.forced_collection_duration + 0.1).timeout
	evaluation.begin_evaluation(1)
	if not evaluation.keep_current():
		failures.append("Expected weapon drop evaluation to equip a weapon.")
	elif weapon_loadout.get_equipped_count() != 1:
		failures.append("Expected kept weapon drop to enter weapon loadout.")

	var skill_pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
	drops.add_child(skill_pickup)
	skill_pickup.setup_active_skill(DASH, player)
	skill_pickup.collect_for(player)
	await create_timer(skill_pickup.forced_collection_duration + 0.1).timeout
	evaluation.begin_evaluation(1)
	if not evaluation.keep_current():
		failures.append("Expected skill drop evaluation to equip a skill.")
	elif skill_loadout.get_skill(0) != DASH:
		failures.append("Expected kept skill drop to enter active skill slot 1.")

	if failures.is_empty():
		print("item_pickup_smoke_test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
