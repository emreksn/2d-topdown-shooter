extends SceneTree

func _initialize() -> void:
	if not _test_clean_early_kill_breakpoints():
		return
	if not _test_early_wave_pressure_is_capped():
		return
	print("early_game_balance_smoke_test: PASS")
	quit(0)

func _test_clean_early_kill_breakpoints() -> bool:
	var base_health := _get_stat(
		"res://Data/Stats/enemy_stats.tres",
		StatIds.MAXIMUM_HEALTH
	)
	var wandering_health := _get_stat(
		"res://Data/Stats/wandering_enemy_stats.tres",
		StatIds.MAXIMUM_HEALTH
	)
	var ranged_health := _get_stat(
		"res://Data/Stats/ranged_enemy_stats.tres",
		StatIds.MAXIMUM_HEALTH
	)
	var pistol_damage := _get_stat(
		"res://Data/Stats/pistol_stats.tres",
		StatIds.PHYSICAL_DAMAGE
	)
	var machine_gun_damage := _get_stat(
		"res://Data/Stats/machine_gun_stats.tres",
		StatIds.PHYSICAL_DAMAGE
	)
	var wand_damage := _get_stat(
		"res://Data/Stats/wand_stats.tres",
		StatIds.ELEMENTAL_DAMAGE
	)

	if not is_equal_approx(base_health, 90.0):
		return _fail("Basic enemy health should support early clean kills.")
	if not is_equal_approx(wandering_health, 90.0):
		return _fail("Wandering enemy health should match the early baseline.")
	if not is_equal_approx(ranged_health, 60.0):
		return _fail("Ranged enemy health should stay lower in early waves.")
	if not is_equal_approx(pistol_damage * 3.0, base_health):
		return _fail("Pistol should cleanly 3-shot basic early enemies.")
	if not is_equal_approx(machine_gun_damage * 6.0, base_health):
		return _fail("Machine Gun should cleanly 6-shot basic early enemies.")
	if not is_equal_approx(wand_damage * 3.0, base_health):
		return _fail("Wand should cleanly 3-shot basic early enemies.")
	if not is_equal_approx(pistol_damage * 2.0, ranged_health):
		return _fail("Pistol should cleanly 2-shot ranged early enemies.")
	if not is_equal_approx(machine_gun_damage * 4.0, ranged_health):
		return _fail("Machine Gun should cleanly 4-shot ranged early enemies.")
	if not is_equal_approx(wand_damage * 2.0, ranged_health):
		return _fail("Wand should cleanly 2-shot ranged early enemies.")
	return true

func _test_early_wave_pressure_is_capped() -> bool:
	var wave_1 := load("res://Data/Waves/wave_01.tres") as WaveDefinition
	var wave_2 := load("res://Data/Waves/wave_02.tres") as WaveDefinition
	var wave_3 := load("res://Data/Waves/wave_03.tres") as WaveDefinition
	if wave_1.spawn_budget != 16 or wave_1.maximum_pack_size != 2:
		return _fail("Wave 1 should have reduced starter pressure.")
	if wave_2.spawn_budget != 30 or wave_2.maximum_pack_size != 3:
		return _fail("Wave 2 should ramp without overwhelming early builds.")
	if wave_3.spawn_budget != 45 or wave_3.maximum_pack_size != 4:
		return _fail("Wave 3 should keep pressure below the old spike.")
	return true

func _get_stat(path: String, stat_id: StringName) -> float:
	var profile := load(path) as StatProfile
	if profile == null:
		return 0.0
	return profile.get_base_value(stat_id, 0.0)

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
