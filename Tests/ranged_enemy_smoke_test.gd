extends SceneTree

func _initialize() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var projectiles := Node2D.new()
	projectiles.add_to_group(&"projectiles_container")
	world.add_child(projectiles)

	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	var enemy := load("res://Scenes/Enemies/ranged_enemy.tscn").instantiate() as Enemy
	world.add_child(player)
	world.add_child(enemy)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(320.0, 0.0)

	await create_timer(0.2).timeout
	var charge_position := enemy.global_position
	await create_timer(0.4).timeout
	if enemy.global_position.distance_to(charge_position) > 2.0:
		return _fail("Ranged enemy moved while charging inside its attack ring.")

	await create_timer(1.2).timeout
	if projectiles.get_child_count() <= 0:
		return _fail("Ranged enemy did not fire after its charge duration.")

	world.queue_free()
	await process_frame
	print("ranged_enemy_smoke_test: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
