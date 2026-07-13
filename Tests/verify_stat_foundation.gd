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
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.LIGHTNING, 50.0),
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.FIRE, 50.0),
		_make_conversion(
			DamageTypeIds.PHYSICAL,
			DamageTypeIds.COLD,
			25.0,
			DamageConversion.Mode.GAIN_AS_EXTRA
		)
	]
	var packet := DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		conversions,
		[&"attack", &"projectile"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 0.0, "converted physical"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.LIGHTNING), 50.0, "lightning conversion"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.FIRE), 50.0, "fire conversion"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.COLD), 25.0, "gain as extra"):
		return false

	var overflow: Array[DamageConversion] = [
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.LIGHTNING, 80.0),
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.FIRE, 80.0)
	]
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		overflow,
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.LIGHTNING), 50.0, "scaled conversion one"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.FIRE), 50.0, "scaled conversion two"):
		return false

	var skill_conversion := _make_conversion(
		DamageTypeIds.PHYSICAL,
		DamageTypeIds.LIGHTNING,
		60.0
	)
	skill_conversion.priority = DamageConversion.Priority.SKILL
	var other_conversion := _make_conversion(
		DamageTypeIds.PHYSICAL,
		DamageTypeIds.FIRE,
		80.0
	)
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		[skill_conversion, other_conversion],
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.LIGHTNING), 60.0, "skill conversion priority"):
		return false
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.FIRE), 40.0, "remaining conversion capacity"):
		return false

	var chain: Array[DamageConversion] = [
		_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.LIGHTNING, 100.0),
		_make_conversion(DamageTypeIds.LIGHTNING, DamageTypeIds.COLD, 100.0),
		_make_conversion(DamageTypeIds.COLD, DamageTypeIds.FIRE, 100.0)
	]
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		chain,
		[&"attack"],
		null
	)
	if not _expect_close(packet.get_damage_by_type(DamageTypeIds.FIRE), 100.0, "chained conversion"):
		return false

	var damage_modifier := _make_modifier(
		StatIds.DAMAGE,
		StatModifier.Operation.INCREASED,
		20.0
	)
	damage_modifier.required_any_tags = [
		DamageTypeIds.PHYSICAL,
		DamageTypeIds.FIRE
	]
	var source := ModifierSet.new()
	source.modifiers = [damage_modifier]
	actor.add_modifier_source(&"hybrid", source)
	packet = DamageResolver.build_outgoing_packet(
		weapon,
		actor,
		[_make_conversion(DamageTypeIds.PHYSICAL, DamageTypeIds.FIRE, 100.0)],
		[&"attack"],
		null
	)
	return _expect_close(
		packet.get_damage_by_type(DamageTypeIds.FIRE),
		120.0,
		"one modifier matching original and destination once"
	)

func _test_defenses() -> bool:
	var packet := DamagePacket.new()
	packet.slices = [DamageSlice.new(100.0, DamageTypeIds.FIRE)]
	var defender := _make_stats(&"monster", StatIds.FIRE_RESISTANCE, 75.0)
	var result := DamageResolver.resolve_incoming(packet, defender)
	if not _expect_close(result.total_damage, 25.0, "75 resistance"):
		return false

	defender = _make_stats(&"monster", StatIds.FIRE_RESISTANCE, -20.0)
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
	if not _expect_close(scaling.get_effectiveness_toughness_factor(), 1.2, "effectiveness toughness"):
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
	var stats := StatComponent.new()
	root.add_child(stats)
	stats.domain = domain
	stats.catalog = catalog
	var profile := StatProfile.new()
	if stat_id != &"":
		var entry := StatValue.new()
		entry.stat_id = stat_id
		entry.value = base_value
		profile.values = [entry]
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
