extends SceneTree

func _initialize() -> void:
	var game := load("res://Scenes/Game/game.tscn").instantiate() as Node
	root.add_child(game)

	var shop := game.get_node("Systems/ShopDirector") as ShopDirector
	var seen_ids := {}
	for item in shop.shop_items:
		if item == null:
			continue
		seen_ids[item.id] = int(seen_ids.get(item.id, 0)) + 1

	if seen_ids.get(&"elemental_shard", 0) != 1:
		return _fail("Shop pool should contain exactly one Elemental Shard.")
	for removed_id in [&"ember_shard", &"copper_coil", &"frost_chip"]:
		if seen_ids.has(removed_id):
			return _fail("Shop pool still contains removed item %s." % removed_id)

	var elemental_shard := load(
		"res://Data/Items/elemental_shard.tres"
	) as ItemDefinition
	var hot_lead := load("res://Data/Items/hot_lead.tres") as ItemDefinition
	if not _item_has_stat(elemental_shard, StatIds.ELEMENTAL_DAMAGE, 3.0):
		return _fail("Elemental Shard does not grant +3 elemental damage.")
	if not _item_has_stat(hot_lead, StatIds.ELEMENTAL_DAMAGE, 8.0):
		return _fail("Hot Lead does not grant +8 elemental damage.")

	var wand_stats := load("res://Data/Stats/wand_stats.tres") as StatProfile
	if not is_equal_approx(
		wand_stats.get_base_value(StatIds.ELEMENTAL_DAMAGE, 0.0),
		30.0
	):
		return _fail("Wand does not have elemental base damage.")
	if not is_equal_approx(
		wand_stats.get_base_value(StatIds.PHYSICAL_DAMAGE, 0.0),
		0.0
	):
		return _fail("Wand should not have physical base damage.")
	for physical_stats_path in [
		"res://Data/Stats/pistol_stats.tres",
		"res://Data/Stats/machine_gun_stats.tres",
		"res://Data/Stats/shotgun_stats.tres",
		"res://Data/Stats/op_test_pistol_stats.tres"
	]:
		var physical_stats := load(physical_stats_path) as StatProfile
		if not is_equal_approx(
			physical_stats.get_base_value(StatIds.ELEMENTAL_DAMAGE, 0.0),
			0.0
		):
			return _fail("%s should not have elemental base damage." % physical_stats_path)

	game.queue_free()
	await process_frame
	print("elemental_migration_smoke_test: PASS")
	quit(0)

func _item_has_stat(
	item: ItemDefinition,
	stat_id: StringName,
	value: float
) -> bool:
	if item == null or item.modifier_set == null:
		return false
	for modifier in item.modifier_set.modifiers:
		if (
			modifier != null
			and modifier.stat_id == stat_id
			and is_equal_approx(modifier.value, value)
		):
			return true
	return false

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
