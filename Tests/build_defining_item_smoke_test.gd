extends SceneTree

func _initialize() -> void:
	if not _test_unique_projectile_items():
		return
	if not _test_area_and_cooldown_items():
		return
	if not _test_rift_modifiers_are_more():
		return
	if not _test_relic_gain_as_extra_conversions():
		return
	print("build_defining_item_smoke_test: PASS")
	quit(0)

func _test_unique_projectile_items() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var inventory := player.get_node("PlayerInventoryComponent") as PlayerInventoryComponent
	var weapon_loadout := player.get_node("WeaponLoadoutComponent") as WeaponLoadoutComponent
	var rng := RandomNumberGenerator.new()
	rng.seed = 160
	var offer := WeaponOffer.create(
		load("res://Data/Weapons/pistol_fork.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(offer):
		return _fail("Could not equip Forking Pistol.")
	var weapon := weapon_loadout.get_weapon(0) as ProjectileWeapon
	if weapon == null:
		return _fail("Forking Pistol was not a projectile weapon.")

	inventory.add_item(load("res://Data/Items/chain_reactor.tres") as ItemDefinition)
	inventory.add_item(load("res://Data/Items/fork_stabilizer.tres") as ItemDefinition)
	var behavior := weapon._get_projectile_behavior()
	if int(behavior[&"chain"]) != 1:
		return _fail("Chain Reactor did not grant +1 Chain.")
	var damage_modifiers: Array = behavior[&"damage_modifiers"]
	if damage_modifiers.size() != 1:
		return _fail("Fork Stabilizer did not pass one forked damage modifier.")
	var modifier := damage_modifiers[0] as StatModifier
	if (
		modifier == null
		or modifier.operation != StatModifier.Operation.MORE
		or not is_equal_approx(modifier.value, 42.857143)
		or not modifier.required_all_tags.has(&"forked")
	):
		return _fail("Fork Stabilizer did not offset forked projectile penalty.")

	player.queue_free()
	return true

func _test_area_and_cooldown_items() -> bool:
	var rare_area := load("res://Data/Items/expanding_sigils.tres") as ItemDefinition
	var legendary_area := load("res://Data/Items/cosmic_geometry.tres") as ItemDefinition
	var rare_cooldown := load("res://Data/Items/clockwork_focus.tres") as ItemDefinition
	var legendary_cooldown := load("res://Data/Items/chrono_core.tres") as ItemDefinition
	if rare_area.rarity != ItemDefinition.Rarity.RARE:
		return _fail("Expanding Sigils should start at Rare.")
	if legendary_area.rarity != ItemDefinition.Rarity.LEGENDARY:
		return _fail("Cosmic Geometry should be Legendary.")
	if rare_cooldown.rarity != ItemDefinition.Rarity.RARE:
		return _fail("Clockwork Focus should start at Rare.")
	if legendary_cooldown.rarity != ItemDefinition.Rarity.LEGENDARY:
		return _fail("Chrono Core should be Legendary.")
	var cooldown_modifier := rare_cooldown.modifier_set.modifiers[0]
	if (
		cooldown_modifier.operation != StatModifier.Operation.INCREASED
		or cooldown_modifier.value >= 0.0
	):
		return _fail("Cooldown reduction should use a negative increased modifier.")
	if rare_cooldown.get_stat_display_text() != "12% decreased cooldown duration":
		return _fail("Cooldown item display should say decreased cooldown duration.")

	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var inventory := player.get_node("PlayerInventoryComponent") as PlayerInventoryComponent
	var loadout := player.get_node(
		"ActiveSkillLoadoutComponent"
	) as ActiveSkillLoadoutComponent
	var dash := load("res://Data/ActiveSkills/dash.tres") as ActiveSkillDefinition
	inventory.add_item(rare_cooldown)
	loadout.equip_skill(0, dash)
	if not loadout.activate_slot(0):
		return _fail("Dash did not activate for cooldown test.")
	if not is_equal_approx(loadout.get_cooldown_remaining(0), 3.52):
		return _fail("Cooldown duration item did not reduce active skill cooldown.")
	player.queue_free()
	return true

func _test_rift_modifiers_are_more() -> bool:
	for path in [
		"res://Data/Content/Variants/prosperous.tres",
		"res://Data/Content/Variants/blessed.tres",
		"res://Data/Content/Variants/bountiful.tres",
		"res://Data/Content/Variants/infested.tres",
		"res://Data/Content/ExtraModifiers/golden_wake.tres",
		"res://Data/Content/ExtraModifiers/bright_wake.tres",
		"res://Data/Content/ExtraModifiers/lucky_wake.tres",
		"res://Data/Content/ExtraModifiers/hardened_cache.tres",
		"res://Data/Content/ExtraModifiers/painful_lessons.tres",
		"res://Data/Content/ExtraModifiers/frantic_pack.tres",
		"res://Data/Content/ExtraModifiers/gilded_lessons.tres",
		"res://Data/Content/ExtraModifiers/heavy_hoard.tres",
		"res://Data/Content/ExtraModifiers/violent_abundance.tres",
		"res://Data/Content/ExtraModifiers/crowded_treasury.tres",
		"res://Data/Content/ExtraModifiers/pressed_offering.tres"
	]:
		var resource := load(path)
		var modifier_set: ModifierSet
		if resource is ContentVariantDefinition:
			modifier_set = (resource as ContentVariantDefinition).inherent_modifier_set
		elif resource is ContentExtraModifierDefinition:
			modifier_set = (resource as ContentExtraModifierDefinition).modifier_set
		if modifier_set == null:
			continue
		for modifier in modifier_set.modifiers:
			if modifier.operation != StatModifier.Operation.MORE:
				return _fail("%s still uses non-MORE Rift modifier operation." % path)
	return true

func _test_relic_gain_as_extra_conversions() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var inventory := player.get_node("PlayerInventoryComponent") as PlayerInventoryComponent
	var emberglass := load("res://Data/Items/emberglass_prism.tres") as ItemDefinition
	var ironwood := load("res://Data/Items/ironwood_icon.tres") as ItemDefinition
	if emberglass.category != ItemDefinition.ItemCategory.RELIC:
		return _fail("Emberglass Prism should be a Relic.")
	if ironwood.category != ItemDefinition.ItemCategory.RELIC:
		return _fail("Ironwood Icon should be a Relic.")
	inventory.add_item(emberglass)
	inventory.add_item(ironwood)
	var conversions := inventory.get_damage_conversions()
	if conversions.size() != 2:
		return _fail("Relics did not expose gain-as-extra conversions.")

	var weapon_loadout := player.get_node("WeaponLoadoutComponent") as WeaponLoadoutComponent
	var rng := RandomNumberGenerator.new()
	rng.seed = 161
	var offer := WeaponOffer.create(
		load("res://Data/Weapons/pistol.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(offer):
		return _fail("Could not equip pistol for conversion test.")
	var weapon := weapon_loadout.get_weapon(0) as ProjectileWeapon
	var packet := DamageResolver.build_outgoing_packet(
		weapon.stat_component,
		null,
		weapon._get_actor_damage_conversions(),
		weapon.get_attack_tags(),
		player,
		weapon.allowed_base_damage_types
	)
	if not is_equal_approx(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 30.0):
		return _fail("Gain-as-extra should keep source Physical damage.")
	if not is_equal_approx(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 7.5):
		return _fail("Physical gain-as-extra Relic did not add Elemental damage.")
	player.queue_free()
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
