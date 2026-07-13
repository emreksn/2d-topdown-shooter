class_name WeaponLoadoutComponent
extends Node

signal loadout_changed
signal weapon_equipped(slot_index: int, offer: WeaponOffer)
signal weapon_sold(slot_index: int, offer: WeaponOffer, value: int)

@export var weapon_mount: Node2D

const SLOT_COUNT := 2
const SLOT_POSITIONS: Array[Vector2] = [
	Vector2(42.0, 0.0),
	Vector2(-42.0, 0.0)
]
const WEAPON_SOURCE_ID := &"weapon:generated"

var equipped_offers: Array[WeaponOffer] = []
var equipped_nodes: Array[Weapon] = []

func _ready() -> void:
	if not is_instance_valid(weapon_mount):
		weapon_mount = get_parent().get_node_or_null("WeaponMount") as Node2D
	_ensure_slots()

func equip_offer(offer: WeaponOffer) -> bool:
	var slot_index := get_first_empty_slot()
	if slot_index < 0:
		return false
	return equip_offer_in_slot(slot_index, offer)

func equip_offer_in_slot(slot_index: int, offer: WeaponOffer) -> bool:
	_ensure_slots()
	_resolve_weapon_mount()
	if (
		slot_index < 0
		or slot_index >= SLOT_COUNT
		or offer == null
		or equipped_offers[slot_index] != null
		or not is_instance_valid(weapon_mount)
	):
		return false

	var weapon := offer.instantiate_weapon()
	if weapon == null:
		return false
	weapon.weapon_definition = offer.definition
	weapon.position = SLOT_POSITIONS[slot_index]
	weapon_mount.add_child(weapon)
	weapon.resolve_stat_components()
	equipped_offers[slot_index] = offer
	equipped_nodes[slot_index] = weapon
	_apply_offer_modifiers(weapon, offer)
	_refresh_inventory_modifiers()
	weapon_equipped.emit(slot_index, offer)
	loadout_changed.emit()
	return true

func sell_weapon(
	slot_index: int,
	progression: PlayerProgressionComponent,
	wave_number: int = 1
) -> bool:
	_ensure_slots()
	if (
		slot_index < 0
		or slot_index >= SLOT_COUNT
		or equipped_offers[slot_index] == null
		or not is_instance_valid(progression)
	):
		return false

	var offer := equipped_offers[slot_index]
	var value := offer.get_sell_value(wave_number)
	var weapon := equipped_nodes[slot_index]
	if is_instance_valid(weapon):
		weapon.queue_free()
	equipped_offers[slot_index] = null
	equipped_nodes[slot_index] = null
	progression.add_gold(value)
	_refresh_inventory_modifiers()
	weapon_sold.emit(slot_index, offer, value)
	loadout_changed.emit()
	return true

func has_empty_slot() -> bool:
	return get_first_empty_slot() >= 0

func is_full() -> bool:
	return not has_empty_slot()

func get_first_empty_slot() -> int:
	_ensure_slots()
	for index in range(SLOT_COUNT):
		if equipped_offers[index] == null:
			return index
	return -1

func get_offer(slot_index: int) -> WeaponOffer:
	_ensure_slots()
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return equipped_offers[slot_index]

func get_weapon(slot_index: int) -> Weapon:
	_ensure_slots()
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return equipped_nodes[slot_index]

func get_equipped_count() -> int:
	_ensure_slots()
	var count := 0
	for offer in equipped_offers:
		if offer != null:
			count += 1
	return count

func _apply_offer_modifiers(weapon: Weapon, offer: WeaponOffer) -> void:
	if (
		not is_instance_valid(weapon)
		or not is_instance_valid(weapon.stat_component)
		or offer == null
		or offer.modifier_set == null
	):
		return
	weapon.stat_component.add_modifier_source(
		WEAPON_SOURCE_ID,
		offer.modifier_set
	)

func _refresh_inventory_modifiers() -> void:
	var inventory := get_parent().get_node_or_null(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	if is_instance_valid(inventory):
		inventory.refresh_modifiers()

func _ensure_slots() -> void:
	while equipped_offers.size() < SLOT_COUNT:
		equipped_offers.append(null)
	while equipped_nodes.size() < SLOT_COUNT:
		equipped_nodes.append(null)

func _resolve_weapon_mount() -> void:
	if is_instance_valid(weapon_mount):
		return
	var parent := get_parent()
	if parent != null:
		weapon_mount = parent.get_node_or_null("WeaponMount") as Node2D
