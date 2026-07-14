extends SceneTree

func _initialize() -> void:
	if not _test_wand_uses_only_elemental_base_damage():
		return
	if not _test_physical_weapon_uses_only_physical_base_damage():
		return
	if not _test_weapon_added_damage_multiplier_scales_actor_damage():
		return
	print("weapon_damage_type_filter_smoke_test: PASS")
	quit(0)

func _test_wand_uses_only_elemental_base_damage() -> bool:
	var wand := _instantiate_weapon("res://Data/Weapons/wand.tres") as ProjectileWeapon
	if wand == null:
		return _fail("Wand did not instantiate as a ProjectileWeapon.")
	wand.resolve_stat_components()
	_add_flat_modifier(wand.stat_component, StatIds.PHYSICAL_DAMAGE, 999.0)

	var packet := DamageResolver.build_outgoing_packet(
		wand.stat_component,
		null,
		[],
		wand.get_attack_tags(),
		null,
		wand.allowed_base_damage_types
	)
	if not is_equal_approx(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 30.0):
		return _fail("Wand did not use its elemental base damage.")
	if not is_equal_approx(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 0.0):
		return _fail("Wand used physical damage as base damage.")
	wand.free()
	return true

func _test_physical_weapon_uses_only_physical_base_damage() -> bool:
	var pistol := _instantiate_weapon("res://Data/Weapons/pistol.tres") as ProjectileWeapon
	if pistol == null:
		return _fail("Pistol did not instantiate as a ProjectileWeapon.")
	pistol.resolve_stat_components()
	_add_flat_modifier(pistol.stat_component, StatIds.ELEMENTAL_DAMAGE, 999.0)

	var packet := DamageResolver.build_outgoing_packet(
		pistol.stat_component,
		null,
		[],
		pistol.get_attack_tags(),
		null,
		pistol.allowed_base_damage_types
	)
	if not is_equal_approx(packet.get_damage_by_type(DamageTypeIds.PHYSICAL), 30.0):
		return _fail("Pistol did not use its physical base damage.")
	if not is_equal_approx(packet.get_damage_by_type(DamageTypeIds.ELEMENTAL), 0.0):
		return _fail("Pistol used elemental damage as base damage.")
	pistol.free()
	return true

func _test_weapon_added_damage_multiplier_scales_actor_damage() -> bool:
	var pistol := _instantiate_weapon("res://Data/Weapons/pistol.tres") as ProjectileWeapon
	if pistol == null:
		return _fail("Pistol did not instantiate as a ProjectileWeapon.")
	pistol.resolve_stat_components()

	var actor_stats := _make_actor_stats()
	_add_actor_modifiers(
		actor_stats,
		[
			_make_actor_modifier(
				StatIds.PHYSICAL_DAMAGE,
				StatModifier.Operation.FLAT,
				10.0
			),
			_make_actor_modifier(
				StatIds.PHYSICAL_DAMAGE,
				StatModifier.Operation.INCREASED,
				100.0
			),
			_make_actor_modifier(
				StatIds.DAMAGE,
				StatModifier.Operation.MORE,
				50.0
			)
		]
	)

	var packet := DamageResolver.build_outgoing_packet(
		pistol.stat_component,
		actor_stats,
		[],
		pistol.get_attack_tags(),
		null,
		pistol.allowed_base_damage_types,
		pistol.added_damage_multiplier
	)
	var expected_damage := 30.0 + (10.0 * 2.0 * 1.5 * pistol.added_damage_multiplier)
	if not is_equal_approx(
		packet.get_damage_by_type(DamageTypeIds.PHYSICAL),
		expected_damage
	):
		return _fail("Pistol did not scale resolved actor damage by its weapon multiplier.")
	pistol.free()
	actor_stats.free()
	return true

func _instantiate_weapon(definition_path: String) -> Weapon:
	var definition := load(definition_path) as WeaponDefinition
	if definition == null or definition.weapon_scene == null:
		return null
	var weapon := definition.weapon_scene.instantiate() as Weapon
	if weapon != null:
		weapon.weapon_definition = definition
		root.add_child(weapon)
	return weapon

func _add_flat_modifier(
	stats: StatComponent,
	stat_id: StringName,
	value: float
) -> void:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = StatModifier.Operation.FLAT
	modifier.value = value
	modifier.scope = StatModifier.Scope.LOCAL
	modifier.target_domain = &"weapon"
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [modifier]
	stats.add_modifier_source(StringName("test:%s" % stat_id), modifier_set)

func _make_actor_stats() -> StatComponent:
	var stats := StatComponent.new()
	stats.domain = &"player"
	stats.catalog = load("res://Data/Stats/stat_catalog.tres") as StatCatalog
	root.add_child(stats)
	return stats

func _make_actor_modifier(
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float
) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = StatModifier.Scope.GLOBAL
	modifier.target_domain = &"player"
	return modifier

func _add_actor_modifiers(
	stats: StatComponent,
	modifiers: Array[StatModifier]
) -> void:
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = modifiers
	stats.add_modifier_source(&"test:actor_damage", modifier_set)

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
