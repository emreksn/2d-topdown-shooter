class_name MonsterRewardComponent
extends Node

signal item_drop_rolled(item: ItemDefinition, drop_position: Vector2)

@export var health_component: HealthComponent
@export var monster_stats: StatComponent
@export var reward_pickup_scene: PackedScene
@export var item_pickup_scene: PackedScene
@export var item_rarity_manager: ItemRarityManager
@export var item_drop_pool: Array[ItemDefinition] = []
@export var weapon_drop_pool: Array[WeaponDefinition] = []
@export var active_skill_drop_pool: Array[ActiveSkillDefinition] = []
@export_range(0.0, 1000.0, 0.5) var experience_per_spawn_cost: float = 5.0
@export_range(0.0, 1000.0, 0.5) var gold_per_spawn_cost: float = 2.0
@export_range(0.0, 100.0, 0.1) var item_drop_chance_per_spawn_cost: float = 2.0
@export_range(0.0, 100.0, 0.1) var relic_drop_chance_per_spawn_cost: float = 0.35
@export_range(0.0, 100.0, 0.1) var weapon_drop_chance_per_spawn_cost: float = 0.25
@export_range(0.0, 100.0, 0.1) var active_skill_drop_chance_per_spawn_cost: float = 0.2
@export_range(0.0, 1.0, 0.01) var experience_variance: float = 0.10
@export_range(0.0, 1.0, 0.01) var gold_variance: float = 0.20
@export_range(0, 20, 1) var maximum_item_drops_per_monster: int = 3
@export var grant_item_drops_directly: bool = false

var spawn_cost: int = 1
var wave_number: int = 1
var rarity_reward_multiplier: float = 1.0
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	if not is_instance_valid(health_component):
		health_component = _find_health_component()
	if not is_instance_valid(monster_stats):
		monster_stats = _find_stat_component()
	if is_instance_valid(health_component):
		health_component.died.connect(_on_died)
	else:
		push_warning("MonsterRewardComponent has no HealthComponent.")
	if item_rarity_manager == null:
		item_rarity_manager = ItemRarityManager.new()

func _find_health_component() -> HealthComponent:
	for sibling in get_parent().get_children():
		if sibling is HealthComponent:
			return sibling
	return null

func _find_stat_component() -> StatComponent:
	for sibling in get_parent().get_children():
		if sibling is StatComponent:
			return sibling
	return null

func configure(
	enemy_spawn_cost: int,
	rarity_multiplier: float = 1.0,
	enemy_wave_number: int = 1
) -> void:
	spawn_cost = maxi(enemy_spawn_cost, 1)
	rarity_reward_multiplier = maxf(rarity_multiplier, 0.0)
	wave_number = maxi(enemy_wave_number, 1)

func get_expected_experience(player_stats: StatComponent = null) -> float:
	if not is_instance_valid(monster_stats):
		return 0.0
	var effectiveness := monster_stats.get_stat(StatIds.MONSTER_EFFECTIVENESS)
	return (
		experience_per_spawn_cost
		* float(spawn_cost)
		* monster_stats.get_stat(StatIds.EXPERIENCE_GRANTED_MULTIPLIER)
		* (1.0 + effectiveness / 200.0)
		* rarity_reward_multiplier
		* _get_player_stat(player_stats, StatIds.EXPERIENCE_GAIN_MULTIPLIER, 1.0)
	)

func get_expected_gold(player_stats: StatComponent = null) -> float:
	if not is_instance_valid(monster_stats):
		return 0.0
	var effectiveness := monster_stats.get_stat(StatIds.MONSTER_EFFECTIVENESS)
	return (
		gold_per_spawn_cost
		* float(spawn_cost)
		* monster_stats.get_stat(StatIds.GOLD_GRANTED_MULTIPLIER)
		* (1.0 + effectiveness / 200.0)
		* rarity_reward_multiplier
		* _get_player_stat(player_stats, StatIds.GOLD_GRANTED_MULTIPLIER, 1.0)
	)

func get_expected_item_drop_count(player_stats: StatComponent = null) -> float:
	if not is_instance_valid(monster_stats) or maximum_item_drops_per_monster <= 0:
		return 0.0
	if _get_item_drop_pool().is_empty():
		return 0.0
	var quantity_multiplier := (
		monster_stats.get_stat(StatIds.ITEM_QUANTITY_MULTIPLIER)
		* _get_player_stat(player_stats, StatIds.ITEM_QUANTITY_MULTIPLIER, 1.0)
	)
	var expected := (
		float(spawn_cost)
		* item_drop_chance_per_spawn_cost
		/ 100.0
		* quantity_multiplier
	)
	return minf(expected, float(maximum_item_drops_per_monster))

func get_item_drop_chance_percent(player_stats: StatComponent = null) -> float:
	var expected := get_expected_item_drop_count(player_stats)
	if expected <= 0.0:
		return 0.0
	if expected >= 1.0:
		return 100.0
	return expected * 100.0

func get_item_rarity_chances(player_stats: StatComponent = null) -> Dictionary:
	if item_rarity_manager == null:
		item_rarity_manager = ItemRarityManager.new()
	var pool := _get_wave_available_item_drop_pool()
	if pool.is_empty():
		return {}

	var available_rarities := {}
	for item in pool:
		if item != null:
			available_rarities[item.rarity] = true

	var rarity_multiplier := (
		monster_stats.get_stat(StatIds.MONSTER_ITEM_RARITY_MULTIPLIER)
		* _get_player_stat(player_stats, StatIds.ITEM_RARITY_MULTIPLIER, 1.0)
		* rarity_reward_multiplier
	)
	var weights := item_rarity_manager.get_adjusted_weights(
		rarity_multiplier,
		wave_number
	)
	var total_weight := 0.0
	for rarity in ItemRarityManager.RARITY_ORDER:
		if available_rarities.has(rarity):
			total_weight += maxf(float(weights[rarity]), 0.0)

	var chances := {}
	if total_weight <= 0.0:
		return chances
	for rarity in ItemRarityManager.RARITY_ORDER:
		if not available_rarities.has(rarity):
			continue
		chances[rarity] = maxf(float(weights[rarity]), 0.0) / total_weight * 100.0
	return chances

func _on_died(_source: Node) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(player):
		return
	var player_stats := player.get_node_or_null("StatComponent") as StatComponent
	var progression := player.get_node_or_null("PlayerProgressionComponent") as PlayerProgressionComponent
	if not is_instance_valid(player_stats) or not is_instance_valid(progression):
		return
	var effectiveness := monster_stats.get_stat(StatIds.MONSTER_EFFECTIVENESS)
	var experience := experience_per_spawn_cost * spawn_cost * monster_stats.get_stat(StatIds.EXPERIENCE_GRANTED_MULTIPLIER) * (1.0 + effectiveness / 200.0) * rarity_reward_multiplier * player_stats.get_stat(StatIds.EXPERIENCE_GAIN_MULTIPLIER) * _triangular_factor(experience_variance)
	var gold := gold_per_spawn_cost * spawn_cost * monster_stats.get_stat(StatIds.GOLD_GRANTED_MULTIPLIER) * (1.0 + effectiveness / 200.0) * rarity_reward_multiplier * player_stats.get_stat(StatIds.GOLD_GRANTED_MULTIPLIER) * _triangular_factor(gold_variance)
	_award_or_drop(RewardPickup.RewardType.EXPERIENCE, experience, player, progression, player_stats)
	_award_or_drop(RewardPickup.RewardType.GOLD, gold, player, progression, player_stats)
	_roll_item_drops(player, player_stats)

func _triangular_factor(variance: float) -> float:
	return 1.0 + ((_random.randf() + _random.randf()) - 1.0) * variance

func _get_player_stat(
	player_stats: StatComponent,
	stat_id: StringName,
	fallback: float
) -> float:
	return player_stats.get_stat(stat_id) if is_instance_valid(player_stats) else fallback

func _award_or_drop(
	type: RewardPickup.RewardType,
	amount: float,
	player: Node2D,
	progression: PlayerProgressionComponent,
	player_stats: StatComponent
) -> void:
	if amount <= 0.0:
		return
	if _random.randf() * 100.0 < player_stats.get_stat(StatIds.INSTANT_PICKUP_CHANCE):
		if type == RewardPickup.RewardType.GOLD:
			progression.add_gold(maxi(1, roundi(amount)))
		else:
			progression.add_experience(amount)
		return
	if reward_pickup_scene == null:
		return
	var pickup := reward_pickup_scene.instantiate() as RewardPickup
	if pickup == null:
		return
	var container := get_tree().get_first_node_in_group(&"drops_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(pickup)
	pickup.global_position = (get_parent() as Node2D).global_position
	pickup.setup(type, amount, player)

func _roll_item_drops(player: Node2D, player_stats: StatComponent) -> void:
	if maximum_item_drops_per_monster <= 0:
		return
	if not is_instance_valid(player_stats):
		return

	var inventory := player.get_node_or_null(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	if (
		grant_item_drops_directly
		and not is_instance_valid(inventory)
	):
		return

	var pool := _get_items_by_category(ItemDefinition.ItemCategory.ITEM)
	var relic_pool := _get_items_by_category(ItemDefinition.ItemCategory.RELIC)
	var weapon_pool := _get_weapon_drop_pool()
	var skill_pool := _get_active_skill_drop_pool()
	if pool.is_empty() and relic_pool.is_empty() and weapon_pool.is_empty() and skill_pool.is_empty():
		return

	var quantity_multiplier := (
		monster_stats.get_stat(StatIds.ITEM_QUANTITY_MULTIPLIER)
		* player_stats.get_stat(StatIds.ITEM_QUANTITY_MULTIPLIER)
	)
	var item_rarity_multiplier := (
		monster_stats.get_stat(StatIds.MONSTER_ITEM_RARITY_MULTIPLIER)
		* player_stats.get_stat(StatIds.ITEM_RARITY_MULTIPLIER)
		* rarity_reward_multiplier
	)

	var drop_count := _roll_expected_count(
		float(spawn_cost)
		* item_drop_chance_per_spawn_cost
		/ 100.0
		* quantity_multiplier
	)

	_grant_rolled_items(
		pool,
		drop_count,
		item_rarity_multiplier,
		player,
		inventory,
		maximum_item_drops_per_monster
	)
	_grant_rolled_items(
		relic_pool,
		_roll_expected_count(
			float(spawn_cost)
			* relic_drop_chance_per_spawn_cost
			/ 100.0
			* quantity_multiplier
			* monster_stats.get_stat(StatIds.MONSTER_RELIC_DROP_CHANCE_MULTIPLIER)
		),
		item_rarity_multiplier,
		player,
		inventory,
		maximum_item_drops_per_monster
	)
	_grant_rolled_weapons(
		weapon_pool,
		_roll_expected_count(
			float(spawn_cost)
			* weapon_drop_chance_per_spawn_cost
			/ 100.0
			* quantity_multiplier
			* monster_stats.get_stat(StatIds.MONSTER_WEAPON_DROP_CHANCE_MULTIPLIER)
		),
		item_rarity_multiplier,
		player,
		maximum_item_drops_per_monster
	)
	_grant_rolled_active_skills(
		skill_pool,
		_roll_expected_count(
			float(spawn_cost)
			* active_skill_drop_chance_per_spawn_cost
			/ 100.0
			* quantity_multiplier
			* monster_stats.get_stat(StatIds.MONSTER_ACTIVE_SKILL_DROP_CHANCE_MULTIPLIER)
		),
		player,
		maximum_item_drops_per_monster
	)

func _roll_expected_count(expected_count: float) -> int:
	if expected_count <= 0.0:
		return 0
	var guaranteed := floori(expected_count)
	var fractional := expected_count - float(guaranteed)
	return guaranteed + (1 if _random.randf() < fractional else 0)

func _grant_rolled_items(
	pool: Array[ItemDefinition],
	drop_count: int,
	rarity_multiplier: float,
	player: Node2D,
	inventory: PlayerInventoryComponent,
	maximum_count: int = -1
) -> int:
	if pool.is_empty() or drop_count <= 0:
		return 0
	var wanted_count := drop_count
	if maximum_count >= 0:
		wanted_count = mini(wanted_count, maximum_count)
	var granted := 0
	for _index: int in range(wanted_count):
		var item := item_rarity_manager.choose_item(
			pool,
			_random,
			rarity_multiplier,
			wave_number
		)
		if item == null:
			continue
		item_drop_rolled.emit(item, (get_parent() as Node2D).global_position)
		if grant_item_drops_directly and is_instance_valid(inventory):
			inventory.add_item(item)
		else:
			_spawn_item_pickup(item, player)
		granted += 1
	return granted

func _spawn_item_pickup(item: ItemDefinition, player: Node2D) -> void:
	if item == null:
		return
	if item_pickup_scene == null:
		var inventory := player.get_node_or_null(
			"PlayerInventoryComponent"
		) as PlayerInventoryComponent
		if is_instance_valid(inventory):
			inventory.add_item(item)
		return
	var pickup := item_pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		return
	var container := get_tree().get_first_node_in_group(&"drops_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(pickup)
	pickup.global_position = (get_parent() as Node2D).global_position
	pickup.setup(item, player)

func _grant_rolled_weapons(
	pool: Array[WeaponDefinition],
	drop_count: int,
	rarity_multiplier: float,
	player: Node2D,
	maximum_count: int = -1
) -> int:
	if pool.is_empty() or drop_count <= 0:
		return 0
	var wanted_count := drop_count
	if maximum_count >= 0:
		wanted_count = mini(wanted_count, maximum_count)
	var granted := 0
	for _index: int in range(wanted_count):
		var rarity := item_rarity_manager.roll_rarity(
			_random,
			rarity_multiplier,
			wave_number
		)
		if rarity > ItemDefinition.Rarity.LEGENDARY:
			rarity = ItemDefinition.Rarity.LEGENDARY
		var definition := pool[_random.randi_range(0, pool.size() - 1)]
		var offer := WeaponOffer.create(definition, rarity, _random)
		_spawn_weapon_pickup(offer, player)
		granted += 1
	return granted

func _grant_rolled_active_skills(
	pool: Array[ActiveSkillDefinition],
	drop_count: int,
	player: Node2D,
	maximum_count: int = -1
) -> int:
	if pool.is_empty() or drop_count <= 0:
		return 0
	var wanted_count := drop_count
	if maximum_count >= 0:
		wanted_count = mini(wanted_count, maximum_count)
	var granted := 0
	for _index: int in range(wanted_count):
		var skill := pool[_random.randi_range(0, pool.size() - 1)]
		_spawn_active_skill_pickup(skill, player)
		granted += 1
	return granted

func _spawn_weapon_pickup(offer: WeaponOffer, player: Node2D) -> void:
	if offer == null or item_pickup_scene == null:
		return
	var pickup := _spawn_base_pickup() as ItemPickup
	if pickup == null:
		return
	pickup.setup_weapon(offer, player)

func _spawn_active_skill_pickup(skill: ActiveSkillDefinition, player: Node2D) -> void:
	if skill == null or item_pickup_scene == null:
		return
	var pickup := _spawn_base_pickup() as ItemPickup
	if pickup == null:
		return
	pickup.setup_active_skill(skill, player)

func _spawn_base_pickup() -> ItemPickup:
	var pickup := item_pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		return null
	var container := get_tree().get_first_node_in_group(&"drops_container")
	if container == null:
		container = get_tree().current_scene
	container.add_child(pickup)
	pickup.global_position = (get_parent() as Node2D).global_position
	return pickup

func _get_item_drop_pool() -> Array[ItemDefinition]:
	if not item_drop_pool.is_empty():
		return item_drop_pool
	var shop_director := get_tree().get_first_node_in_group(
		&"shop_director"
	) as ShopDirector
	if is_instance_valid(shop_director):
		return shop_director.shop_items
	return []

func _get_items_by_category(category: ItemDefinition.ItemCategory) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in _get_item_drop_pool():
		if item != null and item.category == category:
			result.append(item)
	return result

func _get_weapon_drop_pool() -> Array[WeaponDefinition]:
	if not weapon_drop_pool.is_empty():
		return weapon_drop_pool
	var shop_director := get_tree().get_first_node_in_group(
		&"shop_director"
	) as ShopDirector
	if is_instance_valid(shop_director):
		return shop_director.shop_weapons
	return []

func _get_active_skill_drop_pool() -> Array[ActiveSkillDefinition]:
	if not active_skill_drop_pool.is_empty():
		return active_skill_drop_pool
	var skill_ui := get_tree().get_first_node_in_group(
		&"starter_skill_choice_ui"
	) as StarterSkillChoiceUI
	if is_instance_valid(skill_ui):
		return skill_ui.available_skills
	return []

func _get_wave_available_item_drop_pool() -> Array[ItemDefinition]:
	var pool := _get_item_drop_pool()
	if pool.is_empty():
		return []
	if item_rarity_manager == null:
		item_rarity_manager = ItemRarityManager.new()
	var result: Array[ItemDefinition] = []
	for item in pool:
		if (
			item != null
			and item_rarity_manager.is_rarity_unlocked(item.rarity, wave_number)
		):
			result.append(item)
	return result
