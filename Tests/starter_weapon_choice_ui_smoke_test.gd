extends SceneTree

func _initialize() -> void:
	if not await _test_starter_weapon_choice_uses_scrollable_grid():
		return
	print("starter_weapon_choice_ui_smoke_test: PASS")
	quit(0)

func _test_starter_weapon_choice_uses_scrollable_grid() -> bool:
	var game := load("res://Scenes/Game/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var ui := game.get_node("StarterWeaponChoiceUI") as StarterWeaponChoiceUI
	if ui == null:
		return _fail("Starter weapon choice UI was missing.")
	if not ui._root_panel.visible:
		return _fail("Starter weapon choice UI was not visible at run start.")
	if ui._choice_grid == null:
		return _fail("Starter weapon choice UI did not build a choice grid.")
	if ui._choice_grid.columns != 4:
		return _fail("Starter weapon choice grid was not four columns.")
	if ui._choice_grid.get_child_count() < 5:
		return _fail("Starter weapon choice grid did not include starter weapons.")
	var scroll := ui._choice_grid.get_parent() as ScrollContainer
	if scroll == null:
		return _fail("Starter weapon choice grid was not inside a ScrollContainer.")
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return _fail("Starter weapon choice UI should not require horizontal scrolling.")
	if scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return _fail("Starter weapon choice UI vertical scrolling was disabled.")

	game.queue_free()
	await process_frame
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
