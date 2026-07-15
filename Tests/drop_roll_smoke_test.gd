extends SceneTree

const STAT_CATALOG := preload("res://Data/Stats/stat_catalog.tres")
const PLAYER_STATS := preload("res://Data/Stats/player_stats.tres")
const ENEMY_STATS := preload("res://Data/Stats/enemy_stats.tres")
const RUNNING_SHOES := preload("res://Data/Items/running_shoes.tres")
const HEAD_TAKER := preload("res://Data/Items/head_taker_crown.tres")
const IRONWOOD := preload("res://Data/Items/ironwood_icon.tres")
const PISTOL := preload("res://Data/Weapons/pistol.tres")
const DASH := preload("res://Data/ActiveSkills/dash.tres")
const BOUNTIFUL := preload("res://Data/Content/Variants/bountiful.tres")

func _init() -> void:
	var failures: Array[String] = []

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

	var monster := Node2D.new()
	monster.name = "Monster"
	root.add_child(monster)

	var monster_stats := StatComponent.new()
	monster_stats.name = "StatComponent"
	monster_stats.domain = &"monster"
	monster_stats.catalog = STAT_CATALOG
	monster_stats.base_profile = ENEMY_STATS
	monster_stats.set_default_context_tags([&"monster", &"rift"])
	monster.add_child(monster_stats)
	monster_stats.add_modifier_source(
		&"test:bountiful",
		BOUNTIFUL.inherent_modifier_set
	)
	var monster_health := HealthComponent.new()
	monster_health.name = "HealthComponent"
	monster_health.stat_component = monster_stats
	monster.add_child(monster_health)

	_assert_near(
		monster_stats.get_stat(StatIds.ITEM_QUANTITY_MULTIPLIER),
		1.45,
		"Rift item quantity modifier should apply.",
		failures
	)
	_assert_near(
		monster_stats.get_stat(StatIds.MONSTER_ITEM_RARITY_MULTIPLIER),
		1.35,
		"Rift monster item rarity modifier should apply.",
		failures
	)
	_assert_near(
		monster_stats.get_stat(StatIds.MAXIMUM_HEALTH),
		112.5,
		"Rift maximum health modifier should apply.",
		failures
	)
	_assert_near(
		monster_stats.get_stat(StatIds.MELEE_DAMAGE),
		11.0,
		"Rift melee damage modifier should apply.",
		failures
	)

	var rewards := MonsterRewardComponent.new()
	rewards.monster_stats = monster_stats
	rewards.item_drop_pool = [RUNNING_SHOES]
	rewards.item_drop_chance_per_spawn_cost = 100.0
	rewards.maximum_item_drops_per_monster = 5
	rewards.grant_item_drops_directly = true
	rewards.item_rarity_manager = ItemRarityManager.new()
	monster.add_child(rewards)
	rewards.configure(1, 1.0, 1)
	rewards._roll_item_drops(player, player_stats)

	if inventory.items.size() < 1 or inventory.items.size() > 2:
		failures.append(
			"Expected one guaranteed item drop with a possible second drop, got %d."
			% inventory.items.size()
		)
	elif inventory.items[0] != RUNNING_SHOES:
		failures.append("Expected guaranteed item drop to be Running Shoes.")

	var before_relic_inventory_count := inventory.items.size()
	inventory.add_item(HEAD_TAKER)
	inventory.add_item(IRONWOOD)
	if inventory.items.size() != before_relic_inventory_count:
		failures.append("Replacing an active relic should not store old relics.")
	if inventory.get_active_relic(ItemDefinition.RelicSlot.COMBAT) != IRONWOOD:
		failures.append("New relic should replace the active relic in its slot.")

	var weapon_skill_rewards := MonsterRewardComponent.new()
	weapon_skill_rewards.monster_stats = monster_stats
	weapon_skill_rewards.item_pickup_scene = load("res://Scenes/Rewards/item_pickup.tscn")
	weapon_skill_rewards.item_drop_pool = []
	weapon_skill_rewards.weapon_drop_pool = [PISTOL]
	weapon_skill_rewards.active_skill_drop_pool = [DASH]
	weapon_skill_rewards.item_drop_chance_per_spawn_cost = 0.0
	weapon_skill_rewards.relic_drop_chance_per_spawn_cost = 0.0
	weapon_skill_rewards.weapon_drop_chance_per_spawn_cost = 100.0
	weapon_skill_rewards.active_skill_drop_chance_per_spawn_cost = 100.0
	monster.add_child(weapon_skill_rewards)
	weapon_skill_rewards.configure(1, 1.0, 1)

	var drops := Node2D.new()
	drops.add_to_group(&"drops_container")
	root.add_child(drops)
	weapon_skill_rewards._roll_item_drops(player, player_stats)
	if drops.get_child_count() != 2:
		failures.append("Expected one weapon and one skill pickup from forced drop rolls.")
	else:
		var kinds := {}
		for child in drops.get_children():
			var pickup := child as ItemPickup
			if pickup != null:
				kinds[pickup.drop_kind] = true
		if not kinds.has(ItemPickup.DropKind.WEAPON):
			failures.append("Forced drop rolls did not create a weapon pickup.")
		if not kinds.has(ItemPickup.DropKind.ACTIVE_SKILL):
			failures.append("Forced drop rolls did not create an active skill pickup.")

	if failures.is_empty():
		print("drop_roll_smoke_test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_near(
	actual: float,
	expected: float,
	message: String,
	failures: Array[String]
) -> void:
	if absf(actual - expected) > 0.001:
		failures.append("%s Expected %.3f, got %.3f." % [message, expected, actual])
