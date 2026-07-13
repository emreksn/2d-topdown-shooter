class_name LevelUpUI
extends CanvasLayer

@export var level_up_director: LevelUpDirector

var _root_panel: PanelContainer
var _title_label: Label
var _choice_list: HBoxContainer
var _desired_panel_size := Vector2(720.0, 340.0)

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	GameSettings.settings_changed.connect(_resize_panel)
	_root_panel.visible = false
	if is_instance_valid(level_up_director):
		level_up_director.sequence_started.connect(_on_sequence_started)
		level_up_director.sequence_completed.connect(_on_sequence_completed)
		level_up_director.choices_changed.connect(_on_choices_changed)

func _resolve_dependencies() -> void:
	if not is_instance_valid(level_up_director):
		level_up_director = get_tree().get_first_node_in_group(
			&"level_up_director"
		) as LevelUpDirector

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
	_title_label.text = "LEVEL UP"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	layout.add_child(_title_label)

	_choice_list = HBoxContainer.new()
	_choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_list.add_theme_constant_override("separation", 12)
	layout.add_child(_choice_list)

func _on_sequence_started(_pending_count: int) -> void:
	_root_panel.visible = true

func _on_sequence_completed() -> void:
	_root_panel.visible = false
	_clear_choices()

func _on_choices_changed(
	options: Array[LevelUpOption],
	pending_count: int
) -> void:
	_root_panel.visible = true
	_title_label.text = "LEVEL UP"
	if pending_count > 1:
		_title_label.text = "LEVEL UP  (%d queued)" % pending_count
	_clear_choices()
	for index: int in range(options.size()):
		_choice_list.add_child(_make_choice_button(options[index], index))

func _make_choice_button(option: LevelUpOption, index: int) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(210.0, 150.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.text = "%s\n%s" % [
		ItemDefinition.get_rarity_name(option.rarity),
		option.get_display_text()
	]
	UiPresentation.apply_rarity_button_style(button, option.rarity)
	button.pressed.connect(_on_choice_pressed.bind(index))
	return button

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, _desired_panel_size)

func _on_choice_pressed(index: int) -> void:
	if is_instance_valid(level_up_director):
		level_up_director.choose_option(index)

func _clear_choices() -> void:
	while _choice_list.get_child_count() > 0:
		var child := _choice_list.get_child(0)
		_choice_list.remove_child(child)
		child.queue_free()

func _get_rarity_color(rarity: ItemDefinition.Rarity) -> Color:
	return UiPresentation.get_rarity_color(rarity)
