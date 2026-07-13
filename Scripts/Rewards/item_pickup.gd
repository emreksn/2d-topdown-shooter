class_name ItemPickup
extends Node2D

@export_range(1.0, 1000.0, 1.0) var collection_distance: float = 28.0
@export_range(1.0, 2000.0, 1.0) var attraction_speed: float = 320.0
@export_range(0.0, 1000.0, 1.0) var initial_scatter: float = 36.0
@export_range(0.1, 5.0, 0.05) var forced_collection_duration: float = 0.55

var item: ItemDefinition
var target: Node2D
var _velocity := Vector2.ZERO
var _is_forced_collecting: bool = false

@onready var _label: Label = $Label

func _ready() -> void:
	_velocity = Vector2.from_angle(randf_range(0.0, TAU)) * initial_scatter
	_refresh_label()
	queue_redraw()

func setup(drop_item: ItemDefinition, player: Node2D) -> void:
	item = drop_item
	target = player
	_refresh_label()
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
		Vector2(1.35, 1.35),
		forced_collection_duration * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(
		self,
		"scale",
		Vector2(0.2, 0.2),
		forced_collection_duration * 0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_collect, CONNECT_ONE_SHOT)

func _draw() -> void:
	var color := _get_rarity_color()
	draw_circle(Vector2.ZERO, 13.0, Color(color, 0.18))
	draw_circle(Vector2.ZERO, 7.0, color)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 32, color, 2.0, true)

func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	_label.text = item.display_name if item != null else "Item"
	_label.add_theme_color_override("font_color", _get_rarity_color())

func _get_pickup_range() -> float:
	var stats := target.get_node_or_null("StatComponent") as StatComponent
	return stats.get_stat(StatIds.PICKUP_RANGE) if is_instance_valid(stats) else 0.0

func _collect() -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var evaluation_director := get_tree().get_first_node_in_group(
		&"item_evaluation_director"
	) as ItemEvaluationDirector
	if is_instance_valid(evaluation_director) and item != null:
		evaluation_director.queue_item(item)
		queue_free()
		return
	var inventory := target.get_node_or_null(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	if is_instance_valid(inventory) and item != null:
		inventory.add_item(item)
	queue_free()

func _get_rarity_color() -> Color:
	if item == null:
		return Color.WHITE
	match item.rarity:
		ItemDefinition.Rarity.COMMON:
			return Color(0.86, 0.88, 0.9, 1.0)
		ItemDefinition.Rarity.UNCOMMON:
			return Color(0.28, 0.95, 0.45, 1.0)
		ItemDefinition.Rarity.RARE:
			return Color(0.3, 0.62, 1.0, 1.0)
		ItemDefinition.Rarity.LEGENDARY:
			return Color(1.0, 0.72, 0.24, 1.0)
		ItemDefinition.Rarity.TRADEOFF:
			return Color(1.0, 0.38, 0.28, 1.0)
		ItemDefinition.Rarity.UNIQUE:
			return Color(0.85, 0.45, 1.0, 1.0)
		_:
			return Color.WHITE
