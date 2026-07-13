extends SceneTree

func _initialize() -> void:
	if not _test_bulletstorm_channel_and_cleanup():
		return
	if not _test_dash_moves_and_cools_down():
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
	var weapon_offer := WeaponOffer.create(
		load("res://Data/Weapons/pistol.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(weapon_offer):
		return _fail("Could not equip pistol for Bulletstorm test.")
	var weapon := weapon_loadout.get_weapon(0) as ProjectileWeapon
	if weapon == null:
		return _fail("Equipped weapon was not a projectile weapon.")

	var skill := loadout.get_skill(0) as BulletstormVolleySkill
	if skill == null:
		return _fail("Bulletstorm was not equipped in slot 1.")
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
	if not weapon.active_skill_force_single_projectile:
		return _fail("Bulletstorm did not force single projectiles.")
	if not weapon.active_skill_sector_targeting:
		return _fail("Bulletstorm did not enable sector targeting.")
	if weapon.active_skill_sector_count != 12:
		return _fail("Bulletstorm did not use 12 targeting sectors.")
	if not is_equal_approx(weapon.active_skill_sector_target_chance, 0.5):
		return _fail("Bulletstorm did not use 50% sector target chance.")
	if not weapon.active_skill_use_actor_attack_rate:
		return _fail("Bulletstorm did not use player attack rate.")
	var seen_sectors := {}
	for _shot_index in range(12):
		var sector_index := weapon._take_random_sector_index()
		if seen_sectors.has(sector_index):
			return _fail("Bulletstorm reused a sector before all sectors fired.")
		seen_sectors[sector_index] = true
	if seen_sectors.size() != 12:
		return _fail("Bulletstorm did not visit all sectors before refilling.")
	var refilled_sector := weapon._take_random_sector_index()
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
	if weapon.active_skill_force_single_projectile:
		return _fail("Bulletstorm single projectile mode was not cleared.")
	if weapon.active_skill_sector_targeting:
		return _fail("Bulletstorm sector targeting was not cleared.")
	if weapon.active_skill_use_actor_attack_rate:
		return _fail("Bulletstorm player attack rate mode was not cleared.")

	player.queue_free()
	return true

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
