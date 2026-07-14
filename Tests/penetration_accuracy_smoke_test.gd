extends SceneTree

var catalog: StatCatalog

func _initialize() -> void:
	catalog = load("res://Data/Stats/stat_catalog.tres") as StatCatalog
	if not _test_accuracy_reduces_evasion():
		return
	if not _test_resistance_penetration():
		return
	if not _test_armour_penetration():
		return
	quit(0)

func _test_accuracy_reduces_evasion() -> bool:
	var packet := _make_packet(100.0, DamageTypeIds.PHYSICAL, _make_actor_stats({}))
	var defender := _make_stats(&"monster", {StatIds.EVASION: 500.0})

	var result := DamageResolver.resolve_incoming(packet, defender, 0.1, 1.0)
	if not result.was_evaded:
		push_error("Baseline evasion should evade at the fixed roll.")
		quit(1)
		return false

	packet.source = _make_actor_stats({StatIds.ACCURACY: 500.0}).get_parent()
	result = DamageResolver.resolve_incoming(packet, defender, 0.1, 1.0)
	if result.was_evaded:
		push_error("Accuracy did not reduce evasion before the evade roll.")
		quit(1)
		return false
	return _expect_close(result.total_damage, 100.0, "accuracy hit damage")

func _test_resistance_penetration() -> bool:
	var attacker_stats := _make_actor_stats({
		StatIds.ELEMENTAL_RESISTANCE_PENETRATION: 20.0
	})
	var packet := _make_packet(100.0, DamageTypeIds.ELEMENTAL, attacker_stats)
	var defender := _make_stats(
		&"monster",
		{StatIds.ELEMENTAL_RESISTANCE: 50.0}
	)
	var result := DamageResolver.resolve_incoming(packet, defender, 1.0, 1.0)
	return _expect_close(
		result.total_damage,
		70.0,
		"elemental resistance penetration"
	)

func _test_armour_penetration() -> bool:
	var defender := _make_stats(&"monster", {StatIds.ARMOUR: 800.0})
	var packet := _make_packet(100.0, DamageTypeIds.PHYSICAL, _make_actor_stats({}))
	var result := DamageResolver.resolve_incoming(packet, defender, 1.0, 1.0)
	if not _expect_close(result.total_damage, 55.0, "baseline armour reduction"):
		return false

	packet.source = _make_actor_stats({StatIds.ARMOUR_PENETRATION: 800.0}).get_parent()
	result = DamageResolver.resolve_incoming(packet, defender, 1.0, 1.0)
	return _expect_close(result.total_damage, 100.0, "armour penetration")

func _make_packet(
	amount: float,
	damage_type: StringName,
	attacker_stats: StatComponent
) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.slices = [DamageSlice.new(amount, damage_type)]
	packet.tags = [&"attack"]
	packet.source = attacker_stats.get_parent()
	return packet

func _make_actor_stats(values: Dictionary) -> StatComponent:
	var source := Node.new()
	root.add_child(source)
	var stats := _make_stats(&"player", values)
	root.remove_child(stats)
	source.add_child(stats)
	stats.name = "StatComponent"
	return stats

func _make_stats(domain: StringName, values: Dictionary) -> StatComponent:
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

func _expect_close(actual: float, expected: float, label: String) -> bool:
	if is_equal_approx(actual, expected):
		return true
	push_error("%s: expected %f, received %f" % [label, expected, actual])
	quit(1)
	return false
