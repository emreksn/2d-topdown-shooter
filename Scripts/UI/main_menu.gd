class_name MainMenu
extends Control

@export_file("*.tscn") var game_scene_path := "res://Scenes/Game/game.tscn"

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton

var _is_loading := false
var _loading_overlay: Control
var _options_overlay: Control
var _window_mode_option: OptionButton
var _monitor_option: OptionButton
var _resolution_option: OptionButton
var _vsync_check: CheckBox
var _fps_cap_option: OptionButton
var _ui_scale_option: OptionButton
var _settings_snapshot: Dictionary = {}

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_build_loading_overlay()
	_build_options_overlay()
	play_button.grab_focus()

func _on_play_pressed() -> void:
	if _is_loading:
		return
	_is_loading = true
	play_button.text = "LOADING..."
	play_button.disabled = true
	options_button.disabled = true
	quit_button.disabled = true
	_loading_overlay.visible = true
	await get_tree().process_frame

	var err := get_tree().change_scene_to_file(game_scene_path)
	if err != OK:
		_is_loading = false
		play_button.text = "PLAY"
		play_button.disabled = false
		options_button.disabled = false
		quit_button.disabled = false
		_loading_overlay.visible = false
		_show_loading_error("Could not load game scene.")

func _on_options_pressed() -> void:
	_settings_snapshot = GameSettings.get_snapshot()
	_populate_options()
	_options_overlay.visible = true
	_window_mode_option.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _build_loading_overlay() -> void:
	_loading_overlay = ColorRect.new()
	_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.color = Color(0.0, 0.0, 0.0, 0.48)
	_loading_overlay.visible = false
	add_child(_loading_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)

	var panel := PanelContainer.new()
	UiPresentation.apply_panel_style(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin, 22)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "LOADING..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	margin.add_child(label)

func _build_options_overlay() -> void:
	_options_overlay = ColorRect.new()
	_options_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_overlay.color = Color(0.0, 0.0, 0.0, 0.56)
	_options_overlay.visible = false
	add_child(_options_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540.0, 0.0)
	UiPresentation.apply_panel_style(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin, 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	_window_mode_option = _add_option_row(
		layout,
		"Window Mode",
		["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"]
	)
	_monitor_option = _add_option_row(layout, "Monitor", [])
	_resolution_option = _add_option_row(
		layout,
		"Resolution",
		["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"]
	)
	_vsync_check = CheckBox.new()
	_add_control_row(layout, "VSync", _vsync_check)
	_fps_cap_option = _add_option_row(
		layout,
		"FPS Cap",
		["Off", "60", "120", "144"]
	)
	_ui_scale_option = _add_option_row(
		layout,
		"UI Scale",
		["75%", "100%", "125%", "150%"]
	)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_options_cancelled)
	buttons.add_child(cancel_button)

	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_on_options_applied)
	buttons.add_child(apply_button)

func _add_option_row(
	parent: VBoxContainer,
	label_text: String,
	items: Array[String]
) -> OptionButton:
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)
	_add_control_row(parent, label_text, option)
	return option

func _add_control_row(
	parent: VBoxContainer,
	label_text: String,
	control: Control
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)

func _populate_options() -> void:
	_window_mode_option.select(_get_window_mode_index(GameSettings.window_mode))
	_monitor_option.clear()
	var screen_count := DisplayServer.get_screen_count()
	for index: int in range(screen_count):
		_monitor_option.add_item("Monitor %d" % (index + 1))
	_monitor_option.select(clampi(GameSettings.monitor_index, 0, maxi(screen_count - 1, 0)))
	_resolution_option.select(GameSettings.get_resolution_index())
	_vsync_check.button_pressed = GameSettings.vsync_enabled
	_fps_cap_option.select(GameSettings.get_fps_cap_index())
	_ui_scale_option.select(GameSettings.get_ui_scale_index())

func _on_options_applied() -> void:
	GameSettings.window_mode = _get_window_mode_id(_window_mode_option.selected)
	GameSettings.monitor_index = _monitor_option.selected
	GameSettings.resolution = GameSettings.RESOLUTIONS[_resolution_option.selected]
	GameSettings.vsync_enabled = _vsync_check.button_pressed
	GameSettings.fps_cap = GameSettings.FPS_CAPS[_fps_cap_option.selected]
	GameSettings.ui_scale = GameSettings.UI_SCALES[_ui_scale_option.selected]
	GameSettings.apply_and_save()
	_options_overlay.visible = false
	play_button.grab_focus()

func _on_options_cancelled() -> void:
	GameSettings.restore_snapshot(_settings_snapshot)
	_options_overlay.visible = false
	options_button.grab_focus()

func _get_window_mode_index(mode: String) -> int:
	match mode:
		GameSettings.WINDOW_MODE_WINDOWED:
			return 0
		GameSettings.WINDOW_MODE_FULLSCREEN:
			return 2
	return 1

func _get_window_mode_id(index: int) -> String:
	match index:
		0:
			return GameSettings.WINDOW_MODE_WINDOWED
		2:
			return GameSettings.WINDOW_MODE_FULLSCREEN
	return GameSettings.WINDOW_MODE_BORDERLESS

func _show_loading_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
