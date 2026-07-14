extends SceneTree

func _initialize() -> void:
	var root := Node2D.new()
	get_root().add_child(root)

	var enemy := load("res://Scenes/Enemies/chasing_enemy.tscn").instantiate() as Enemy
	enemy.global_position = Vector2(400.0, 0.0)
	root.add_child(enemy)
	enemy.configure_spawn_reward(2, 1.0, 1)

	var player := load("res://Scenes/player.tscn").instantiate() as Node2D
	player.global_position = Vector2.ZERO
	root.add_child(player)
	await process_frame

	var rewards := enemy.get_node("MonsterRewardComponent") as MonsterRewardComponent
	rewards.item_drop_pool = [
		load("res://Data/Items/running_shoes.tres") as ItemDefinition
	]
	var player_stats := player.get_node("StatComponent") as StatComponent
	var enemy_stats := enemy.get_node("StatComponent") as StatComponent

	if not is_equal_approx(enemy_stats.get_base_stat(StatIds.MAXIMUM_HEALTH), 90.0):
		_fail("Enemy base maximum health should be visible to inspection.")
		return
	if not is_equal_approx(rewards.get_expected_experience(player_stats), 10.0):
		_fail("Expected experience should resolve from spawn cost and stat multipliers.")
		return
	if not is_equal_approx(rewards.get_expected_gold(player_stats), 4.0):
		_fail("Expected gold should resolve from spawn cost and stat multipliers.")
		return
	if not is_equal_approx(rewards.get_expected_item_drop_count(player_stats), 0.04):
		_fail("Expected item drop count should match reward drop chance math.")
		return
	if not is_equal_approx(rewards.get_item_drop_chance_percent(player_stats), 4.0):
		_fail("Expected item drop chance should match fractional drop math.")
		return

	var rift_enemy := load("res://Scenes/Enemies/chasing_enemy.tscn").instantiate() as Enemy
	root.add_child(rift_enemy)
	rift_enemy.configure_spawn_context(
		[&"monster", &"rift"],
		{
			&"test:bountiful": (
				load("res://Data/Content/Variants/bountiful.tres")
				as ContentVariantDefinition
			).inherent_modifier_set
		}
	)
	var rift_health := rift_enemy.get_node("HealthComponent") as HealthComponent
	if not is_equal_approx(rift_health.maximum_health, 112.5):
		_fail("Enemy modified maximum health should be visible to inspection.")
		return
	if not is_equal_approx(rift_health.current_health, 112.5):
		_fail("Enemy should fill to modified maximum health when spawned fresh.")
		return

	print("monster_inspection_smoke_test: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
