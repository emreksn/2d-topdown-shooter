class_name ItemEvaluationDirector
extends Node

signal evaluation_started(total_count: int)
signal current_item_changed(drop, item_index: int, total_count: int)
signal evaluation_completed
signal item_kept(item: ItemDefinition)
signal item_sold(item: ItemDefinition, value: int)
signal weapon_kept(offer: WeaponOffer)
signal weapon_sold(offer: WeaponOffer, value: int)
signal active_skill_kept(skill: ActiveSkillDefinition)
signal active_skill_sold(skill: ActiveSkillDefinition, value: int)

@export var inventory: PlayerInventoryComponent
@export var progression: PlayerProgressionComponent
@export var weapon_loadout: WeaponLoadoutComponent
@export var active_skill_loadout: ActiveSkillLoadoutComponent

var pending_items: Array = []
var current_wave_number: int = 1

var _current_item
var _is_evaluating := false
var _evaluated_count: int = 0

func _ready() -> void:
	add_to_group(&"item_evaluation_director")
	_resolve_dependencies()

func queue_item(item: ItemDefinition) -> void:
	if item != null:
		pending_items.append(item)

func queue_weapon_offer(offer: WeaponOffer) -> void:
	if offer != null:
		pending_items.append(offer)

func queue_active_skill(skill: ActiveSkillDefinition) -> void:
	if skill != null:
		pending_items.append(skill)

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
	var weapon_offer := _current_item as WeaponOffer
	if weapon_offer != null:
		if is_instance_valid(weapon_loadout) and weapon_loadout.equip_offer(weapon_offer):
			weapon_kept.emit(weapon_offer)
			_show_next_item()
			return true
		return false
	var active_skill := _current_item as ActiveSkillDefinition
	if active_skill != null:
		var slot := _get_skill_equip_slot()
		if slot >= 0 and is_instance_valid(active_skill_loadout):
			active_skill_loadout.equip_skill(slot, active_skill)
			active_skill_kept.emit(active_skill)
			_show_next_item()
			return true
		return false
	var item := _current_item as ItemDefinition
	if item == null:
		return false
	if is_instance_valid(inventory):
		inventory.add_item(item)
	item_kept.emit(item)
	_show_next_item()
	return true

func sell_current() -> bool:
	if not _is_evaluating or _current_item == null:
		return false
	var value := _get_current_sell_value()
	if is_instance_valid(progression) and _is_current_sellable():
		progression.add_gold(value)
	else:
		value = 0
	var weapon_offer := _current_item as WeaponOffer
	var active_skill := _current_item as ActiveSkillDefinition
	var item := _current_item as ItemDefinition
	if weapon_offer != null:
		weapon_sold.emit(weapon_offer, value)
	elif active_skill != null:
		active_skill_sold.emit(active_skill, value)
	elif item != null:
		item_sold.emit(item, value)
	_show_next_item()
	return true

func _show_next_item() -> void:
	if pending_items.is_empty():
		_complete_evaluation()
		return
	_current_item = pending_items.pop_front()
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
	if not is_instance_valid(weapon_loadout):
		weapon_loadout = player.get_node_or_null(
			"WeaponLoadoutComponent"
		) as WeaponLoadoutComponent
	if not is_instance_valid(active_skill_loadout):
		active_skill_loadout = player.get_node_or_null(
			"ActiveSkillLoadoutComponent"
		) as ActiveSkillLoadoutComponent

func _get_current_sell_value() -> int:
	var weapon_offer := _current_item as WeaponOffer
	if weapon_offer != null:
		return weapon_offer.get_sell_value(current_wave_number)
	var active_skill := _current_item as ActiveSkillDefinition
	if active_skill != null:
		return active_skill.get_sell_value(current_wave_number)
	var item := _current_item as ItemDefinition
	if item != null:
		return item.get_sell_value(current_wave_number)
	return 0

func _is_current_sellable() -> bool:
	var item := _current_item as ItemDefinition
	return item == null or item.sellable

func _get_skill_equip_slot() -> int:
	if not is_instance_valid(active_skill_loadout):
		return -1
	for index: int in range(ActiveSkillLoadoutComponent.SLOT_COUNT):
		if active_skill_loadout.get_skill(index) == null:
			return index
	return 0
