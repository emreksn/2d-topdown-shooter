class_name ItemEvaluationUI
extends CanvasLayer

@export var evaluation_director: ItemEvaluationDirector

var _root_panel: PanelContainer
var _title_label: Label
var _name_label: Label
var _details_label: Label
var _meta_label: Label
var _keep_button: Button
var _sell_button: Button
var _desired_panel_size := Vector2(700.0, 430.0)

func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	GameSettings.settings_changed.connect(_resize_panel)
	_root_panel.visible = false
	if is_instance_valid(evaluation_director):
		evaluation_director.evaluation_started.connect(_on_evaluation_started)
		evaluation_director.evaluation_completed.connect(_on_evaluation_completed)
		evaluation_director.current_item_changed.connect(_on_current_item_changed)

func _resolve_dependencies() -> void:
	if not is_instance_valid(evaluation_director):
		evaluation_director = get_tree().get_first_node_in_group(
			&"item_evaluation_director"
		) as ItemEvaluationDirector

func _build_ui() -> void:
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

	_title_label = Label.new()
	_title_label.text = "ITEM EVALUATION"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_heading(_title_label, 25)
	layout.add_child(_title_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiPresentation.apply_heading(_name_label, 21)
	layout.add_child(_name_label)

	_meta_label = Label.new()
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_body_label(_meta_label, true, 13)
	layout.add_child(_meta_label)

	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(details_scroll)

	_details_label = Label.new()
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiPresentation.apply_body_label(_details_label, false, 14)
	details_scroll.add_child(_details_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	_keep_button = Button.new()
	_keep_button.text = "Keep"
	_keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_button.pressed.connect(_on_keep_pressed)
	UiPresentation.apply_action_button_style(_keep_button, Color(0.34, 0.95, 0.52, 1.0))
	buttons.add_child(_keep_button)

	_sell_button = Button.new()
	_sell_button.text = "Sell"
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_button.pressed.connect(_on_sell_pressed)
	UiPresentation.apply_action_button_style(_sell_button, UiPresentation.GOLD)
	buttons.add_child(_sell_button)

func _on_evaluation_started(_total_count: int) -> void:
	_root_panel.visible = true

func _on_evaluation_completed() -> void:
	_root_panel.visible = false

func _on_current_item_changed(
	drop,
	item_index: int,
	total_count: int
) -> void:
	_root_panel.visible = true
	_title_label.text = "ITEM EVALUATION  (%d / %d)" % [
		item_index,
		total_count
	]
	if drop == null:
		_name_label.text = "Unknown Drop"
		_meta_label.text = ""
		_details_label.text = ""
		return
	_refresh_drop(drop)

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, _desired_panel_size)

func _on_keep_pressed() -> void:
	if is_instance_valid(evaluation_director):
		evaluation_director.keep_current()

func _on_sell_pressed() -> void:
	if is_instance_valid(evaluation_director):
		evaluation_director.sell_current()

func _refresh_drop(drop) -> void:
	var wave_number := (
		evaluation_director.current_wave_number
		if is_instance_valid(evaluation_director)
		else 1
	)
	var item := drop as ItemDefinition
	var weapon_offer := drop as WeaponOffer
	var active_skill := drop as ActiveSkillDefinition
	_sell_button.disabled = false
	if weapon_offer != null:
		_name_label.text = weapon_offer.get_display_name()
		_name_label.add_theme_color_override("font_color", _get_rarity_color(weapon_offer.rarity))
		_meta_label.text = "Weapon offer"
		_details_label.text = weapon_offer.get_stat_display_text()
		_keep_button.text = "Equip"
		_keep_button.disabled = (
			not is_instance_valid(evaluation_director.weapon_loadout)
			or evaluation_director.weapon_loadout.is_full()
		)
		_sell_button.text = "Sell %dg" % weapon_offer.get_sell_value(wave_number)
		return
	if active_skill != null:
		_name_label.text = active_skill.display_name
		_name_label.add_theme_color_override("font_color", Color(0.25, 0.85, 1.0, 1.0))
		_meta_label.text = "Active skill"
		_details_label.text = "Cooldown %.1fs" % active_skill.cooldown_duration
		_keep_button.text = "Equip"
		_keep_button.disabled = false
		_sell_button.text = "Sell %dg" % active_skill.get_sell_value(wave_number)
		return
	if item == null:
		return
	_name_label.text = "%s %s" % [
		item.get_rarity_display_name(),
		item.display_name
	]
	_name_label.add_theme_color_override("font_color", _get_rarity_color(item.rarity))
	_meta_label.text = (
		"%s relic" % item.get_relic_slot_display_name()
		if item.category == ItemDefinition.ItemCategory.RELIC
		else "Inventory item"
	)
	_details_label.text = item.get_stat_display_text()
	_keep_button.text = (
		_get_relic_keep_text(item)
		if item.category == ItemDefinition.ItemCategory.RELIC
		else "Keep"
	)
	_keep_button.disabled = false
	_sell_button.disabled = not item.sellable
	_sell_button.text = "Sell %dg" % item.get_sell_value(wave_number) if item.sellable else "Cannot Sell"

func _get_relic_keep_text(item: ItemDefinition) -> String:
	if not is_instance_valid(evaluation_director.inventory):
		return "Equip"
	var current := evaluation_director.inventory.get_active_relic(item.relic_slot)
	return "Replace" if current != null else "Equip"

func _get_rarity_color(rarity: ItemDefinition.Rarity) -> Color:
	return UiPresentation.get_rarity_color(rarity)
