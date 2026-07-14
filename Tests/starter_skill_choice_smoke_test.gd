extends SceneTree

func _initialize() -> void:
	if not await _test_starter_skill_choice_replaces_defaults_after_weapon_pick():
		return
	print("starter_skill_choice_smoke_test: PASS")
	quit(0)

func _test_starter_skill_choice_replaces_defaults_after_weapon_pick() -> bool:
	var game := load("res://Scenes/Game/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var player := game.get_node("World/Actors/Player")
	var weapon_loadout := player.get_node(
		"WeaponLoadoutComponent"
	) as WeaponLoadoutComponent
	var skill_loadout := player.get_node(
		"ActiveSkillLoadoutComponent"
	) as ActiveSkillLoadoutComponent
	var skill_ui := game.get_node(
		"StarterSkillChoiceUI"
	) as StarterSkillChoiceUI
	if weapon_loadout == null or skill_loadout == null or skill_ui == null:
		return _fail("Starter skill choice dependencies were missing.")

	var rng := RandomNumberGenerator.new()
	rng.seed = 120
	var offer := WeaponOffer.create(
		load("res://Data/Weapons/wand.tres") as WeaponDefinition,
		ItemDefinition.Rarity.COMMON,
		rng
	)
	if not weapon_loadout.equip_offer(offer):
		return _fail("Could not equip wand for starter skill selection.")
	await process_frame
	await process_frame

	if not skill_ui._root_panel.visible:
		return _fail("Starter skill choice UI did not appear after weapon selection.")
	if not paused:
		return _fail("Starter skill choice UI did not pause the game.")
	if skill_loadout.get_skill(0) != null or skill_loadout.get_skill(1) != null:
		return _fail("Starter skill choice UI did not clear existing defaults.")

	var frost_nova := load(
		"res://Data/ActiveSkills/frost_nova.tres"
	) as ActiveSkillDefinition
	var dash := load("res://Data/ActiveSkills/dash.tres") as ActiveSkillDefinition
	skill_ui._on_skill_chosen(frost_nova)
	if skill_loadout.get_skill(0) != frost_nova:
		return _fail("First chosen starter skill was not equipped in slot 1.")
	if not paused:
		return _fail("Game unpaused before the second starter skill choice.")

	skill_ui._on_skill_chosen(dash)
	if skill_loadout.get_skill(1) != dash:
		return _fail("Second chosen starter skill was not equipped in slot 2.")
	if skill_ui._root_panel.visible:
		return _fail("Starter skill choice UI remained visible after two choices.")
	if paused:
		return _fail("Starter skill choice UI did not unpause after two choices.")

	game.queue_free()
	await process_frame
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
