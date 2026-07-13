class_name PlayerInventoryComponent
extends Node

signal inventory_changed
signal item_added(item: ItemDefinition)
signal item_sold(item: ItemDefinition, value: int)
signal relic_equipped(item: ItemDefinition, replaced_item: ItemDefinition)

@export var stat_component: StatComponent

const RELIC_SLOTS: Array[ItemDefinition.RelicSlot] = [
	ItemDefinition.RelicSlot.COMBAT,
	ItemDefinition.RelicSlot.WEAPON,
	ItemDefinition.RelicSlot.ECONOMY,
	ItemDefinition.RelicSlot.SURVIVAL,
	ItemDefinition.RelicSlot.WAVE
]

var items: Array[ItemDefinition] = []
var active_relics: Dictionary = {}

func _ready() -> void:
	if not is_instance_valid(stat_component):
		stat_component = get_parent().get_node_or_null("StatComponent") as StatComponent
	_apply_all_modifiers()

func add_item(item: ItemDefinition) -> bool:
	if item == null:
		return false
	if item.category == ItemDefinition.ItemCategory.RELIC:
		return equip_relic(item)
	items.append(item)
	_apply_item_modifier(items.size() - 1, item)
	item_added.emit(item)
	inventory_changed.emit()
	return true

func equip_relic(item: ItemDefinition) -> bool:
	if (
		item == null
		or item.category != ItemDefinition.ItemCategory.RELIC
		or item.relic_slot == ItemDefinition.RelicSlot.NONE
	):
		return false

	var slot: ItemDefinition.RelicSlot = item.relic_slot
	var previous := active_relics.get(slot) as ItemDefinition
	if previous == item:
		items.append(item)
		item_added.emit(item)
		inventory_changed.emit()
		return true
	if previous != null:
		items.append(previous)
	active_relics[slot] = item
	_apply_all_modifiers()
	item_added.emit(item)
	relic_equipped.emit(item, previous)
	inventory_changed.emit()
	return true

func equip_relic_from_inventory(item: ItemDefinition) -> bool:
	var index := items.find(item)
	if index < 0:
		return false
	items.remove_at(index)
	return equip_relic(item)

func sell_item(
	item: ItemDefinition,
	progression: PlayerProgressionComponent,
	wave_number: int = 1,
	prefer_active_relic: bool = false
) -> bool:
	if item == null or not item.sellable or not is_instance_valid(progression):
		return false

	var removed := false
	if prefer_active_relic and item.category == ItemDefinition.ItemCategory.RELIC:
		removed = _remove_active_relic(item)
	if not removed:
		removed = _remove_inventory_item(item)
	if not removed and item.category == ItemDefinition.ItemCategory.RELIC:
		removed = _remove_active_relic(item)
	if not removed:
		return false

	var value := item.get_sell_value(wave_number)
	progression.add_gold(value)
	_apply_all_modifiers()
	item_sold.emit(item, value)
	inventory_changed.emit()
	return true

func get_item_counts() -> Dictionary:
	var counts := {}
	for item in items:
		if item == null:
			continue
		counts[item] = int(counts.get(item, 0)) + 1
	return counts

func get_active_relic(slot: ItemDefinition.RelicSlot) -> ItemDefinition:
	return active_relics.get(slot) as ItemDefinition

func refresh_modifiers() -> void:
	_apply_all_modifiers()

func _apply_all_modifiers() -> void:
	for index: int in range(0, 128):
		_remove_modifier_source(_source_id(index))
	for slot: ItemDefinition.RelicSlot in RELIC_SLOTS:
		_remove_modifier_source(_relic_source_id(slot))
	for index: int in range(items.size()):
		_apply_item_modifier(index, items[index])
	for slot_key in active_relics:
		var slot: int = int(slot_key)
		_apply_relic_modifier(slot, active_relics[slot_key])

func _apply_item_modifier(index: int, item: ItemDefinition) -> void:
	if (
		not is_instance_valid(stat_component)
		or item == null
		or item.category == ItemDefinition.ItemCategory.RELIC
		or item.modifier_set == null
	):
		return
	_add_modifier_source(_source_id(index), item.modifier_set)

func _apply_relic_modifier(slot: int, item: ItemDefinition) -> void:
	if (
		not is_instance_valid(stat_component)
		or item == null
		or item.modifier_set == null
	):
		return
	_add_modifier_source(_relic_source_id(slot), item.modifier_set)

func _add_modifier_source(source_id: StringName, modifier_set: ModifierSet) -> void:
	if is_instance_valid(stat_component):
		stat_component.add_modifier_source(source_id, modifier_set)
	for weapon_stats in _get_weapon_stat_components():
		weapon_stats.add_modifier_source(source_id, modifier_set)

func _remove_modifier_source(source_id: StringName) -> void:
	if is_instance_valid(stat_component):
		stat_component.remove_modifier_source(source_id)
	for weapon_stats in _get_weapon_stat_components():
		weapon_stats.remove_modifier_source(source_id)

func _get_weapon_stat_components() -> Array[StatComponent]:
	var result: Array[StatComponent] = []
	var _owner := get_parent()
	if _owner == null:
		return result
	var weapon_mount := _owner.get_node_or_null("WeaponMount")
	if weapon_mount == null:
		return result
	for weapon in weapon_mount.get_children():
		for child in weapon.get_children():
			if child is StatComponent:
				result.append(child)
	return result

func _remove_inventory_item(item: ItemDefinition) -> bool:
	var index := items.find(item)
	if index < 0:
		return false
	items.remove_at(index)
	return true

func _remove_active_relic(item: ItemDefinition) -> bool:
	for slot_key in active_relics.keys():
		if active_relics[slot_key] == item:
			active_relics.erase(slot_key)
			return true
	return false

func _source_id(index: int) -> StringName:
	return StringName("inventory:item:%d" % index)

func _relic_source_id(slot: int) -> StringName:
	return StringName("relic:%d" % slot)
