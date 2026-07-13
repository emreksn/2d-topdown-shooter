class_name ShopDirector
extends Node

signal offers_changed
signal purchase_failed(reason: String)
signal item_purchased(item: ItemDefinition, remaining_gold: int)
signal weapon_purchased(offer: WeaponOffer, remaining_gold: int)
signal reroll_completed(cost: int, was_free: bool)

@export var wave_director: WaveDirector
@export var player: Node2D
@export var progression: PlayerProgressionComponent
@export var inventory: PlayerInventoryComponent
@export var weapon_loadout: WeaponLoadoutComponent
@export var player_stats: StatComponent
@export var rarity_manager: ItemRarityManager
@export var shop_items: Array[ItemDefinition] = []
@export var shop_weapons: Array[WeaponDefinition] = []
@export_range(1, 8, 1) var offer_count: int = 3
@export_range(0.0, 1.0, 0.01) var base_relic_offer_chance: float = 0.18
@export_range(0.0, 1.0, 0.01) var base_weapon_offer_chance: float = 0.2
@export_range(0, 1000, 1, "or_greater") var base_reroll_cost: int = 2
@export_range(0, 1000, 1, "or_greater") var reroll_cost_increase: int = 2

var current_offers: Array = []
var current_prices: Array[int] = []
var current_locks: Array[bool] = []
var current_wave_number: int = 0
var rerolls_this_phase: int = 0

var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	if not is_instance_valid(wave_director):
		wave_director = get_tree().get_first_node_in_group(&"wave_director") as WaveDirector
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	if is_instance_valid(player):
		if not is_instance_valid(progression):
			progression = player.get_node_or_null(
				"PlayerProgressionComponent"
			) as PlayerProgressionComponent
		if not is_instance_valid(inventory):
			inventory = player.get_node_or_null(
				"PlayerInventoryComponent"
			) as PlayerInventoryComponent
		if not is_instance_valid(weapon_loadout):
			weapon_loadout = player.get_node_or_null(
				"WeaponLoadoutComponent"
			) as WeaponLoadoutComponent
		if not is_instance_valid(player_stats):
			player_stats = player.get_node_or_null("StatComponent") as StatComponent
	if is_instance_valid(wave_director):
		wave_director.shop_started.connect(_on_shop_started)
	if rarity_manager == null:
		rarity_manager = ItemRarityManager.new()

func buy_offer(index: int) -> bool:
	if index < 0 or index >= current_offers.size():
		purchase_failed.emit("Offer is no longer available.")
		return false
	if not _is_shop_phase_active():
		purchase_failed.emit("Shop is only available between waves.")
		return false
	if not is_instance_valid(progression) or not is_instance_valid(inventory):
		purchase_failed.emit("Shop is missing player inventory.")
		return false

	var offer = current_offers[index]
	var item: ItemDefinition = offer as ItemDefinition
	var weapon_offer: WeaponOffer = offer as WeaponOffer
	if item == null and weapon_offer == null:
		purchase_failed.emit("Offer slot is empty.")
		return false
	if weapon_offer != null:
		return _buy_weapon_offer(index, weapon_offer)
	if _is_relic_slot_occupied(item):
		purchase_failed.emit(
			"%s Relic slot is already occupied."
			% item.get_relic_slot_display_name()
		)
		return false
	var price := current_prices[index]
	if progression.gold < price:
		purchase_failed.emit("Not enough gold.")
		return false

	progression.spend_gold(price)
	inventory.add_item(item)
	current_offers[index] = null
	current_prices[index] = 0
	current_locks[index] = false
	item_purchased.emit(item, progression.gold)
	offers_changed.emit()
	return true

func _buy_weapon_offer(index: int, offer: WeaponOffer) -> bool:
	if not is_instance_valid(weapon_loadout):
		purchase_failed.emit("Shop is missing weapon loadout.")
		return false
	if weapon_loadout.is_full():
		purchase_failed.emit("Weapon slots full.")
		return false
	var price := current_prices[index]
	if progression.gold < price:
		purchase_failed.emit("Not enough gold.")
		return false
	progression.spend_gold(price)
	if not weapon_loadout.equip_offer(offer):
		progression.add_gold(price)
		purchase_failed.emit("Could not equip weapon.")
		return false
	current_offers[index] = null
	current_prices[index] = 0
	current_locks[index] = false
	weapon_purchased.emit(offer, progression.gold)
	offers_changed.emit()
	return true

func reroll_offers() -> bool:
	if not _is_shop_phase_active():
		purchase_failed.emit("Shop is only available between waves.")
		return false
	if not is_instance_valid(progression):
		purchase_failed.emit("Shop is missing player gold.")
		return false

	var cost := get_current_reroll_cost()
	if progression.gold < cost:
		purchase_failed.emit("Not enough gold to reroll.")
		return false
	var free := _roll_free_reroll()
	if not free:
		progression.spend_gold(cost)
	rerolls_this_phase += 1
	_roll_offers(false)
	reroll_completed.emit(cost, free)
	return true

func toggle_offer_lock(index: int) -> bool:
	if index < 0 or index >= current_locks.size():
		return false
	if current_offers[index] == null:
		return false
	current_locks[index] = not current_locks[index]
	offers_changed.emit()
	return true

func leave_shop() -> void:
	if is_instance_valid(wave_director):
		wave_director.finish_shop_phase()

func get_current_reroll_cost() -> int:
	var base_cost := base_reroll_cost + rerolls_this_phase * reroll_cost_increase
	var multiplier := _get_shop_reroll_cost_multiplier()
	return maxi(0, roundi(float(base_cost) * multiplier))

func _on_shop_started(completed_wave_number: int, _next_wave_number: int) -> void:
	current_wave_number = completed_wave_number
	rerolls_this_phase = 0
	_roll_offers(true)

func _roll_offers(is_new_shop_phase: bool) -> void:
	_ensure_offer_slots()
	if shop_items.is_empty() and shop_weapons.is_empty():
		offers_changed.emit()
		return

	var rarity_multiplier := _get_shop_rarity_multiplier()
	var item_pool := _get_wave_available_items(
		_get_items_by_category(ItemDefinition.ItemCategory.ITEM)
	)
	var relic_pool := _get_wave_available_items(
		_get_items_by_category(ItemDefinition.ItemCategory.RELIC)
	)
	var weapon_pool := _get_wave_available_weapons()
	if item_pool.is_empty() and relic_pool.is_empty() and weapon_pool.is_empty():
		push_warning("Shop has no wave-available offers.")
		offers_changed.emit()
		return
	for offer_index: int in range(current_offers.size()):
		if current_locks[offer_index] and current_offers[offer_index] != null:
			continue
		if is_new_shop_phase or not current_locks[offer_index]:
			current_offers[offer_index] = null
			current_prices[offer_index] = 0
		var offer = _roll_offer(
			item_pool,
			relic_pool,
			weapon_pool,
			rarity_multiplier
		)
		if offer == null:
			continue
		current_offers[offer_index] = offer
		current_prices[offer_index] = _get_offer_price(offer)
	offers_changed.emit()

func _ensure_offer_slots() -> void:
	var wanted_count := _get_shop_offer_count()
	while current_offers.size() < wanted_count:
		current_offers.append(null)
		current_prices.append(0)
		current_locks.append(false)
	while current_offers.size() > wanted_count:
		var last_index := current_offers.size() - 1
		if current_locks[last_index] and current_offers[last_index] != null:
			break
		current_offers.remove_at(last_index)
		current_prices.remove_at(last_index)
		current_locks.remove_at(last_index)

func _get_shop_rarity_multiplier() -> float:
	if not is_instance_valid(player_stats):
		return 1.0
	return (
		player_stats.get_stat(StatIds.ITEM_RARITY_MULTIPLIER)
		* player_stats.get_stat(StatIds.SHOP_ITEM_RARITY_MULTIPLIER)
	)

func _get_shop_offer_count() -> int:
	if not is_instance_valid(player_stats):
		return offer_count
	var extra_offers := floori(
		player_stats.get_flat_modifier_total(
			StatIds.SHOP_EXTRA_OFFER_COUNT,
			[],
			StatModifier.Scope.GLOBAL
		)
	)
	return clampi(offer_count + extra_offers, 1, 8)

func _get_shop_reroll_cost_multiplier() -> float:
	if not is_instance_valid(player_stats):
		return 1.0
	return maxf(
		0.0,
		player_stats.get_stat(StatIds.SHOP_REROLL_COST_MULTIPLIER)
	)

func _roll_free_reroll() -> bool:
	if not is_instance_valid(player_stats):
		return false
	var chance := clampf(
		player_stats.get_stat(StatIds.SHOP_FREE_REROLL_CHANCE),
		0.0,
		100.0
	)
	return _random.randf() * 100.0 < chance

func _get_shop_relic_chance_multiplier() -> float:
	if not is_instance_valid(player_stats):
		return 1.0
	return (
		player_stats.get_stat(StatIds.RELIC_CHANCE_MULTIPLIER)
		* player_stats.get_stat(StatIds.SHOP_RELIC_CHANCE_MULTIPLIER)
	)

func is_offer_blocked_by_relic_slot(index: int) -> bool:
	if index < 0 or index >= current_offers.size():
		return false
	var item := current_offers[index] as ItemDefinition
	return _is_relic_slot_occupied(item)

func is_offer_blocked_by_weapon_slots(index: int) -> bool:
	if index < 0 or index >= current_offers.size():
		return false
	var offer := current_offers[index] as WeaponOffer
	return offer != null and is_instance_valid(weapon_loadout) and weapon_loadout.is_full()

func _is_relic_slot_occupied(item: ItemDefinition) -> bool:
	return (
		item != null
		and item.category == ItemDefinition.ItemCategory.RELIC
		and item.relic_slot != ItemDefinition.RelicSlot.NONE
		and is_instance_valid(inventory)
		and inventory.get_active_relic(item.relic_slot) != null
	)

func _roll_offer(
	item_pool: Array[ItemDefinition],
	relic_pool: Array[ItemDefinition],
	weapon_pool: Array[WeaponDefinition],
	rarity_multiplier: float
):
	if not weapon_pool.is_empty() and _random.randf() < base_weapon_offer_chance:
		return _roll_weapon_offer(weapon_pool, rarity_multiplier)
	var offer_pool := _choose_item_or_relic_pool(item_pool, relic_pool)
	if offer_pool.is_empty():
		if not weapon_pool.is_empty():
			return _roll_weapon_offer(weapon_pool, rarity_multiplier)
		return null
	return rarity_manager.choose_item(
		offer_pool,
		_random,
		rarity_multiplier,
		current_wave_number
	)

func _choose_item_or_relic_pool(
	item_pool: Array[ItemDefinition],
	relic_pool: Array[ItemDefinition]
) -> Array[ItemDefinition]:
	if item_pool.is_empty():
		return relic_pool
	if relic_pool.is_empty():
		return item_pool
	var relic_chance := clampf(
		base_relic_offer_chance * _get_shop_relic_chance_multiplier(),
		0.0,
		1.0
	)
	return relic_pool if _random.randf() < relic_chance else item_pool

func _roll_weapon_offer(
	weapon_pool: Array[WeaponDefinition],
	rarity_multiplier: float
) -> WeaponOffer:
	var rarity := rarity_manager.roll_rarity(
		_random,
		rarity_multiplier,
		current_wave_number
	)
	if rarity > ItemDefinition.Rarity.LEGENDARY:
		rarity = ItemDefinition.Rarity.LEGENDARY
	var definition: WeaponDefinition = weapon_pool[
		_random.randi_range(0, weapon_pool.size() - 1)
	]
	return WeaponOffer.create(definition, rarity, _random)

func _get_offer_price(offer) -> int:
	var item := offer as ItemDefinition
	if item != null:
		return item.get_shop_price(current_wave_number)
	var weapon_offer := offer as WeaponOffer
	if weapon_offer != null:
		return weapon_offer.get_shop_price(current_wave_number)
	return 0

func _is_shop_phase_active() -> bool:
	return (
		is_instance_valid(wave_director)
		and wave_director.state == WaveDirector.State.SHOP
	)

func _get_items_by_category(
	category: ItemDefinition.ItemCategory
) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in shop_items:
		if item != null and item.category == category:
			result.append(item)
	return result

func _get_wave_available_items(items: Array[ItemDefinition]) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in items:
		if (
			item != null
			and rarity_manager.is_rarity_unlocked(
				item.rarity,
				current_wave_number
			)
		):
			result.append(item)
	return result

func _get_wave_available_weapons() -> Array[WeaponDefinition]:
	var result: Array[WeaponDefinition] = []
	for weapon in shop_weapons:
		if weapon != null:
			result.append(weapon)
	return result
