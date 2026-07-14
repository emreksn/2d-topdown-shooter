extends SceneTree

func _initialize() -> void:
	if not _test_bulletstorm_channel_and_cleanup():
		return
	if not _test_pistol_variants_are_bulletstorm_eligible():
		return
	if not _test_dash_moves_and_cools_down():
		return
	if not _test_frost_nova_requires_elemental_weapon_and_slows():
		return
	print("active_skill_smoke_test: PASS")
	quit(0)

func _test_bulletstorm_channel_and_cleanup() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)

	var loadout := player.get_node(
		"ActiveSkillLoadoutComponent"
	) as ActiveSkillLoadoutComponent
	var weapon_loadout := player.get_node(
		"WeaponLoadoutComponent"
	) as WeaponLoadoutComponent
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var pistol_offer := WeaponOffer.create(
		load("res://Data/Weapons/pistol.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	var machine_gun_offer := WeaponOffer.create(
		load("res://Data/Weapons/machine_gun.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(pistol_offer):
		return _fail("Could not equip pistol for Bulletstorm test.")
	if not weapon_loadout.equip_offer(machine_gun_offer):
		return _fail("Could not equip machine gun for Bulletstorm test.")
	var weapon_1 := weapon_loadout.get_weapon(0) as ProjectileWeapon
	var weapon_2 := weapon_loadout.get_weapon(1) as ProjectileWeapon
	if weapon_1 == null or weapon_2 == null:
		return _fail("Equipped weapon was not a projectile weapon.")

	var skill := loadout.get_skill(0) as BulletstormVolleySkill
	if skill == null:
		return _fail("Bulletstorm was not equipped in slot 1.")
	var eligible_slots := loadout.get_eligible_weapon_slots(skill)
	if eligible_slots.size() != 2:
		return _fail("Bulletstorm did not see both physical ranged weapons.")
	if not loadout.bind_skill_to_weapon(0, 1):
		return _fail("Bulletstorm could not bind to weapon slot 2.")
	if loadout.get_bound_weapon_slot(1) != -1:
		return _fail("Dash should not have a bound weapon slot.")
	_add_weapon_tagged_modifier(
		weapon_2.stat_component,
		StatIds.PROJECTILE_SPEED,
		StatModifier.Operation.INCREASED,
		50.0,
		&"bulletstorm_volley",
		&"test:bulletstorm_projectile_speed"
	)
	var tagged_speed_before := weapon_2.stat_component.get_stat(
		StatIds.PROJECTILE_SPEED,
		weapon_2.get_attack_tags(),
		StatModifier.Scope.LOCAL
	)
	if not loadout.activate_slot(0):
		return _fail("Bulletstorm did not activate.")
	if not loadout.is_slot_active(0):
		return _fail("Bulletstorm slot was not marked active.")
	if player.get_node("StatComponent").get_modifier_source(
		BulletstormVolleySkill.PLAYER_SOURCE_ID
	) == null:
		return _fail("Bulletstorm did not apply player modifiers.")
	if not is_equal_approx(skill.attack_rate_more, 500.0):
		return _fail("Bulletstorm attack speed tuning was not 500% more.")
	if not is_equal_approx(skill.damage_less, 25.0):
		return _fail("Bulletstorm damage tuning was not 25% less.")
	if weapon_1.active_skill_force_single_projectile:
		return _fail("Bulletstorm affected an unbound weapon.")
	if weapon_1.get_attack_tags().has(&"bulletstorm_volley"):
		return _fail("Bulletstorm tagged an unbound weapon.")
	if not weapon_2.active_skill_force_single_projectile:
		return _fail("Bulletstorm did not force single projectiles on the bound weapon.")
	if not weapon_2.get_attack_tags().has(&"bulletstorm_volley"):
		return _fail("Bulletstorm did not tag the bound weapon attack context.")
	if not weapon_2.active_skill_sector_targeting:
		return _fail("Bulletstorm did not enable sector targeting on the bound weapon.")
	if weapon_2.active_skill_sector_count != 12:
		return _fail("Bulletstorm did not use 12 targeting sectors.")
	if not is_equal_approx(weapon_2.active_skill_sector_target_chance, 0.5):
		return _fail("Bulletstorm did not use 50% sector target chance.")
	if not weapon_2.active_skill_use_actor_attack_rate:
		return _fail("Bulletstorm did not use player attack rate.")
	if weapon_2.stat_component.get_modifier_source(
		BulletstormVolleySkill.WEAPON_SOURCE_ID
	) == null:
		return _fail("Bulletstorm did not apply bound weapon damage modifier.")
	var tagged_speed_during := weapon_2.stat_component.get_stat(
		StatIds.PROJECTILE_SPEED,
		weapon_2.get_attack_tags(),
		StatModifier.Scope.LOCAL
	)
	if not is_equal_approx(tagged_speed_during, tagged_speed_before * 1.5):
		return _fail("Bulletstorm did not inherit selected weapon skill-tagged modifiers.")
	var seen_sectors := {}
	for _shot_index in range(12):
		var sector_index := weapon_2._take_random_sector_index()
		if seen_sectors.has(sector_index):
			return _fail("Bulletstorm reused a sector before all sectors fired.")
		seen_sectors[sector_index] = true
	if seen_sectors.size() != 12:
		return _fail("Bulletstorm did not visit all sectors before refilling.")
	var refilled_sector := weapon_2._take_random_sector_index()
	if refilled_sector < 0 or refilled_sector >= 12:
		return _fail("Bulletstorm did not refill the sector bag correctly.")
	if loadout.activate_slot(0):
		return _fail("Bulletstorm activated again while on cooldown.")

	skill.tick(loadout, 0, skill.duration + 0.1)
	if loadout.is_slot_active(0):
		return _fail("Bulletstorm remained active after duration expired.")
	if player.get_node("StatComponent").get_modifier_source(
		BulletstormVolleySkill.PLAYER_SOURCE_ID
	) != null:
		return _fail("Bulletstorm player modifiers were not removed.")
	if weapon_2.active_skill_force_single_projectile:
		return _fail("Bulletstorm single projectile mode was not cleared.")
	if weapon_2.active_skill_sector_targeting:
		return _fail("Bulletstorm sector targeting was not cleared.")
	if weapon_2.active_skill_use_actor_attack_rate:
		return _fail("Bulletstorm player attack rate mode was not cleared.")
	if weapon_2.get_attack_tags().has(&"bulletstorm_volley"):
		return _fail("Bulletstorm attack tags were not cleared.")
	if weapon_2.stat_component.get_modifier_source(
		BulletstormVolleySkill.WEAPON_SOURCE_ID
	) != null:
		return _fail("Bulletstorm bound weapon modifier was not removed.")

	player.queue_free()
	return true

func _test_pistol_variants_are_bulletstorm_eligible() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var loadout := player.get_node(
		"ActiveSkillLoadoutComponent"
	) as ActiveSkillLoadoutComponent
	var weapon_loadout := player.get_node(
		"WeaponLoadoutComponent"
	) as WeaponLoadoutComponent
	var progression := player.get_node(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	var skill := loadout.get_skill(0) as BulletstormVolleySkill
	if skill == null:
		return _fail("Bulletstorm was not equipped for pistol variant eligibility test.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 46

	for path in [
		"res://Data/Weapons/pistol_slow.tres",
		"res://Data/Weapons/pistol_fork.tres",
		"res://Data/Weapons/pistol_chain.tres"
	]:
		var offer := WeaponOffer.create(
			load(path) as WeaponDefinition,
			ItemDefinition.Rarity.COMMON,
			rng
		)
		if not weapon_loadout.equip_offer(offer):
			return _fail("%s did not equip." % path)
		var eligible_slots := loadout.get_eligible_weapon_slots(skill)
		if eligible_slots != [0]:
			return _fail("%s was not Bulletstorm-eligible." % path)
		weapon_loadout.sell_weapon(0, progression)

	player.queue_free()
	return true

func _test_frost_nova_requires_elemental_weapon_and_slows() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var loadout := player.get_node(
		"ActiveSkillLoadoutComponent"
	) as ActiveSkillLoadoutComponent
	var weapon_loadout := player.get_node(
		"WeaponLoadoutComponent"
	) as WeaponLoadoutComponent
	var rng := RandomNumberGenerator.new()
	rng.seed = 45
	var pistol_offer := WeaponOffer.create(
		load("res://Data/Weapons/pistol.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(pistol_offer):
		return _fail("Could not equip pistol for Frost Nova rejection test.")
	var frost_nova := load("res://Data/ActiveSkills/frost_nova.tres") as FrostNovaSkill
	if frost_nova == null:
		return _fail("Frost Nova resource did not load.")
	if not loadout.equip_skill(1, frost_nova):
		return _fail("Could not equip Frost Nova.")
	if loadout.activate_slot(1):
		return _fail("Frost Nova activated without an elemental weapon.")

	var progression := player.get_node(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	weapon_loadout.sell_weapon(0, progression)
	var wand_offer := WeaponOffer.create(
		load("res://Data/Weapons/wand.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(wand_offer):
		return _fail("Could not equip wand for Frost Nova test.")
	if loadout.get_bound_weapon_slot(1) != 0:
		return _fail("Frost Nova did not bind to the elemental weapon.")
	var wand := weapon_loadout.get_weapon(0)
	if not is_instance_valid(wand):
		return _fail("Frost Nova bound weapon was missing.")

	_add_player_damage_modifier(
		player.get_node("StatComponent") as StatComponent,
		StatIds.ELEMENTAL_DAMAGE,
		20.0
	)
	_add_weapon_damage_modifier(
		wand.stat_component,
		StatIds.ELEMENTAL_DAMAGE,
		StatModifier.Operation.MORE,
		100.0
	)
	_add_weapon_damage_modifier(
		wand.stat_component,
		StatIds.AREA_OF_EFFECT,
		StatModifier.Operation.INCREASED,
		30.0
	)
	var enemy := _spawn_enemy_at(player.global_position + Vector2(80.0, 0.0))
	var far_enemy := _spawn_enemy_at(player.global_position + Vector2(300.0, 0.0))
	var effects := Node2D.new()
	effects.add_to_group(&"effects_container")
	root.add_child(effects)
	var far_health := far_enemy.get_node("HealthComponent") as HealthComponent
	enemy.global_position = player.global_position + Vector2(80.0, 0.0)
	var health := enemy.get_node("HealthComponent") as HealthComponent
	var status := enemy.get_node("StatusEffectComponent") as StatusEffectComponent
	var before_health := health.current_health
	var far_before_health := far_health.current_health
	if not loadout.activate_slot(1):
		return _fail("Frost Nova did not activate with an elemental weapon.")
	if not is_equal_approx(health.current_health, before_health - 56.0):
		return _fail("Frost Nova did not inherit selected weapon damage modifiers.")
	if not is_equal_approx(far_health.current_health, far_before_health - 56.0):
		return _fail("Frost Nova did not inherit selected weapon area modifiers.")
	if not is_equal_approx(status.get_slow_magnitude(), 25.0):
		return _fail("Frost Nova did not apply 25% slow.")
	if effects.get_child_count() != 1:
		return _fail("Frost Nova did not spawn a visual effect.")
	var effect := effects.get_child(0) as FrostNovaEffect
	if effect == null:
		return _fail("Frost Nova spawned the wrong visual effect type.")
	if not is_equal_approx(effect.radius, 338.0):
		return _fail("Frost Nova visual did not use the resolved AoE radius.")

	enemy.queue_free()
	far_enemy.queue_free()
	effects.queue_free()
	player.queue_free()
	return true

func _spawn_enemy_at(position: Vector2) -> Node2D:
	var enemy := load("res://Scenes/enemy.tscn").instantiate() as Node2D
	enemy.global_position = position
	root.add_child(enemy)
	return enemy

func _add_player_damage_modifier(
	stats: StatComponent,
	stat_id: StringName,
	value: float
) -> void:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = StatModifier.Operation.FLAT
	modifier.value = value
	modifier.scope = StatModifier.Scope.GLOBAL
	modifier.target_domain = &"player"
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [modifier]
	stats.add_modifier_source(&"test:frost_nova_damage", modifier_set)

func _add_weapon_damage_modifier(
	stats: StatComponent,
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float
) -> void:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = StatModifier.Scope.LOCAL
	modifier.target_domain = &"weapon"
	modifier.required_all_tags = [&"frost_nova"]
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [modifier]
	stats.add_modifier_source(&"test:frost_nova_weapon_damage", modifier_set)

func _add_weapon_tagged_modifier(
	stats: StatComponent,
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float,
	required_tag: StringName,
	source_id: StringName
) -> void:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = StatModifier.Scope.LOCAL
	modifier.target_domain = &"weapon"
	modifier.required_all_tags = [required_tag]
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [modifier]
	stats.add_modifier_source(source_id, modifier_set)

func _test_dash_moves_and_cools_down() -> bool:
	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	root.add_child(player)
	var loadout := player.get_node(
		"ActiveSkillLoadoutComponent"
	) as ActiveSkillLoadoutComponent
	loadout.last_move_direction = Vector2.RIGHT

	var start_position := player.global_position
	if not loadout.activate_slot(1):
		return _fail("Dash did not activate.")
	if player.dashTimeRemaining <= 0.0:
		return _fail("Dash did not start a timed movement burst.")
	if not is_equal_approx(player.global_position.x, start_position.x):
		return _fail("Dash moved the player instantly instead of over time.")
	if player.dashVelocity.x <= 0.0:
		return _fail("Dash did not set forward dash velocity.")
	if loadout.get_cooldown_remaining(1) <= 0.0:
		return _fail("Dash did not start cooldown.")
	if loadout.activate_slot(1):
		return _fail("Dash activated again while on cooldown.")

	player.queue_free()
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
