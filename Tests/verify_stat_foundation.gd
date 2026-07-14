extends SceneTree

var catalog: StatCatalog

func _initialize() -> void:
	catalog = load("res://Data/Stats/stat_catalog.tres") as StatCatalog
	if not _test_stat_formula():
		return
	if not _test_conversion():
		return
	if not _test_defenses():
		return
	if not _test_effectiveness_sources():
		return
	if not _test_reward_stat_catalog():
		return
	if not _test_modifier_display_text():
		return
	quit(0)

func _test_stat_formula() -> bool:
	var stats := _make_stats(&"player", StatIds.MOVEMENT_SPEED, 100.0)
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [
		_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.FLAT, 20.0),
		_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.INCREASED, 50.0),
		_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.MORE, 20.0),
		_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.MORE, 10.0)
	]
	stats.add_modifier_source(&"test", modifier_set)
	if not _expect_close(
		stats.get_stat(StatIds.MOVEMENT_SPEED),
		237.6,
		"flat/increased/more formula"
	):
		return false
	stats.remove_modifier_source(&"test")
	if not _expect_close(
		stats.get_stat(StatIds.MOVEMENT_SPEED),
		100.0,
		"source removal"
	):
		return false

	var reductions := ModifierSet.new()
	reductions.modifiers = [
		_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.INCREASED, -20.0),
		_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.MORE, -25.0)
	]
	stats.add_modifier_source(&"reductions", reductions)
	return _expect_close(
		stats.get_stat(StatIds.MOVEMENT_SPEED),
		60.0,
		"reduced and less formula"
	)

func _test_conversion() -> bool:
	var weapon := _make_stats(&"weapon", StatIds.PHYSICAL_DAMAGE, 100.0)
	var actor := _make_stats(&"player", &"", 0.0)
	var conversions: Array[DamageConversion] = [
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.ELEMENTAL, 50.0)
	]
	var packet := DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		conversions,
		[&"attack", &"projectile"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 50.0, "remaining physical"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 50.0, "elemental conversion"):
		return false

	var overflow: Array[DamageConversion] = [
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.ELEMENTAL, 80.0),
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.ELEMENTAL, 80.0)
	]
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		overflow,
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 0.0, "overconverted physical"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 100.0, "overconversion cap"):
		return false

	var skill_conversion := _make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.ELEMENTAL, 60.0)
	skill_conversion.priority = DamageConversion.Priority.SKILL
	var other_conversion := _make_conversion(DamageTypeIds.ELEMENTAL, DamageTypeIds.PHYSICAL, 50.0)
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		[skill_conversion, other_conversion],
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 70.0, "two-stage converted physical"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 30.0, "two-stage converted elemental"):
		return false

	var physical_gain := _make_conversion(
		DamageTypeIds.PHYSICAL,
		DamageTypeIds.ELEMENTAL,
		25.0,
		DamageConversion.Mode.GAIN_AS_EXTRA
	)
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		[physical_gain],
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 100.0, "physical source remains after gain"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 25.0, "physical gains elemental"):
		return false

	var elemental_weapon := _make_stats(&"weapon", StatIds.ELEMENTAL_DAMAGE, 100.0)
	packet = DamageResolver.build_outgoing_packet(
		elemental_weapon,
		actor,
		[_make_conversion(
			DamageTypeIds.ELEMENTAL,
			DamageTypeIds.PHYSICAL,
			30.0,
			DamageConversion.Mode.GAIN_AS_EXTRA
		)],
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 100.0, "elemental source remains after gain"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 30.0, "elemental gains physical"):
		return false

	packet = DamageResolver.build_outgoing_packet(
		elemental_weapon,
		actor,
		[_make_conversion(
			DamageTypeIds.ELEMENTAL,
			DamageTypeIds.ELEMENTAL,
			20.0,
			DamageConversion.Mode.GAIN_AS_EXTRA
		)],
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 120.0, "elemental gains elemental once"):
		return false

	var bidirectional_gain: Array[DamageConversion] = [
		_make_conversion(
			DamageTypeIds.PHYSICAL,
			DamageTypeIds.ELEMENTAL,
			50.0,
			DamageConversion.Mode.GAIN_AS_EXTRA
		),
		_make_conversion(
			DamageTypeIds.ELEMENTAL,
			DamageTypeIds.PHYSICAL,
			50.0,
			DamageConversion.Mode.GAIN_AS_EXTRA
		)
	]
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		bidirectional_gain,
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 100.0, "bidirectional gain does not recurse physical"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 50.0, "bidirectional gain does not recurse elemental"):
		return false

	var damage_modifier := _make_modifier(
		StatIds.PHYSICAL_DAMAGE,
		StatModifier.Operation.INCREASED,
		20.0
	)
	var source := ModifierSet.new()
	source.modifiers = [damage_modifier]
	actor.add_modifier_source(&"hybrid", source)
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		[_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.ELEMENTAL, 100.0)],
		[&"attack"],
		null
	)
	if not _expect_close(
		packet.get_damage_by_type(DamageTypeIds.ELEMENTAL),
		100.0,
		"converted damage ignores source-type modifiers"
	):
		return false

	var elemental_modifier := _make_modifier(
		StatIds.ELEMENTAL_DAMAGE,
		StatModifier.Operation.INCREASED,
		20.0
	)
	var elemental_source := ModifierSet.new()
	elemental_source.modifiers = [elemental_modifier]
	actor.add_modifier_source(&"elemental", elemental_source)
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		[_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.ELEMENTAL, 100.0)],
		[&"attack"],
		null
	)
	return _expect_close(
		packet.get_damage_by_type(DamageTypeIds.ELEMENTAL),
		100.0,
		"converted weapon base ignores actor added-damage modifiers"
	)

func _test_defenses() -> bool:
	var packet := DamagePacket.new()
	packet.slices = [DamageSlice.new(100.0, DamageTypeIds.ELEMENTAL)]
	var defender := _make_stats(&"monster", StatIds.ELEMENTAL_RESISTANCE, 75.0)
	var result := DamageResolver.resolve_incoming(packet, defender)
	if not _expect_close(result.total_damage, 25.0, "75 resistance"):
		return false

	defender = _make_stats(&"monster", StatIds.ELEMENTAL_RESISTANCE, -20.0)
	result = DamageResolver.resolve_incoming(packet, defender)
	if not _expect_close(result.total_damage, 120.0, "negative resistance"):
		return false

	for test_case in [
		[100.0, 50.0],
		[200.0, 100.0 / 3.0],
		[-100.0, 200.0],
		[-200.0, 300.0]
	]:
		defender = _make_stats(&"monster", StatIds.TOUGHNESS, test_case[0])
		result = DamageResolver.resolve_incoming(packet, defender)
		if not _expect_close(result.total_damage, test_case[1], "toughness"):
			return false

	defender = _make_stats_from_values(
		&"monster",
		{
			StatIds.TOUGHNESS: 20.0,
			StatIds.MONSTER_EFFECTIVENESS: 20.0
		}
	)
	result = DamageResolver.resolve_incoming(packet, defender)
	if not _expect_close(
		result.total_damage,
		100.0 / 1.4,
		"monster effectiveness merges with toughness"
	):
		return false

	packet.slices = [DamageSlice.new(100.0, DamageTypeIds.PHYSICAL)]
	defender = _make_stats(&"monster", StatIds.ARMOUR, 1000.0)
	result = DamageResolver.resolve_incoming(packet, defender, 1.0, 1.0)
	if not _expect_close(result.total_damage, 50.0, "armour reduction"):
		return false
	if not _expect_close(result.armour_reduction, 0.5, "armour reduction ratio"):
		return false
	packet.slices = [DamageSlice.new(1000.0, DamageTypeIds.PHYSICAL)]
	result = DamageResolver.resolve_incoming(packet, defender, 1.0, 1.0)
	if not _expect_close(result.armour_reduction, 0.5, "armour rating-only reduction"):
		return false

	packet.slices = [DamageSlice.new(100.0, DamageTypeIds.PHYSICAL)]
	defender = _make_stats(&"monster", StatIds.EVASION, 1000.0)
	result = DamageResolver.resolve_incoming(packet, defender, 0.0, 1.0)
	if not result.was_evaded:
		push_error("Evasion roll did not evade.")
		quit(1)
		return false
	if not _expect_close(result.total_damage, 0.0, "evaded damage"):
		return false
	if not result.damage_by_type.is_empty():
		push_error("Evaded hit should not resolve typed damage.")
		quit(1)
		return false

	result = DamageResolver.resolve_incoming(packet, defender, 1.0, 0.0)
	if not result.was_deflected:
		push_error("Deflection roll did not deflect.")
		quit(1)
		return false
	if not _expect_close(result.total_damage, 80.0, "deflected damage"):
		return false

	var mixed_packet := DamagePacket.new()
	mixed_packet.slices = [
		DamageSlice.new(50.0, DamageTypeIds.PHYSICAL),
		DamageSlice.new(50.0, DamageTypeIds.ELEMENTAL)
	]
	var shield_stats := _make_stats_from_values(
		&"player",
		{
			StatIds.MAXIMUM_HEALTH: 100.0,
			StatIds.MAXIMUM_ARCANE_SHIELD: 40.0
		}
	)
	var health := HealthComponent.new()
	health.stat_component = shield_stats
	root.add_child(health)
	health.reset()
	result = DamageResolver.resolve_incoming(mixed_packet, shield_stats, 1.0, 1.0)
	var life_damage := health.take_resolved_damage(result)
	if not _expect_close(result.arcane_shield_damage, 40.0, "arcane shield absorb"):
		return false
	if not _expect_close(life_damage, 60.0, "arcane shield life passthrough"):
		return false
	if not _expect_close(health.current_health, 40.0, "arcane shield health"):
		return false
	if not _expect_close(health.current_arcane_shield, 0.0, "arcane shield spent"):
		return false
	if not _expect_close(
		health._get_arcane_shield_recharge_start_delay(),
		3.0,
		"default arcane shield recharge start delay"
	):
		return false

	var quick_start_stats := _make_stats_from_values(
		&"player",
		{
			StatIds.ARCANE_SHIELD_RECHARGE_START_SPEED: 100.0
		}
	)
	health.stat_component = quick_start_stats
	if not _expect_close(
		health._get_arcane_shield_recharge_start_delay(),
		1.5,
		"arcane shield recharge start speed"
	):
		return false
	return true

func _test_effectiveness_sources() -> bool:
	var stats := _make_stats(&"monster", StatIds.MONSTER_EFFECTIVENESS, 0.0)
	var first := ModifierSet.new()
	first.modifiers = [
		_make_modifier(
			StatIds.MONSTER_EFFECTIVENESS,
			StatModifier.Operation.FLAT,
			10.0
		)
	]
	var second := ModifierSet.new()
	second.modifiers = [
		_make_modifier(
			StatIds.MONSTER_EFFECTIVENESS,
			StatModifier.Operation.FLAT,
			10.0
		)
	]
	stats.add_modifier_source(&"shop", first)
	stats.add_modifier_source(&"rift", second)
	var scaling := MonsterScalingComponent.new()
	root.add_child(scaling)
	scaling.stat_component = stats
	if not _expect_close(scaling.get_combined_toughness(), 20.0, "combined toughness"):
		return false
	if not _expect_close(scaling.get_experience_multiplier(), 1.1, "effectiveness experience"):
		return false
	if not _expect_close(scaling.get_item_quantity_multiplier(), 1.1, "effectiveness quantity"):
		return false
	stats.remove_modifier_source(&"rift")
	return _expect_close(
		stats.get_stat(StatIds.MONSTER_EFFECTIVENESS),
		10.0,
		"independent effectiveness source removal"
	)

func _test_reward_stat_catalog() -> bool:
	for stat_id in [
		StatIds.GOLD_GRANTED_MULTIPLIER,
		StatIds.ITEM_RARITY_MULTIPLIER,
		StatIds.MONSTER_RARITY_MULTIPLIER,
		StatIds.AREA_OF_EFFECT,
		StatIds.SLOW_CHANCE,
		StatIds.SLOW_MAGNITUDE,
		StatIds.SLOW_DURATION,
		StatIds.ACCURACY,
		StatIds.PHYSICAL_RESISTANCE_PENETRATION,
		StatIds.ELEMENTAL_RESISTANCE_PENETRATION,
		StatIds.ARMOUR_PENETRATION,
		StatIds.ARCANE_SHIELD_RECHARGE_START_SPEED,
		StatIds.EXPERIENCE_GAIN_MULTIPLIER,
		StatIds.PICKUP_RANGE,
		StatIds.INSTANT_PICKUP_CHANCE
	]:
		if catalog.get_definition(stat_id) == null:
			push_error("Reward stat is missing from catalog: %s" % stat_id)
			quit(1)
			return false
		var expected_default := (
			0.0
			if stat_id in [
				StatIds.ARCANE_SHIELD_RECHARGE_START_SPEED,
				StatIds.ACCURACY,
				StatIds.PHYSICAL_RESISTANCE_PENETRATION,
				StatIds.ELEMENTAL_RESISTANCE_PENETRATION,
				StatIds.ARMOUR_PENETRATION,
				StatIds.PICKUP_RANGE,
				StatIds.INSTANT_PICKUP_CHANCE
			]
			else 1.0
		)
		if not _expect_close(
			catalog.get_default(stat_id),
			expected_default,
			"utility/reward stat default"
		):
			return false
	var instant_pickup := catalog.get_definition(
		StatIds.INSTANT_PICKUP_CHANCE
	)
	if not _expect_close(
		instant_pickup.clamp_value(125.0),
		100.0,
		"instant pickup maximum"
	):
		return false
	return true

func _test_modifier_display_text() -> bool:
	var increased := _make_modifier(
		StatIds.ITEM_RARITY_MULTIPLIER,
		StatModifier.Operation.INCREASED,
		25.0
	)
	if ItemDefinition._format_modifier_line(increased) != "25% increased item rarity":
		push_error("Positive increased modifier display regressed.")
		quit(1)
		return false

	var decreased := _make_modifier(
		StatIds.GOLD_GRANTED_MULTIPLIER,
		StatModifier.Operation.INCREASED,
		-20.0
	)
	if ItemDefinition._format_modifier_line(decreased) != "20% decreased gold granted":
		push_error("Negative increased modifier display regressed.")
		quit(1)
		return false

	var less := _make_modifier(
		StatIds.ATTACK_RATE,
		StatModifier.Operation.MORE,
		-10.0
	)
	if ItemDefinition._format_modifier_line(less) != "10% less attack rate":
		push_error("Negative more modifier display regressed.")
		quit(1)
		return false
	return true

func _make_stats(
	domain: StringName,
	stat_id: StringName,
	base_value: float
) -> StatComponent:
	var values := {}
	if stat_id != &"":
		values[stat_id] = base_value
	return _make_stats_from_values(domain, values)

func _make_stats_from_values(
	domain: StringName,
	values: Dictionary
) -> StatComponent:
	var stats := StatComponent.new()
	root.add_child(stats)
	stats.domain = domain
	stats.catalog = catalog
	var profile := StatProfile.new()
	var entries: Array[StatValue] = []
	for stat_id in values:
		var entry := StatValue.new()
		entry.stat_id = stat_id
		entry.value = float(values[stat_id])
		entries.append(entry)
	profile.values = entries
	stats.base_profile = profile
	return stats

func _make_modifier(
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float
) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = StatModifier.Scope.GLOBAL
	return modifier

func _make_conversion(
	source_type: StringName,
	destination_type: StringName,
	percentage: float,
	mode: DamageConversion.Mode = DamageConversion.Mode.CONVERT
) -> DamageConversion:
	var conversion := DamageConversion.new()
	conversion.source_type = source_type
	conversion.destination_type = destination_type
	conversion.percentage = percentage
	conversion.mode = mode
	return conversion

func _expect_close(actual: float, expected: float, label: String) -> bool:
	if is_equal_approx(actual, expected):
		return true
	push_error("%s: expected %f, received %f" % [label, expected, actual])
	quit(1)
	return false
