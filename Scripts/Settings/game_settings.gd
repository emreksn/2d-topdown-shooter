extends Node

signal settings_changed

const CONFIG_PATH := "user://settings.cfg"
const SECTION_DISPLAY := "display"
const SECTION_INTERFACE := "interface"

const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_BORDERLESS := "borderless"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_MARGIN := 64

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
const UI_SCALES: Array[float] = [0.75, 1.0, 1.25, 1.5]
const FPS_CAPS: Array[int] = [0, 60, 120, 144]

var window_mode := WINDOW_MODE_WINDOWED
var monitor_index := 0
var resolution := Vector2i(1920, 1080)
var vsync_enabled := true
var fps_cap := 0
var ui_scale := 1.0

func _ready() -> void:
	load_settings()
	call_deferred("_apply_startup_settings")

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		return

	window_mode = str(config.get_value(
		SECTION_DISPLAY,
		"window_mode",
		window_mode
	))
	monitor_index = int(config.get_value(
		SECTION_DISPLAY,
		"monitor_index",
		monitor_index
	))
	var width := int(config.get_value(
		SECTION_DISPLAY,
		"resolution_width",
		resolution.x
	))
	var height := int(config.get_value(
		SECTION_DISPLAY,
		"resolution_height",
		resolution.y
	))
	resolution = Vector2i(width, height)
	vsync_enabled = bool(config.get_value(
		SECTION_DISPLAY,
		"vsync_enabled",
		vsync_enabled
	))
	fps_cap = int(config.get_value(
		SECTION_DISPLAY,
		"fps_cap",
		fps_cap
	))
	ui_scale = float(config.get_value(
		SECTION_INTERFACE,
		"ui_scale",
		ui_scale
	))

	_validate_values()

func save_settings() -> void:
	_validate_values()
	var config := ConfigFile.new()
	config.set_value(SECTION_DISPLAY, "window_mode", window_mode)
	config.set_value(SECTION_DISPLAY, "monitor_index", monitor_index)
	config.set_value(SECTION_DISPLAY, "resolution_width", resolution.x)
	config.set_value(SECTION_DISPLAY, "resolution_height", resolution.y)
	config.set_value(SECTION_DISPLAY, "vsync_enabled", vsync_enabled)
	config.set_value(SECTION_DISPLAY, "fps_cap", fps_cap)
	config.set_value(SECTION_INTERFACE, "ui_scale", ui_scale)
	config.save(CONFIG_PATH)

func apply_and_save() -> void:
	_validate_values()
	apply_display_settings()
	save_settings()
	settings_changed.emit()

func apply_runtime_settings() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if vsync_enabled
		else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = fps_cap

func apply_display_settings() -> void:
	_validate_values()
	apply_runtime_settings()
	var target_screen := _get_valid_monitor_index(monitor_index)
	monitor_index = target_screen
	var screen_position := DisplayServer.screen_get_position(target_screen)
	var screen_size := DisplayServer.screen_get_size(target_screen)

	match window_mode:
		WINDOW_MODE_FULLSCREEN:
			_prepare_window_on_monitor(target_screen, screen_position, screen_size)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			)
		WINDOW_MODE_BORDERLESS:
			_prepare_window_on_monitor(target_screen, screen_position, screen_size)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(screen_position)
			DisplayServer.window_set_size(screen_size)
		_:
			_prepare_window_on_monitor(target_screen, screen_position, screen_size)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var window_size := _get_safe_windowed_size(screen_size)
			DisplayServer.window_set_size(window_size)
			_center_window(target_screen, window_size)

	_restore_window_focus()

func get_snapshot() -> Dictionary:
	return {
		"window_mode": window_mode,
		"monitor_index": monitor_index,
		"resolution": resolution,
		"vsync_enabled": vsync_enabled,
		"fps_cap": fps_cap,
		"ui_scale": ui_scale
	}

func restore_snapshot(snapshot: Dictionary) -> void:
	window_mode = str(snapshot.get("window_mode", WINDOW_MODE_WINDOWED))
	monitor_index = int(snapshot.get("monitor_index", 0))
	resolution = snapshot.get("resolution", Vector2i(1920, 1080))
	vsync_enabled = bool(snapshot.get("vsync_enabled", true))
	fps_cap = int(snapshot.get("fps_cap", 0))
	ui_scale = float(snapshot.get("ui_scale", 1.0))
	_validate_values()
	settings_changed.emit()

func get_resolution_index() -> int:
	for index: int in range(RESOLUTIONS.size()):
		if RESOLUTIONS[index] == resolution:
			return index
	return 2

func get_ui_scale_index() -> int:
	for index: int in range(UI_SCALES.size()):
		if is_equal_approx(UI_SCALES[index], ui_scale):
			return index
	return 1

func get_fps_cap_index() -> int:
	for index: int in range(FPS_CAPS.size()):
		if FPS_CAPS[index] == fps_cap:
			return index
	return 0

func _apply_startup_settings() -> void:
	apply_display_settings()

func _prepare_window_on_monitor(
	screen_index: int,
	screen_position: Vector2i,
	screen_size: Vector2i
) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_current_screen(screen_index)
	DisplayServer.window_set_position(screen_position + Vector2i(32, 32))
	DisplayServer.window_set_size(_get_safe_windowed_size(screen_size))

func _center_window(screen_index: int, window_size: Vector2i) -> void:
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	var offset := screen_size - window_size
	var centered_position := screen_position + Vector2i(
		floori(float(offset.x) * 0.5),
		floori(float(offset.y) * 0.5)
	)
	DisplayServer.window_set_position(centered_position)

func _get_safe_windowed_size(screen_size: Vector2i) -> Vector2i:
	var max_size := Vector2i(
		maxi(screen_size.x - WINDOW_MARGIN, 640),
		maxi(screen_size.y - WINDOW_MARGIN, 360)
	)
	return Vector2i(
		mini(resolution.x, max_size.x),
		mini(resolution.y, max_size.y)
	)

func _get_valid_monitor_index(index: int) -> int:
	var screen_count := DisplayServer.get_screen_count()
	return clampi(index, 0, maxi(screen_count - 1, 0))

func _restore_window_focus() -> void:
	if DisplayServer.has_method("window_move_to_foreground"):
		DisplayServer.window_move_to_foreground()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _validate_values() -> void:
	if window_mode not in [
		WINDOW_MODE_WINDOWED,
		WINDOW_MODE_BORDERLESS,
		WINDOW_MODE_FULLSCREEN
	]:
		window_mode = WINDOW_MODE_WINDOWED

	monitor_index = _get_valid_monitor_index(monitor_index)

	if resolution not in RESOLUTIONS:
		resolution = Vector2i(1920, 1080)
	if fps_cap not in FPS_CAPS:
		fps_cap = 0

	var valid_scale := false
	for scale: float in UI_SCALES:
		if is_equal_approx(scale, ui_scale):
			valid_scale = true
			break
	if not valid_scale:
		ui_scale = 1.0
