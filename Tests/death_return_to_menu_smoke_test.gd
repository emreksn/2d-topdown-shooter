extends SceneTree

func _initialize() -> void:
	if not await _test_death_feedback_returns_to_main_menu():
		return
	print("death_return_to_menu_smoke_test: PASS")
	quit(0)

func _test_death_feedback_returns_to_main_menu() -> bool:
	var scene := Node2D.new()
	scene.name = "DeathTestScene"
	root.add_child(scene)
	current_scene = scene

	var actor := Node2D.new()
	scene.add_child(actor)

	var health := HealthComponent.new()
	var death_reload := ReloadSceneOnDeath.new()
	death_reload.health_component = health
	death_reload.delay = 0.05
	actor.add_child(health)
	actor.add_child(death_reload)

	await process_frame
	health.died.emit(null)
	await create_timer(0.02, true).timeout
	if not get_tree().paused:
		return _fail("Death feedback did not pause the run.")
	if scene.get_child_count() < 2:
		return _fail("Death feedback overlay was not added to the current scene.")

	await create_timer(0.1, true).timeout
	if get_tree().paused:
		return _fail("Death return did not unpause the tree.")
	if current_scene == scene:
		return _fail("Death return did not leave the current run scene.")
	return true

func _fail(message: String) -> bool:
	push_error(message)
	get_tree().paused = false
	quit(1)
	return false
