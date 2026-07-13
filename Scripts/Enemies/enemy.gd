class_name Enemy
extends CharacterBody2D

@export var movement_speed: float = 100.0
@export var movement_behavior: MovementBehavior
@export var targeting_component: TargetingComponent
@export var health_component: HealthComponent
@export var stat_component: StatComponent
@export_category("Walk Squash")
@export_range(0.0, 0.25, 0.005) var walk_squash_strength: float = 0.08
@export_range(0.0, 30.0, 0.5) var walk_squash_rate: float = 8.0
@export_range(1.0, 1000.0, 1.0) var walk_squash_reference_speed: float = 100.0
@export_range(0.0, 20.0, 0.5) var walk_squash_transition_speed: float = 8.0
@export_category("Feedback")
@export var hit_flash_color := Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.01, 0.5, 0.01) var hit_flash_duration: float = 0.08
@export_range(0.0, 80.0, 1.0) var hit_bump_distance: float = 10.0
@export_range(0.01, 1.0, 0.01) var death_pop_duration: float = 0.22

var spawn_tags: Array[StringName] = [&"monster"]
var _runtime_modifier_registry: RuntimeModifierRegistry
var _runtime_source_ids: Array[StringName] = []
var _forced_chase_target: Node2D
var _walk_squash_amount: float = 0.0
var _walk_material: ShaderMaterial
var _base_scale := Vector2.ONE
var _base_position := Vector2.ZERO
var _hit_tween: Tween
var _death_tween: Tween
var _is_dying := false

@onready var _sprite: Sprite2D = $Sprite

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_base_scale = scale
	_base_position = position
	for child in get_children():
		if movement_behavior == null and child is MovementBehavior:
			movement_behavior = child
		elif targeting_component == null and child is TargetingComponent:
			targeting_component = child
		elif health_component == null and child is HealthComponent:
			health_component = child
		elif stat_component == null and child is StatComponent:
			stat_component = child

	if is_instance_valid(health_component):
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
	_setup_walk_squash()

func get_inspection_name() -> String:
	return name.to_pascal_case().replace("Enemy", " Enemy")

func _on_mouse_entered() -> void:
	if _is_dying:
		return
	for tooltip in get_tree().get_nodes_in_group(&"monster_inspect_tooltip"):
		if tooltip.has_method("show_enemy"):
			tooltip.show_enemy(self)

func _on_mouse_exited() -> void:
	for tooltip in get_tree().get_nodes_in_group(&"monster_inspect_tooltip"):
		if tooltip.has_method("hide_enemy"):
			tooltip.hide_enemy(self)

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if not is_instance_valid(movement_behavior):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target: Node2D
	if is_instance_valid(targeting_component):
		target = targeting_component.get_target()

	var direction := (
		global_position.direction_to(_forced_chase_target.global_position)
		if is_instance_valid(_forced_chase_target)
		else movement_behavior.get_movement_direction(self, target, delta)
	)
	var resolved_speed := (
		stat_component.get_stat(StatIds.MOVEMENT_SPEED, spawn_tags)
		if is_instance_valid(stat_component)
		else movement_speed
	)
	velocity = direction.normalized() * resolved_speed
	move_and_slide()
	_update_walk_squash(delta, resolved_speed)

func enter_wave_clearing(target: Node2D) -> void:
	_forced_chase_target = target

func _setup_walk_squash() -> void:
	if not is_instance_valid(_sprite) or not (_sprite.material is ShaderMaterial):
		return
	_walk_material = _sprite.material.duplicate() as ShaderMaterial
	_sprite.material = _walk_material
	_walk_material.set_shader_parameter("squash_strength", walk_squash_strength)
	_walk_material.set_shader_parameter("bottom_anchor", _sprite.get_rect().end.y)
	_walk_material.set_shader_parameter("walk_speed", walk_squash_rate)
	_walk_material.set_shader_parameter("flash_color", hit_flash_color)
	_walk_material.set_shader_parameter("flash_amount", 0.0)

func _update_walk_squash(delta: float, resolved_speed: float) -> void:
	if not is_instance_valid(_walk_material):
		return
	var target_amount := 0.0 if velocity.is_zero_approx() else 1.0
	_walk_squash_amount = move_toward(
		_walk_squash_amount,
		target_amount,
		delta * walk_squash_transition_speed
	)
	var speed_scale := resolved_speed / maxf(walk_squash_reference_speed, 1.0)
	_walk_material.set_shader_parameter("movement_amount", _walk_squash_amount)
	_walk_material.set_shader_parameter("walk_speed", walk_squash_rate * speed_scale)

func configure_spawn_reward(
	spawn_cost: int,
	rarity_reward_multiplier: float = 1.0,
	wave_number: int = 1
) -> void:
	var rewards := get_node_or_null("MonsterRewardComponent") as MonsterRewardComponent
	if is_instance_valid(rewards):
		rewards.configure(spawn_cost, rarity_reward_multiplier, wave_number)

func _on_damaged(_amount: float, source: Node) -> void:
	if _is_dying:
		return
	_play_hit_flash()
	_play_hit_bump(source)

func _on_died(_source: Node) -> void:
	if _is_dying:
		return
	_is_dying = true
	_on_mouse_exited()
	_disable_combat_collision()
	_play_death_pop()

func _play_hit_flash() -> void:
	if not is_instance_valid(_walk_material):
		return
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	_walk_material.set_shader_parameter("flash_color", hit_flash_color)
	_walk_material.set_shader_parameter("flash_amount", 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_method(
		_set_flash_amount,
		1.0,
		0.0,
		hit_flash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_hit_bump(source: Node) -> void:
	if hit_bump_distance <= 0.0:
		return
	var source_node := source as Node2D
	if not is_instance_valid(source_node):
		return
	var direction := source_node.global_position.direction_to(global_position)
	if direction.is_zero_approx():
		return
	var return_position := position
	position += direction * hit_bump_distance
	var bump_tween := create_tween()
	bump_tween.tween_property(
		self,
		"position",
		return_position,
		hit_flash_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_death_pop() -> void:
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	if is_instance_valid(_death_tween):
		_death_tween.kill()
	if is_instance_valid(_walk_material):
		_walk_material.set_shader_parameter("flash_color", hit_flash_color)
		_walk_material.set_shader_parameter("flash_amount", 1.0)
	z_index += 20
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(
		self,
		"scale",
		_base_scale * 1.18,
		death_pop_duration * 0.35
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		death_pop_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.chain().tween_property(
		self,
		"scale",
		_base_scale * 0.35,
		death_pop_duration * 0.65
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.finished.connect(queue_free, CONNECT_ONE_SHOT)

func _set_flash_amount(amount: float) -> void:
	if is_instance_valid(_walk_material):
		_walk_material.set_shader_parameter("flash_amount", amount)

func _disable_combat_collision() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
		elif child is Hurtbox:
			var hurtbox := child as Hurtbox
			hurtbox.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitorable", false)
			for hurtbox_child in hurtbox.get_children():
				if hurtbox_child is CollisionShape2D:
					(hurtbox_child as CollisionShape2D).set_deferred("disabled", true)
		if child.has_method("set_process"):
			child.set_process(false)
		if child.has_method("set_physics_process"):
			child.set_physics_process(false)

func configure_spawn_context(
	context_tags: Array[StringName],
	modifier_sources: Dictionary,
	runtime_registry: RuntimeModifierRegistry = null
) -> void:
	spawn_tags = context_tags.duplicate()
	var stats := get_node_or_null("StatComponent") as StatComponent
	if stats == null:
		return
	stats.set_default_context_tags(spawn_tags)
	for source_id in modifier_sources:
		stats.add_modifier_source(source_id, modifier_sources[source_id])
	if is_instance_valid(runtime_registry):
		_runtime_modifier_registry = runtime_registry
		if not _runtime_modifier_registry.sources_changed.is_connected(
			_sync_runtime_modifier_sources
		):
			_runtime_modifier_registry.sources_changed.connect(
				_sync_runtime_modifier_sources
			)
		_sync_runtime_modifier_sources()

func _sync_runtime_modifier_sources() -> void:
	var stats := get_node_or_null("StatComponent") as StatComponent
	if stats == null or not is_instance_valid(_runtime_modifier_registry):
		return
	for source_id in _runtime_source_ids:
		stats.remove_modifier_source(source_id)
	_runtime_source_ids.clear()
	var sources := _runtime_modifier_registry.get_applicable_sources(
		&"monster",
		spawn_tags
	)
	for source_id in sources:
		stats.add_modifier_source(source_id, sources[source_id])
		_runtime_source_ids.append(source_id)
