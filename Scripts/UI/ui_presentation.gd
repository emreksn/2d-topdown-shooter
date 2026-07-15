class_name UiPresentation
extends RefCounted

const SAFE_MARGIN := 24.0
const PANEL_BG := Color(0.045, 0.052, 0.068, 0.96)
const PANEL_BORDER := Color(0.22, 0.78, 0.92, 0.72)
const TEXT_PRIMARY := Color(0.94, 0.97, 1.0, 1.0)
const TEXT_MUTED := Color(0.58, 0.66, 0.72, 1.0)
const GOLD := Color(1.0, 0.78, 0.28, 1.0)
const DANGER := Color(1.0, 0.34, 0.34, 1.0)

static func get_ui_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var settings := tree.root.get_node_or_null("/root/GameSettings")
	if settings == null:
		return 1.0
	return float(settings.get("ui_scale"))

static func resize_center_panel(
	panel: Control,
	desired_size: Vector2,
	safe_margin: float = SAFE_MARGIN
) -> void:
	if not is_instance_valid(panel):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var viewport_size := tree.root.get_visible_rect().size
	var scale := get_ui_scale()
	var target_size := desired_size * scale
	target_size.x = minf(target_size.x, maxf(viewport_size.x - safe_margin * 2.0, 260.0))
	target_size.y = minf(target_size.y, maxf(viewport_size.y - safe_margin * 2.0, 220.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5

static func apply_panel_style(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_BORDER
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 6.0)
	panel.add_theme_stylebox_override("panel", style)

static func apply_subpanel_style(panel: Control, color: Color = Color(0.075, 0.085, 0.105, 0.9)) -> void:
	if not is_instance_valid(panel):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.22, 0.27, 0.34, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

static func apply_standard_margins(
	margin: MarginContainer,
	value: int = 18
) -> void:
	if not is_instance_valid(margin):
		return
	margin.add_theme_constant_override("margin_left", value)
	margin.add_theme_constant_override("margin_top", value)
	margin.add_theme_constant_override("margin_right", value)
	margin.add_theme_constant_override("margin_bottom", value)

static func apply_heading(label: Label, font_size: int = 24) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", font_size)

static func apply_body_label(label: Label, muted: bool = false, font_size: int = 13) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", TEXT_MUTED if muted else TEXT_PRIMARY)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", font_size)

static func apply_rarity_button_style(
	button: Button,
	rarity: ItemDefinition.Rarity
) -> void:
	apply_button_style(button, get_rarity_color(rarity))
	button.add_theme_color_override(
		"font_disabled_color",
		Color(get_rarity_color(rarity), 0.45)
	)

static func apply_button_style(button: Button, color: Color) -> void:
	if not is_instance_valid(button):
		return
	button.flat = false
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", color.lightened(0.25))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.53, 0.58, 0.82))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	button.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.content_margin_left = 14.0
		style.content_margin_top = 10.0
		style.content_margin_right = 14.0
		style.content_margin_bottom = 10.0
		style.bg_color = Color(0.065, 0.078, 0.098, 0.96)
		if state == "hover":
			style.bg_color = Color(0.095, 0.12, 0.145, 0.98)
		elif state == "pressed":
			style.bg_color = Color(0.035, 0.045, 0.058, 1.0)
		elif state == "disabled":
			style.bg_color = Color(0.035, 0.038, 0.048, 0.82)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(color, 0.88 if state != "disabled" else 0.28)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", _make_focus_style(color))

static func apply_action_button_style(button: Button, color: Color = PANEL_BORDER) -> void:
	apply_button_style(button, color)
	button.add_theme_font_size_override("font_size", 15)

static func apply_empty_button_style(button: Button) -> void:
	if not is_instance_valid(button):
		return
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.035, 0.045, 0.72)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.18, 0.19, 0.22, 1.0)
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_right = 5
		style.corner_radius_bottom_left = 5
		button.add_theme_stylebox_override(state, style)

static func apply_progress_bar_style(
	bar: ProgressBar,
	fill_color: Color,
	background_color: Color = Color(0.045, 0.052, 0.068, 0.96)
) -> void:
	if not is_instance_valid(bar):
		return
	var background := StyleBoxFlat.new()
	background.bg_color = background_color
	background.border_width_left = 1
	background.border_width_top = 1
	background.border_width_right = 1
	background.border_width_bottom = 1
	background.border_color = Color(0.02, 0.025, 0.032, 0.95)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_right = 4
	background.corner_radius_bottom_left = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_right = 4
	fill.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

static func _make_focus_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.18)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color.lightened(0.18)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

static func get_rarity_color(rarity: ItemDefinition.Rarity) -> Color:
	match rarity:
		ItemDefinition.Rarity.COMMON:
			return Color(0.86, 0.88, 0.9, 1.0)
		ItemDefinition.Rarity.UNCOMMON:
			return Color(0.28, 0.95, 0.45, 1.0)
		ItemDefinition.Rarity.RARE:
			return Color(0.3, 0.62, 1.0, 1.0)
		ItemDefinition.Rarity.LEGENDARY:
			return Color(1.0, 0.72, 0.24, 1.0)
		ItemDefinition.Rarity.TRADEOFF:
			return Color(1.0, 0.28, 0.32, 1.0)
		ItemDefinition.Rarity.UNIQUE:
			return Color(0.96, 0.42, 1.0, 1.0)
	return Color.WHITE
