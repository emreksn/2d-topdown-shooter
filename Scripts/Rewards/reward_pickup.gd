class_name RewardPickup
extends Node2D

enum RewardType { GOLD, EXPERIENCE }

@export_range(1.0, 1000.0, 1.0) var collection_distance: float = 26.0
@export_range(1.0, 2000.0, 1.0) var attraction_speed: float = 360.0
@export_range(0.0, 1000.0, 1.0) var initial_scatter: float = 42.0
@export_range(0.1, 5.0, 0.05) var forced_collection_duration: float = 0.55

var reward_type: RewardType = RewardType.GOLD
var amount: float = 0.0
var target: Node2D
var _velocity := Vector2.ZERO
var _is_forced_collecting: bool = false

func _ready() -> void:
	_velocity = Vector2.from_angle(randf_range(0.0, TAU)) * initial_scatter
	queue_redraw()

func setup(type: RewardType, reward_amount: float, player: Node2D) -> void:
	reward_type = type
	amount = reward_amount
	target = player
	queue_redraw()
	if (
		is_instance_valid(target)
		and global_position.distance_to(target.global_position)
		<= collection_distance
	):
		_collect()

func _physics_process(delta: float) -> void:
	if _is_forced_collecting:
		return
	if not is_instance_valid(target):
		var tree := get_tree()
		if tree == null:
			return
		target = tree.get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= collection_distance:
		_collect()
		return
	if distance <= _get_pickup_range():
		_velocity = global_position.direction_to(target.global_position) * attraction_speed
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, delta * 120.0)
	global_position += _velocity * delta

func collect_for(player: Node2D) -> void:
	if _is_forced_collecting:
		return
	target = player
	if not is_instance_valid(target):
		_collect()
		return
	_is_forced_collecting = true
	z_index = 50
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		self,
		"global_position",
		target.global_position,
		forced_collection_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(
		self,
		"scale",
		Vector2(1.8, 1.8),
		forced_collection_duration * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(
		self,
		"scale",
		Vector2(0.25, 0.25),
		forced_collection_duration * 0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_collect, CONNECT_ONE_SHOT)

func _draw() -> void:
	var color := Color(1.0, 0.78, 0.12, 1.0) if reward_type == RewardType.GOLD else Color(0.2, 0.65, 1.0, 1.0)
	draw_circle(Vector2.ZERO, 9.0, Color(color, 0.2))
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, color, 2.0, true)

func _get_pickup_range() -> float:
	var stats := target.get_node_or_null("StatComponent") as StatComponent
	return stats.get_stat(StatIds.PICKUP_RANGE) if is_instance_valid(stats) else 0.0

func _collect() -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var progression := target.get_node_or_null("PlayerProgressionComponent") as PlayerProgressionComponent
	if not is_instance_valid(progression):
		queue_free()
		return
	if reward_type == RewardType.GOLD:
		progression.add_gold(maxi(1, roundi(amount)))
	else:
		progression.add_experience(amount)
	queue_free()
