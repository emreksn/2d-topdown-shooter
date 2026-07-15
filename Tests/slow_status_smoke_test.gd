extends SceneTree

const ENEMY_SCENE := preload("res://Scenes/Enemies/chasing_enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://Scenes/Enemies/ranged_enemy.tscn")
const PROJECTILE_SCENE := preload("res://Scenes/Combat/projectile.tscn")

func _initialize() -> void:
	if not await _test_slow_reduces_movement_stat():
		return
	if not await _test_slow_action_breakpoints():
		return
	if not await _test_projectile_applies_slow():
		return
	print("slow_status_smoke_test: PASS")
	quit(0)

func _test_slow_reduces_movement_stat() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	world.add_child(enemy)
	await process_frame

	var stats := enemy.get_node("StatComponent") as StatComponent
	var statuses := enemy.get_node("StatusEffectComponent") as StatusEffectComponent
	var base_speed := stats.get_stat(StatIds.MOVEMENT_SPEED)
	statuses.apply_slow(40.0, 1.0)
	var slowed_speed := stats.get_stat(StatIds.MOVEMENT_SPEED)
	if not is_equal_approx(slowed_speed, base_speed * 0.6):
		return _fail("40% Slow did not apply as MORE movement speed reduction.")
	if not _expect_slow_shader_amount(enemy, 40.0 / 70.0, "slow shader active amount"):
		return false

	await create_timer(1.1).timeout
	if not is_equal_approx(stats.get_stat(StatIds.MOVEMENT_SPEED), base_speed):
		return _fail("Slow movement modifier did not expire.")
	if not _expect_slow_shader_amount(enemy, 0.0, "slow shader expired amount"):
		return false

	world.queue_free()
	await process_frame
	return true

func _test_slow_action_breakpoints() -> bool:
	var statuses := StatusEffectComponent.new()
	root.add_child(statuses)

	statuses.apply_slow(20.0, 1.0)
	if not is_equal_approx(statuses.get_action_speed_multiplier(), 1.0):
		return _fail("Light Slow should not reduce action speed.")

	statuses.apply_slow(30.0, 1.0)
	if not is_equal_approx(statuses.get_action_speed_multiplier(), 0.85):
		return _fail("Medium Slow should reduce action speed by 15%.")

	statuses.apply_slow(55.0, 1.0)
	if not is_equal_approx(statuses.get_action_speed_multiplier(), 0.7):
		return _fail("Heavy Slow should reduce action speed by 30%.")

	statuses.queue_free()
	await process_frame
	return true

func _test_projectile_applies_slow() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var enemy := RANGED_ENEMY_SCENE.instantiate() as Enemy
	world.add_child(enemy)
	await process_frame
	var statuses := enemy.get_node("StatusEffectComponent") as StatusEffectComponent

	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	world.add_child(projectile)
	projectile.setup(
		Vector2.RIGHT,
		_make_packet(1.0),
		0.0,
		false,
		"",
		{
			&"slow_chance": 100.0,
			&"slow_magnitude": 50.0,
			&"slow_duration": 2.0
		}
	)
	projectile._on_area_entered(enemy.get_node("Hurtbox") as Area2D)
	if not is_equal_approx(statuses.get_slow_magnitude(), 50.0):
		return _fail("Projectile did not apply configured Slow.")

	world.queue_free()
	await process_frame
	return true

func _make_packet(amount: float) -> DamagePacket:
	return DamageResolver.build_direct_packet(
		amount,
		DamageTypeIds.PHYSICAL,
		null,
		[&"attack", &"projectile"],
		null
	)

func _expect_slow_shader_amount(
	enemy: Enemy,
	expected: float,
	label: String
) -> bool:
	var sprite := enemy.get_node("Sprite") as Sprite2D
	var material := sprite.material as ShaderMaterial
	if material == null:
		return _fail("%s missing shader material." % label)
	var actual := float(material.get_shader_parameter("slow_amount"))
	if absf(actual - expected) > 0.001:
		return _fail("%s expected %f, got %f." % [label, expected, actual])
	return true

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
