class_name ContentChoiceUI
extends CanvasLayer

@export var content_manager: ContentManager

var _root_panel: PanelContainer
var _title_label: Label
var _choice_list: HBoxContainer
var _desired_panel_size := Vector2(780.0, 360.0)

func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	GameSettings.settings_changed.connect(_resize_panel)
	_root_panel.visible = false
	if is_instance_valid(content_manager):
		content_manager.selection_started.connect(_on_selection_started)
		content_manager.selection_completed.connect(_on_selection_completed)
		content_manager.choices_changed.connect(_on_choices_changed)

func _resolve_dependencies() -> void:
	if not is_instance_valid(content_manager):
		content_manager = get_tree().get_first_node_in_group(
			&"content_manager"
		) as ContentManager

func _build_ui() -> void:
	_root_panel = PanelContainer.new()
	UiPresentation.apply_panel_style(_root_panel)
	add_child(_root_panel)
	_resize_panel()

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin)
	_root_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.text = "NEXT WAVE CONTENT"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(_title_label)

	var scroller := ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroller)

	_choice_list = HBoxContainer.new()
	_choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_list.add_theme_constant_override("separation", 12)
	scroller.add_child(_choice_list)

func _on_selection_started(next_wave_number: int, _options: Array) -> void:
	_title_label.text = "WAVE %d CONTENT" % next_wave_number
	_root_panel.visible = true

func _on_selection_completed(
	_next_wave_number: int,
	_selected_offer: ContentOffer
) -> void:
	_root_panel.visible = false
	_clear_choices()

func _on_choices_changed(options: Array) -> void:
	_root_panel.visible = true
	_clear_choices()
	for index: int in range(options.size()):
		_choice_list.add_child(_make_choice_button(options[index], index))

func _make_choice_button(option: ContentOffer, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(230.0, 210.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if option == null or option.content == null:
		_add_card_text(
			button,
			"No Extra Content",
			["Start a normal wave."],
			[]
		)
		_apply_button_style(button, Color(0.72, 0.76, 0.8, 1.0))
	else:
		_add_card_text(
			button,
			option.get_display_name(),
			option.get_grant_lines(),
			option.get_extra_lines()
		)
		button.tooltip_text = _build_offer_tooltip(option)
		_apply_button_style(button, Color(0.7, 0.45, 1.0, 1.0))
	button.pressed.connect(_on_choice_pressed.bind(index))
	return button

func _on_choice_pressed(index: int) -> void:
	if is_instance_valid(content_manager):
		content_manager.choose_option(index)

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, _desired_panel_size)

func _clear_choices() -> void:
	while _choice_list.get_child_count() > 0:
		var child := _choice_list.get_child(0)
		_choice_list.remove_child(child)
		child.queue_free()

func _apply_button_style(button: Button, color: Color) -> void:
	UiPresentation.apply_button_style(button, color)

func _add_card_text(
	button: Button,
	title: String,
	grant_lines: Array[String],
	extra_lines: Array[String]
) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(title_label)

	if not grant_lines.is_empty():
		var grants_label := _make_body_label(
			"%s Grants:\n%s" % [title, "\n".join(grant_lines)]
		)
		layout.add_child(grants_label)

	var extra_label := _make_body_label(
		"Extra Modifiers:\n%s" % (
			"\n".join(extra_lines)
			if not extra_lines.is_empty()
			else "None"
		)
	)
	layout.add_child(extra_label)

func _make_body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return label

func _build_offer_tooltip(option: ContentOffer) -> String:
	var lines: Array[String] = [option.get_grant_heading()]
	var grant_lines := option.get_grant_lines()
	if grant_lines.is_empty():
		lines.append("No extra modifiers.")
	else:
		lines.append_array(grant_lines)
	lines.append("")
	lines.append("Extra Modifiers:")
	var extra_lines := option.get_extra_lines()
	if extra_lines.is_empty():
		lines.append("None")
	else:
		lines.append_array(extra_lines)
	return "\n".join(lines)
