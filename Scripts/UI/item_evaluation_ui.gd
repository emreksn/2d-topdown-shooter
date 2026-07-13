class_name ItemEvaluationUI
extends CanvasLayer

@export var evaluation_director: ItemEvaluationDirector

var _root_panel: PanelContainer
var _title_label: Label
var _name_label: Label
var _details_label: Label
var _keep_button: Button
var _sell_button: Button
var _desired_panel_size := Vector2(660.0, 390.0)

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
	_title_label.add_theme_font_size_override("font_size", 24)
	layout.add_child(_title_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_name_label)

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
	details_scroll.add_child(_details_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	_keep_button = Button.new()
	_keep_button.text = "Keep"
	_keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_button.pressed.connect(_on_keep_pressed)
	buttons.add_child(_keep_button)

	_sell_button = Button.new()
	_sell_button.text = "Sell"
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_button.pressed.connect(_on_sell_pressed)
	buttons.add_child(_sell_button)

func _on_evaluation_started(_total_count: int) -> void:
	_root_panel.visible = true

func _on_evaluation_completed() -> void:
	_root_panel.visible = false

func _on_current_item_changed(
	item: ItemDefinition,
	item_index: int,
	total_count: int
) -> void:
	_root_panel.visible = true
	_title_label.text = "ITEM EVALUATION  (%d / %d)" % [
		item_index,
		total_count
	]
	if item == null:
		_name_label.text = "Unknown Item"
		_details_label.text = ""
		return
	_name_label.text = "%s %s" % [
		item.get_rarity_display_name(),
		item.display_name
	]
	_name_label.add_theme_color_override("font_color", _get_rarity_color(item.rarity))
	_details_label.text = item.get_stat_display_text()
	_sell_button.disabled = not item.sellable
	var value := item.get_sell_value(
		evaluation_director.current_wave_number
		if is_instance_valid(evaluation_director)
		else 1
	)
	_sell_button.text = "Sell %dg" % value if item.sellable else "Cannot Sell"

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, _desired_panel_size)

func _on_keep_pressed() -> void:
	if is_instance_valid(evaluation_director):
		evaluation_director.keep_current()

func _on_sell_pressed() -> void:
	if is_instance_valid(evaluation_director):
		evaluation_director.sell_current()

func _get_rarity_color(rarity: ItemDefinition.Rarity) -> Color:
	return UiPresentation.get_rarity_color(rarity)
