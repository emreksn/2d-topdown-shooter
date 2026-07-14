extends SceneTree

const PROJECTILE_SCENE := preload("res://Scenes/Combat/projectile.tscn")
const ENEMY_SCENE := preload("res://Scenes/Enemies/chasing_enemy.tscn")

func _initialize() -> void:
	if not await _test_pierce_before_fork():
		return
	if not await _test_chain_redirects_after_hit():
		return
	print("projectile_behavior_smoke_test: PASS")
	quit(0)

func _test_pierce_before_fork() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var projectiles := Node2D.new()
	world.add_child(projectiles)

	var enemy_a := _spawn_enemy(world, Vector2(40.0, 0.0))
	var enemy_b := _spawn_enemy(world, Vector2(90.0, 24.0))
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectiles.add_child(projectile)
	projectile.global_position = Vector2.ZERO
	projectile.setup(
		Vector2.RIGHT,
		_make_packet(100.0),
		0.0,
		false,
		"",
		{
			&"projectile_scene": PROJECTILE_SCENE,
			&"target_group": &"enemies",
			&"pierce": 1,
			&"fork": 1,
			&"chain": 1,
			&"fork_damage_multiplier": 0.7
		}
	)

	projectile._on_area_entered(enemy_a.get_node("Hurtbox") as Area2D)
	await process_frame
	if projectile.is_queued_for_deletion():
		return _fail("Pierce did not keep the projectile alive after first hit.")
	if projectiles.get_child_count() != 1:
		return _fail("Fork happened before pierce was consumed.")

	projectile._on_area_entered(enemy_b.get_node("Hurtbox") as Area2D)
	await process_frame
	if projectiles.get_child_count() != 2:
		return _fail("Fork did not split into exactly two projectiles.")

	var fork := projectiles.get_child(0) as Projectile
	var enemy_c := _spawn_enemy(world, Vector2(140.0, -24.0))
	fork._on_area_entered(enemy_c.get_node("Hurtbox") as Area2D)
	var health := enemy_c.get_node("HealthComponent") as HealthComponent
	if not is_equal_approx(health.current_health, 30.0):
		return _fail("Forked projectile did not deal default 70% damage.")

	world.queue_free()
	await process_frame
	return true

func _test_chain_redirects_after_hit() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var projectiles := Node2D.new()
	world.add_child(projectiles)

	var enemy_a := _spawn_enemy(world, Vector2(40.0, 0.0))
	var enemy_b := _spawn_enemy(world, Vector2(120.0, 0.0))
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectiles.add_child(projectile)
	projectile.global_position = Vector2.ZERO
	projectile.setup(
		Vector2.RIGHT,
		_make_packet(25.0),
		0.0,
		false,
		"",
		{
			&"target_group": &"enemies",
			&"chain": 1,
			&"chain_radius": 200.0
		}
	)

	projectile._on_area_entered(enemy_a.get_node("Hurtbox") as Area2D)
	await process_frame
	if projectile.is_queued_for_deletion():
		return _fail("Chain did not keep the projectile alive after first hit.")

	projectile._on_area_entered(enemy_b.get_node("Hurtbox") as Area2D)
	await process_frame
	if not projectile.is_queued_for_deletion():
		return _fail("Projectile stayed alive after its final chain hit.")

	world.queue_free()
	await process_frame
	return true

func _spawn_enemy(parent: Node, position: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	parent.add_child(enemy)
	enemy.global_position = position
	return enemy

func _make_packet(amount: float) -> DamagePacket:
	return DamageResolver.build_direct_packet(
		amount,
		DamageTypeIds.PHYSICAL,
		null,
		[&"attack", &"projectile"],
		null
	)

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
