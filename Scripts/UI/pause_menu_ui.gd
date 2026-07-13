class_name PauseMenuUI
extends CanvasLayer

@export var player: Node
@export_file("*.tscn") var main_menu_scene_path := "res://Scenes/UI/main_menu.tscn"

var _root: Control
var _stats_list: VBoxContainer
var _modified_only: CheckBox
var _paused_by_menu := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	_root.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		_toggle_pause_menu()
		get_viewport().set_input_as_handled()

func _resolve_dependencies() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player")

func _build_ui() -> void:
	_root = ColorRect.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.color = Color(0.0, 0.0, 0.0, 0.58)
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900.0, 620.0)
	UiPresentation.apply_panel_style(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin, 22)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	layout.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	layout.add_child(body)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(170.0, 0.0)
	menu.add_theme_constant_override("separation", 10)
	body.add_child(menu)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_close_pause_menu)
	menu.add_child(resume_button)

	var stats_button := Button.new()
	stats_button.text = "Stats"
	stats_button.disabled = true
	menu.add_child(stats_button)

	var quit_button := Button.new()
	quit_button.text = "Main Menu"
	quit_button.pressed.connect(_go_to_main_menu)
	menu.add_child(quit_button)

	var stats_panel := VBoxContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_constant_override("separation", 10)
	body.add_child(stats_panel)

	var stats_header := HBoxContainer.new()
	stats_header.add_theme_constant_override("separation", 12)
	stats_panel.add_child(stats_header)

	var stats_title := Label.new()
	stats_title.text = "Stats"
	stats_title.add_theme_font_size_override("font_size", 22)
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_header.add_child(stats_title)

	_modified_only = CheckBox.new()
	_modified_only.text = "Modified only"
	_modified_only.toggled.connect(func(_enabled: bool) -> void:
		_refresh_stats()
	)
	stats_header.add_child(_modified_only)

	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 12)
	stats_panel.add_child(headings)
	_add_header_label(headings, "Stat", 260.0)
	_add_header_label(headings, "Base", 120.0)
	_add_header_label(headings, "Current", 120.0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stats_panel.add_child(scroll)

	_stats_list = VBoxContainer.new()
	_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_stats_list)

func _add_header_label(parent: Control, text: String, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0.0)
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _toggle_pause_menu() -> void:
	if _root.visible:
		_close_pause_menu()
		return
	var tree := get_tree()
	if tree != null and tree.paused:
		return
	_open_pause_menu()

func _open_pause_menu() -> void:
	_refresh_stats()
	_root.visible = true
	var tree := get_tree()
	if tree != null and not tree.paused:
		tree.paused = true
		_paused_by_menu = true

func _close_pause_menu() -> void:
	_root.visible = false
	if not _paused_by_menu:
		return
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_paused_by_menu = false

func _go_to_main_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	_paused_by_menu = false
	tree.change_scene_to_file(main_menu_scene_path)

func _refresh_stats() -> void:
	if not is_instance_valid(_stats_list):
		return
	_clear_stats()
	if not is_instance_valid(player):
		_resolve_dependencies()
	if not is_instance_valid(player):
		_add_note("No player found.")
		return

	var player_stats := player.get_node_or_null("StatComponent") as StatComponent
	if is_instance_valid(player_stats):
		_add_component_section("Player", player_stats)

	var weapon_mount := player.get_node_or_null("WeaponMount")
	if weapon_mount != null:
		for weapon in weapon_mount.get_children():
			for child in weapon.get_children():
				if child is StatComponent:
					_add_component_section("%s Weapon" % weapon.name, child)

func _clear_stats() -> void:
	while _stats_list.get_child_count() > 0:
		var child := _stats_list.get_child(0)
		_stats_list.remove_child(child)
		child.queue_free()

func _add_component_section(title: String, stats: StatComponent) -> void:
	var section_label := Label.new()
	section_label.text = title
	section_label.add_theme_font_size_override("font_size", 17)
	section_label.add_theme_color_override("font_color", Color(0.74, 0.86, 1.0, 1.0))
	_stats_list.add_child(section_label)

	var added := 0
	if stats.catalog == null:
		_add_note("No stat catalog.")
		return
	for definition in stats.catalog.definitions:
		if definition == null:
			continue
		if _add_stat_row(stats, definition):
			added += 1
	if added == 0:
		_add_note("No modified stats." if _modified_only.button_pressed else "No stats.")

func _add_stat_row(stats: StatComponent, definition: StatDefinition) -> bool:
	var base := _get_base_value(stats, definition)
	var current := stats.get_stat(definition.id)
	var delta := current - base
	if _modified_only.button_pressed and is_equal_approx(delta, 0.0):
		return false

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_stats_list.add_child(row)

	var name_label := Label.new()
	name_label.text = definition.display_name
	name_label.custom_minimum_size = Vector2(260.0, 0.0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)

	var base_label := Label.new()
	base_label.text = _format_stat_value(base, definition)
	base_label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(base_label)

	var current_label := Label.new()
	current_label.text = _format_stat_value(current, definition)
	current_label.custom_minimum_size = Vector2(120.0, 0.0)
	current_label.add_theme_color_override("font_color", _get_delta_color(delta))
	row.add_child(current_label)
	return true

func _get_base_value(stats: StatComponent, definition: StatDefinition) -> float:
	if stats.base_profile == null:
		return definition.default_value
	return stats.base_profile.get_base_value(definition.id, definition.default_value)

func _format_stat_value(value: float, definition: StatDefinition) -> String:
	if definition.display_as_percentage:
		return "%.1f%%" % value
	if absf(value - roundf(value)) < 0.005:
		return "%d" % roundi(value)
	return "%.2f" % value

func _get_delta_color(delta: float) -> Color:
	if delta > 0.005:
		return Color(0.34, 1.0, 0.48, 1.0)
	if delta < -0.005:
		return Color(1.0, 0.34, 0.34, 1.0)
	return Color(0.86, 0.88, 0.9, 1.0)

func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_list.add_child(label)
