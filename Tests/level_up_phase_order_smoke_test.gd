extends SceneTree

func _init() -> void:
	var game := load("res://Scenes/Game/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame

	var wave_director := game.get_node("Systems/WaveDirector") as WaveDirector
	var evaluation_director := game.get_node(
		"Systems/ItemEvaluationDirector"
	) as ItemEvaluationDirector
	var level_up_director := game.get_node("Systems/LevelUpDirector") as LevelUpDirector
	var progression := game.get_node(
		"World/Actors/Player/PlayerProgressionComponent"
	) as PlayerProgressionComponent
	var shoes := load("res://Data/Items/running_shoes.tres") as ItemDefinition

	wave_director.set_process(false)
	wave_director.reward_collection_show_duration = 0.0
	wave_director.current_wave_number = 1
	wave_director.state = WaveDirector.State.POST_WAVE
	evaluation_director.queue_item(shoes)
	progression.pending_level_ups = 2

	var shop_started := false
	wave_director.shop_started.connect(
		func(_completed_wave_number: int, _next_wave_number: int) -> void:
			shop_started = true
	)

	wave_director._complete_wave_after_cleanup(1)
	await process_frame
	await process_frame

	if shop_started:
		return _fail("Shop started while item evaluation was still pending.")
	if wave_director.state != WaveDirector.State.POST_WAVE:
		return _fail("WaveDirector left POST_WAVE before post-wave choices finished.")
	if not level_up_director.current_options.is_empty():
		return _fail("Level-up choices appeared before item evaluation finished.")

	evaluation_director.keep_current()
	await process_frame
	await process_frame

	if level_up_director.current_options.is_empty():
		return _fail("Level-up choices did not appear for pending level-ups.")

	level_up_director.choose_option(0)
	await process_frame
	if shop_started:
		return _fail("Shop started before all queued level-ups were chosen.")

	level_up_director.choose_option(0)
	await process_frame
	await process_frame

	if not shop_started:
		return _fail("Shop did not start after queued level-ups were resolved.")
	if wave_director.state != WaveDirector.State.SHOP:
		return _fail("WaveDirector did not enter SHOP after level-ups resolved.")

	print("level_up_phase_order_smoke_test: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
