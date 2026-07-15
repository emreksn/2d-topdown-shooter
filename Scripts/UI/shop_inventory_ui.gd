class_name ShopInventoryUI
extends CanvasLayer

@export var wave_director: WaveDirector
@export var shop_director: ShopDirector
@export var inventory: PlayerInventoryComponent
@export var weapon_loadout: WeaponLoadoutComponent
@export var progression: PlayerProgressionComponent

var _root_panel: PanelContainer
var _status_label: Label
var _title_label: Label
var _gold_label: Label
var _offer_column: VBoxContainer
var _inventory_column: VBoxContainer
var _offer_list: HBoxContainer
var _inventory_list: VBoxContainer
var _toggle_button: Button
var _footer: HBoxContainer
var _reroll_button: Button
var _next_button: Button
var _paused_for_inventory := false
var _desired_panel_size := Vector2(900.0, 520.0)

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	GameSettings.settings_changed.connect(_resize_panel)
	_root_panel.visible = false

	if is_instance_valid(wave_director):
		wave_director.shop_started.connect(_on_shop_started)
		wave_director.shop_ended.connect(_on_shop_ended)
		wave_director.wave_started.connect(_on_wave_started)
	if is_instance_valid(shop_director):
		shop_director.offers_changed.connect(_refresh)
		shop_director.purchase_failed.connect(_show_status)
		shop_director.item_purchased.connect(_on_item_purchased)
		shop_director.weapon_purchased.connect(_on_weapon_purchased)
		shop_director.reroll_completed.connect(_on_reroll_completed)
	if is_instance_valid(inventory):
		inventory.inventory_changed.connect(_refresh)
		inventory.item_sold.connect(_on_item_sold)
		inventory.relic_equipped.connect(_on_relic_equipped)
	if is_instance_valid(weapon_loadout):
		weapon_loadout.loadout_changed.connect(_refresh)
		weapon_loadout.weapon_sold.connect(_on_weapon_sold)
	if is_instance_valid(progression):
		progression.gold_changed.connect(_on_gold_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory_panel()

func _resolve_dependencies() -> void:
	if not is_instance_valid(wave_director):
		wave_director = get_tree().get_first_node_in_group(&"wave_director") as WaveDirector
	if not is_instance_valid(shop_director):
		shop_director = get_tree().get_first_node_in_group(&"shop_director") as ShopDirector
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player != null:
		if not is_instance_valid(inventory):
			inventory = player.get_node_or_null(
				"PlayerInventoryComponent"
			) as PlayerInventoryComponent
		if not is_instance_valid(weapon_loadout):
			weapon_loadout = player.get_node_or_null(
				"WeaponLoadoutComponent"
			) as WeaponLoadoutComponent
		if not is_instance_valid(progression):
			progression = player.get_node_or_null(
				"PlayerProgressionComponent"
			) as PlayerProgressionComponent

func _build_ui() -> void:
	_toggle_button = Button.new()
	_toggle_button.text = "Inventory"
	_toggle_button.position = Vector2(24.0, 124.0)
	_toggle_button.size = Vector2(128.0, 34.0)
	_toggle_button.pressed.connect(_toggle_inventory_panel)
	UiPresentation.apply_action_button_style(_toggle_button, Color(0.74, 0.86, 1.0, 1.0))
	add_child(_toggle_button)

	_root_panel = PanelContainer.new()
	UiPresentation.apply_panel_style(_root_panel)
	add_child(_root_panel)
	_resize_panel()

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin)
	_root_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	_title_label = Label.new()
	_title_label.text = "SHOP"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiPresentation.apply_heading(_title_label, 26)
	header.add_child(_title_label)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.custom_minimum_size = Vector2(150.0, 0.0)
	UiPresentation.apply_heading(_gold_label, 20)
	_gold_label.add_theme_color_override("font_color", UiPresentation.GOLD)
	header.add_child(_gold_label)

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	layout.add_child(columns)

	_offer_column = _make_column(columns, "Offers", 560.0, true)

	_offer_list = HBoxContainer.new()
	_offer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_list.add_theme_constant_override("separation", 10)
	_offer_column.add_child(_offer_list)

	_inventory_column = _make_column(columns, "Inventory", 230.0, false)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_inventory_column.add_child(inventory_scroll)

	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 4)
	_inventory_list.set_meta("clear_start", 0)
	inventory_scroll.add_child(_inventory_list)

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	layout.add_child(_footer)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiPresentation.apply_body_label(_status_label, true, 13)
	_footer.add_child(_status_label)

	_reroll_button = Button.new()
	_reroll_button.text = "Reroll"
	UiPresentation.apply_action_button_style(_reroll_button, Color(0.52, 0.72, 1.0, 1.0))
	_reroll_button.pressed.connect(func() -> void:
		if is_instance_valid(shop_director):
			shop_director.reroll_offers()
	)
	_footer.add_child(_reroll_button)

	_next_button = Button.new()
	_next_button.text = "Start Next Wave"
	UiPresentation.apply_action_button_style(_next_button, Color(0.34, 0.95, 0.52, 1.0))
	_next_button.pressed.connect(func() -> void:
		if is_instance_valid(shop_director):
			shop_director.leave_shop()
	)
	_footer.add_child(_next_button)

func _make_column(
	parent: Control,
	title_text: String,
	min_width: float,
	expand: bool
) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(min_width, 0.0)
	box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
		if expand
		else Control.SIZE_SHRINK_END
	)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)

	var label := Label.new()
	label.text = title_text
	UiPresentation.apply_heading(label, 17)
	box.add_child(label)
	return box

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, _desired_panel_size)

func _on_shop_started(_completed_wave_number: int, next_wave_number: int) -> void:
	_unpause_inventory_if_needed()
	_root_panel.visible = true
	_show_status("Prepare for wave %d." % next_wave_number)
	_refresh()

func _on_shop_ended(_next_wave_number: int) -> void:
	_root_panel.visible = false
	_unpause_inventory_if_needed()

func _on_wave_started(_wave_number: int, _definition: WaveDefinition) -> void:
	_root_panel.visible = false
	_unpause_inventory_if_needed()

func _on_gold_changed(_total_gold: int) -> void:
	if is_node_ready():
		_refresh()

func _on_item_purchased(item: ItemDefinition, _remaining_gold: int) -> void:
	_show_status("Bought %s." % item.display_name)
	_refresh()

func _on_weapon_purchased(offer: WeaponOffer, _remaining_gold: int) -> void:
	_show_status("Equipped %s." % offer.get_inventory_label())
	_refresh()

func _on_item_sold(item: ItemDefinition, value: int) -> void:
	_show_status("Sold %s for %d gold." % [item.display_name, value])
	_refresh()

func _on_weapon_sold(_slot_index: int, offer: WeaponOffer, value: int) -> void:
	_show_status("Sold %s for %d gold." % [offer.get_inventory_label(), value])
	_refresh()

func _on_reroll_completed(cost: int, was_free: bool) -> void:
	if was_free:
		_show_status("Free reroll.")
	else:
		_show_status("Rerolled for %d gold." % cost)
	_refresh()

func _on_relic_equipped(item: ItemDefinition, replaced_item: ItemDefinition) -> void:
	if replaced_item != null:
		_show_status(
			"Equipped %s. Replaced %s."
			% [item.display_name, replaced_item.display_name]
		)
	else:
		_show_status("Equipped %s." % item.display_name)
	_refresh()

func _show_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message

func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_mode()
	_clear_column(_offer_list)
	_clear_column(_inventory_list)
	_refresh_offers()
	_refresh_inventory()

func _refresh_mode() -> void:
	var shop_active := _is_shop_phase_active()
	_offer_column.visible = shop_active
	_footer.visible = shop_active
	if is_instance_valid(_inventory_column):
		_inventory_column.size_flags_horizontal = (
			Control.SIZE_SHRINK_END
			if shop_active
			else Control.SIZE_EXPAND_FILL
		)
	_title_label.text = "SHOP" if shop_active else "INVENTORY"
	if is_instance_valid(_gold_label):
		_gold_label.text = "GOLD  %d" % (progression.gold if is_instance_valid(progression) else 0)
	if is_instance_valid(_reroll_button) and is_instance_valid(shop_director):
		_reroll_button.disabled = not shop_active
		_reroll_button.text = "Reroll %dg" % shop_director.get_current_reroll_cost()

func _refresh_offers() -> void:
	if not _is_shop_phase_active():
		return
	if not is_instance_valid(shop_director):
		_add_note(_offer_list, "No shop.")
		return
	for index: int in range(shop_director.current_offers.size()):
		_offer_list.add_child(_make_offer_slot(index, shop_director.current_offers[index]))

func _make_offer_slot(index: int, offer) -> Control:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(172.0, 154.0)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 6)

	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(172.0, 118.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_child(button)

	var item := offer as ItemDefinition
	var weapon_offer := offer as WeaponOffer
	if item == null and weapon_offer == null:
		button.text = "Sold"
		button.disabled = true
		UiPresentation.apply_empty_button_style(button)
	elif weapon_offer != null:
		var blocked_by_weapon_slots := shop_director.is_offer_blocked_by_weapon_slots(index)
		var unaffordable := not _can_afford_offer(index)
		button.text = weapon_offer.get_offer_text(_get_current_wave_number())
		if blocked_by_weapon_slots:
			button.text += "\nWeapon slots full"
			button.disabled = true
		elif unaffordable:
			button.text += "\nNeed %dg more" % _get_missing_gold(index)
			button.disabled = true
		UiPresentation.apply_rarity_button_style(button, weapon_offer.rarity)
		if not blocked_by_weapon_slots and not unaffordable:
			button.pressed.connect(_on_offer_pressed.bind(index))
	else:
		var price := shop_director.current_prices[index]
		var blocked_by_relic_slot := shop_director.is_offer_blocked_by_relic_slot(index)
		var unaffordable := not _can_afford_offer(index)
		button.text = "%s - %dg\n%s" % [
			item.get_inventory_label(),
			price,
			item.get_stat_display_text()
		]
		if blocked_by_relic_slot:
			button.text += "\nSlot occupied"
			button.disabled = true
		elif unaffordable:
			button.text += "\nNeed %dg more" % _get_missing_gold(index)
			button.disabled = true
		UiPresentation.apply_rarity_button_style(button, item.rarity)
		if not blocked_by_relic_slot and not unaffordable:
			button.pressed.connect(_on_offer_pressed.bind(index))

	var lock_button := Button.new()
	var is_locked := (
		index < shop_director.current_locks.size()
		and shop_director.current_locks[index]
	)
	lock_button.text = "Pinned" if is_locked else "Pin"
	lock_button.disabled = item == null and weapon_offer == null
	UiPresentation.apply_action_button_style(lock_button, Color(0.74, 0.78, 0.84, 1.0))
	lock_button.pressed.connect(_on_lock_offer_pressed.bind(index))
	slot.add_child(lock_button)
	return slot

func _refresh_inventory() -> void:
	if not is_instance_valid(inventory):
		_add_note(_inventory_list, "No inventory.")
		return
	_add_weapon_slots()
	_add_relic_slots()
	var counts := inventory.get_item_counts()
	if counts.is_empty():
		_add_note(_inventory_list, "Inventory empty.")
		return
	for item_key in counts:
		var item := item_key as ItemDefinition
		_inventory_list.add_child(
			_make_inventory_entry(
				item,
				int(counts[item_key]),
				false
			)
		)

func _add_weapon_slots() -> void:
	var header := Label.new()
	header.text = "Weapons"
	UiPresentation.apply_heading(header, 15)
	_inventory_list.add_child(header)

	if not is_instance_valid(weapon_loadout):
		_add_note(_inventory_list, "No weapon loadout.")
		return
	for slot_index in range(WeaponLoadoutComponent.SLOT_COUNT):
		var offer := weapon_loadout.get_offer(slot_index)
		if offer == null:
			_add_note(_inventory_list, "Slot %d: empty" % (slot_index + 1))
		else:
			_inventory_list.add_child(_make_weapon_entry(slot_index, offer))

func _add_relic_slots() -> void:
	var header := Label.new()
	header.text = "Relics"
	UiPresentation.apply_heading(header, 15)
	_inventory_list.add_child(header)

	var slots: Array[ItemDefinition.RelicSlot] = [
		ItemDefinition.RelicSlot.COMBAT,
		ItemDefinition.RelicSlot.WEAPON,
		ItemDefinition.RelicSlot.ECONOMY,
		ItemDefinition.RelicSlot.SURVIVAL,
		ItemDefinition.RelicSlot.WAVE
	]
	for slot: ItemDefinition.RelicSlot in slots:
		var item := inventory.get_active_relic(slot)
		if item == null:
			_add_note(
				_inventory_list,
				"%s: empty" % ItemDefinition.get_relic_slot_name(slot)
			)
		else:
			_inventory_list.add_child(_make_inventory_entry(item, 1, true))

	var inventory_header := Label.new()
	inventory_header.text = "Items"
	UiPresentation.apply_heading(inventory_header, 15)
	_inventory_list.add_child(inventory_header)

func _make_inventory_entry(
	item: ItemDefinition,
	count: int,
	is_active_relic: bool
) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = _get_inventory_display_text(item, count, is_active_relic)
	label.add_theme_color_override("font_color", UiPresentation.get_rarity_color(item.rarity))
	box.add_child(label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)

	if (
		not is_active_relic
		and item.category == ItemDefinition.ItemCategory.RELIC
	):
		var equip_button := Button.new()
		equip_button.text = "Equip"
		UiPresentation.apply_action_button_style(equip_button, Color(0.34, 0.95, 0.52, 1.0))
		equip_button.pressed.connect(_on_equip_inventory_relic.bind(item))
		actions.add_child(equip_button)

	if item.sellable:
		var sell_button := Button.new()
		sell_button.text = "Sell %dg" % item.get_sell_value(
			_get_current_wave_number()
		)
		UiPresentation.apply_action_button_style(sell_button, UiPresentation.GOLD)
		sell_button.pressed.connect(_on_sell_item.bind(item, is_active_relic))
		actions.add_child(sell_button)

	return box

func _get_inventory_display_text(
	item: ItemDefinition,
	count: int,
	is_active_relic: bool
) -> String:
	if item.category == ItemDefinition.ItemCategory.RELIC:
		var slot_name := item.get_relic_slot_display_name()
		if is_active_relic:
			return "%s: %s" % [slot_name, item.display_name]
		var suffix := " x%d" % count if count > 1 else ""
		return "%s Relic: %s%s" % [slot_name, item.display_name, suffix]
	return item.get_inventory_label(count)

func _make_weapon_entry(slot_index: int, offer: WeaponOffer) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "Slot %d: %s\n%s" % [
		slot_index + 1,
		offer.get_inventory_label(),
		offer.get_stat_display_text()
	]
	label.add_theme_color_override("font_color", UiPresentation.get_rarity_color(offer.rarity))
	box.add_child(label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)

	var sell_button := Button.new()
	sell_button.text = "Sell %dg" % offer.get_sell_value(_get_current_wave_number())
	UiPresentation.apply_action_button_style(sell_button, UiPresentation.GOLD)
	sell_button.pressed.connect(_on_sell_weapon.bind(slot_index))
	actions.add_child(sell_button)

	return box

func _clear_column(column: Control) -> void:
	if not is_instance_valid(column):
		return
	var default_start := 1 if column is VBoxContainer else 0
	var start_index := int(column.get_meta("clear_start", default_start))
	while column.get_child_count() > start_index:
		var child := column.get_child(start_index)
		column.remove_child(child)
		child.queue_free()

func _on_offer_pressed(index: int) -> void:
	if is_instance_valid(shop_director):
		shop_director.buy_offer(index)

func _on_lock_offer_pressed(index: int) -> void:
	if is_instance_valid(shop_director):
		shop_director.toggle_offer_lock(index)

func _on_equip_inventory_relic(item: ItemDefinition) -> void:
	if is_instance_valid(inventory):
		inventory.equip_relic_from_inventory(item)

func _on_sell_item(item: ItemDefinition, prefer_active_relic: bool) -> void:
	if is_instance_valid(inventory) and is_instance_valid(progression):
		inventory.sell_item(
			item,
			progression,
			_get_current_wave_number(),
			prefer_active_relic
		)

func _on_sell_weapon(slot_index: int) -> void:
	if is_instance_valid(weapon_loadout) and is_instance_valid(progression):
		weapon_loadout.sell_weapon(
			slot_index,
			progression,
			_get_current_wave_number()
		)

func _get_current_wave_number() -> int:
	if is_instance_valid(wave_director):
		return maxi(wave_director.current_wave_number, 1)
	return 1

func _can_afford_offer(index: int) -> bool:
	if not is_instance_valid(progression) or not is_instance_valid(shop_director):
		return true
	if index < 0 or index >= shop_director.current_prices.size():
		return true
	return progression.gold >= shop_director.current_prices[index]

func _get_missing_gold(index: int) -> int:
	if not is_instance_valid(progression) or not is_instance_valid(shop_director):
		return 0
	if index < 0 or index >= shop_director.current_prices.size():
		return 0
	return maxi(shop_director.current_prices[index] - progression.gold, 0)

func _add_note(column: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiPresentation.apply_body_label(label, true, 13)
	column.add_child(label)

func _toggle_inventory_panel() -> void:
	if _root_panel.visible:
		_root_panel.visible = false
		_unpause_inventory_if_needed()
	else:
		_root_panel.visible = true
		if not _is_shop_phase_active():
			_pause_for_inventory()
		_refresh()

func _pause_for_inventory() -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	_paused_for_inventory = true
	tree.paused = true

func _unpause_inventory_if_needed() -> void:
	if not _paused_for_inventory:
		return
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_paused_for_inventory = false

func _is_shop_phase_active() -> bool:
	return (
		is_instance_valid(wave_director)
		and wave_director.state == WaveDirector.State.SHOP
	)

func _apply_empty_offer_style(button: Button) -> void:
	UiPresentation.apply_empty_button_style(button)

func _apply_rarity_style(button: Button, rarity: ItemDefinition.Rarity) -> void:
	UiPresentation.apply_rarity_button_style(button, rarity)

func _get_rarity_color(rarity: ItemDefinition.Rarity) -> Color:
	return UiPresentation.get_rarity_color(rarity)
