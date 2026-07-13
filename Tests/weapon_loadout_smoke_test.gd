extends SceneTree

func _initialize() -> void:
	if not _test_loadout_slots_and_selling():
		return
	if not _test_shop_weapon_purchase_and_block():
		return
	if not _test_weapon_rarity_generation():
		return
	print("weapon_loadout_smoke_test: PASS")
	quit(0)

func _test_loadout_slots_and_selling() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var loadout := player.get_node("WeaponLoadoutComponent") as WeaponLoadoutComponent
	var progression := player.get_node(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	var pistol_offer := WeaponOffer.create(
		load("res://Data/Weapons/pistol.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	var shotgun_offer := WeaponOffer.create(
		load("res://Data/Weapons/shotgun.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	var machine_gun_offer := WeaponOffer.create(
		load("res://Data/Weapons/machine_gun.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)

	if not loadout.equip_offer(pistol_offer):
		return _fail("First weapon did not equip.")
	if loadout.get_offer(0) != pistol_offer:
		return _fail("First weapon did not equip into slot 1.")
	if not loadout.equip_offer(shotgun_offer):
		return _fail("Second weapon did not equip.")
	if loadout.get_offer(1) != shotgun_offer:
		return _fail("Second weapon did not equip into slot 2.")
	if loadout.equip_offer(machine_gun_offer):
		return _fail("Third weapon equipped even though both slots were full.")

	var gold_before := progression.gold
	if not loadout.sell_weapon(0, progression, 1):
		return _fail("Selling slot 1 weapon failed.")
	if loadout.get_offer(0) != null:
		return _fail("Selling slot 1 did not free the slot.")
	if progression.gold <= gold_before:
		return _fail("Selling a weapon did not grant gold.")
	if not loadout.equip_offer(machine_gun_offer):
		return _fail("Weapon did not equip after freeing a slot.")
	if loadout.get_offer(0) != machine_gun_offer:
		return _fail("Freed slot was not reused first.")

	player.queue_free()
	return true

func _test_shop_weapon_purchase_and_block() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var loadout := player.get_node("WeaponLoadoutComponent") as WeaponLoadoutComponent
	var progression := player.get_node(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	progression.add_gold(200)

	var wave_director := WaveDirector.new()
	wave_director.state = WaveDirector.State.SHOP

	var shop := ShopDirector.new()
	shop.wave_director = wave_director
	shop.player = player
	shop.progression = progression
	shop.inventory = player.get_node(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	shop.weapon_loadout = loadout
	root.add_child(shop)

	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var pistol := load("res://Data/Weapons/pistol.tres") as WeaponDefinition
	var shotgun := load("res://Data/Weapons/shotgun.tres") as WeaponDefinition
	var machine_gun := load("res://Data/Weapons/machine_gun.tres") as WeaponDefinition
	var first_offer := WeaponOffer.create(pistol, ItemDefinition.Rarity.COMMON, rng)
	var second_offer := WeaponOffer.create(shotgun, ItemDefinition.Rarity.COMMON, rng)
	var blocked_offer := WeaponOffer.create(machine_gun, ItemDefinition.Rarity.COMMON, rng)

	shop.current_offers = [first_offer]
	shop.current_prices = [first_offer.get_shop_price(1)]
	shop.current_locks = [false]
	if not shop.buy_offer(0):
		return _fail("Shop weapon purchase failed.")
	if loadout.get_offer(0) != first_offer:
		return _fail("Shop weapon did not equip into slot 1.")

	shop.current_offers = [second_offer]
	shop.current_prices = [second_offer.get_shop_price(1)]
	shop.current_locks = [false]
	if not shop.buy_offer(0):
		return _fail("Second shop weapon purchase failed.")
	if loadout.get_offer(1) != second_offer:
		return _fail("Second shop weapon did not equip into slot 2.")

	var gold_before_block := progression.gold
	shop.current_offers = [blocked_offer]
	shop.current_prices = [blocked_offer.get_shop_price(1)]
	shop.current_locks = [false]
	if shop.buy_offer(0):
		return _fail("Shop allowed weapon purchase with full slots.")
	if progression.gold != gold_before_block:
		return _fail("Blocked weapon purchase spent gold.")

	shop.queue_free()
	wave_director.queue_free()
	player.queue_free()
	return true

func _test_weapon_rarity_generation() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var definition := load("res://Data/Weapons/pistol.tres") as WeaponDefinition
	var rare_offer := WeaponOffer.create(
		definition,
		ItemDefinition.Rarity.RARE,
		rng
	)
	if not is_equal_approx(rare_offer.stat_multiplier, 1.6):
		return _fail("Rare weapon multiplier was not 1.6.")
	if rare_offer.affix_modifiers.size() != 2:
		return _fail("Rare weapon did not roll exactly 2 affixes.")
	var seen_stats := {}
	for modifier in rare_offer.affix_modifiers:
		if seen_stats.has(modifier.stat_id):
			return _fail("Weapon rolled duplicate affix stats.")
		seen_stats[modifier.stat_id] = true
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
