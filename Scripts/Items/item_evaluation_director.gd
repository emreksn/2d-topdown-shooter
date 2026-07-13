class_name ItemEvaluationDirector
extends Node

signal evaluation_started(total_count: int)
signal current_item_changed(item: ItemDefinition, item_index: int, total_count: int)
signal evaluation_completed
signal item_kept(item: ItemDefinition)
signal item_sold(item: ItemDefinition, value: int)

@export var inventory: PlayerInventoryComponent
@export var progression: PlayerProgressionComponent

var pending_items: Array[ItemDefinition] = []
var current_wave_number: int = 1

var _current_item: ItemDefinition
var _is_evaluating := false
var _evaluated_count: int = 0

func _ready() -> void:
	add_to_group(&"item_evaluation_director")
	_resolve_dependencies()

func queue_item(item: ItemDefinition) -> void:
	if item != null:
		pending_items.append(item)

func has_pending_items() -> bool:
	return not pending_items.is_empty()

func begin_evaluation(wave_number: int) -> bool:
	if pending_items.is_empty():
		return false
	_resolve_dependencies()
	current_wave_number = maxi(wave_number, 1)
	_is_evaluating = true
	_evaluated_count = 0
	evaluation_started.emit(pending_items.size())
	_show_next_item()
	return true

func keep_current() -> bool:
	if not _is_evaluating or _current_item == null:
		return false
	if is_instance_valid(inventory):
		inventory.add_item(_current_item)
	item_kept.emit(_current_item)
	_show_next_item()
	return true

func sell_current() -> bool:
	if not _is_evaluating or _current_item == null:
		return false
	var value := _current_item.get_sell_value(current_wave_number)
	if is_instance_valid(progression) and _current_item.sellable:
		progression.add_gold(value)
	else:
		value = 0
	item_sold.emit(_current_item, value)
	_show_next_item()
	return true

func _show_next_item() -> void:
	if pending_items.is_empty():
		_complete_evaluation()
		return
	_current_item = pending_items.pop_front() as ItemDefinition
	_evaluated_count += 1
	current_item_changed.emit(
		_current_item,
		_evaluated_count,
		_evaluated_count + pending_items.size()
	)

func _complete_evaluation() -> void:
	_is_evaluating = false
	_current_item = null
	evaluation_completed.emit()

func _resolve_dependencies() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player == null:
		return
	if not is_instance_valid(inventory):
		inventory = player.get_node_or_null(
			"PlayerInventoryComponent"
		) as PlayerInventoryComponent
	if not is_instance_valid(progression):
		progression = player.get_node_or_null(
			"PlayerProgressionComponent"
		) as PlayerProgressionComponent
