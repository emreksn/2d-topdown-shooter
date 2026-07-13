class_name MonsterInspectTooltip
extends CanvasLayer

const INSPECTED_STATS: Array[StringName] = [
	StatIds.MAXIMUM_HEALTH,
	StatIds.MOVEMENT_SPEED,
	StatIds.MELEE_DAMAGE,
	StatIds.TOUGHNESS,
	StatIds.MONSTER_EFFECTIVENESS,
	StatIds.PHYSICAL_RESISTANCE,
	StatIds.FIRE_RESISTANCE,
	StatIds.LIGHTNING_RESISTANCE,
	StatIds.COLD_RESISTANCE,
	StatIds.EXPERIENCE_GRANTED_MULTIPLIER,
	StatIds.GOLD_GRANTED_MULTIPLIER,
	StatIds.ITEM_QUANTITY_MULTIPLIER,
	StatIds.MONSTER_ITEM_RARITY_MULTIPLIER
]

@export var cursor_offset := Vector2(18.0, 18.0)
@export_range(160.0, 520.0, 1.0) var panel_width: float = 360.0

var _enemy: Enemy
var _panel: PanelContainer
var _label: RichTextLabel

func _ready() -> void:
	add_to_group(&"monster_inspect_tooltip")
	layer = 90
	_build_ui()
	hide()

func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_enemy) or _enemy.is_queued_for_deletion():
		hide()
		return
	_panel.position = _get_clamped_position()

func show_enemy(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	_enemy = enemy
	_label.text = _build_tooltip_text(enemy)
	_panel.size = Vector2.ZERO
	_panel.position = _get_clamped_position()
	show()

func hide_enemy(enemy: Enemy = null) -> void:
	if enemy != null and enemy != _enemy:
		return
	_enemy = null
	hide()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.055, 0.94)
	style.border_color = Color(0.22, 0.72, 0.82, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(panel_width - 24.0, 0.0)
	_label.add_theme_color_override("default_color", Color(0.88, 0.92, 0.95))
	_label.add_theme_font_size_override("normal_font_size", 13)
	_panel.add_child(_label)

func _build_tooltip_text(enemy: Enemy) -> String:
	var stats := enemy.get_node_or_null("StatComponent") as StatComponent
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	var rewards := enemy.get_node_or_null(
		"MonsterRewardComponent"
	) as MonsterRewardComponent
	var player_stats := _get_player_stats()

	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % enemy.get_inspection_name())
	lines.append("[color=#8ecfe0]Tags:[/color] %s" % _format_tags(enemy.spawn_tags))
	if is_instance_valid(health):
		lines.append(
			"[color=#8ecfe0]Health:[/color] %s / %s"
			% [
				_format_number(health.current_health),
				_format_number(health.maximum_health)
			]
		)
	if is_instance_valid(stats):
		var changed_stat_lines := _get_changed_stat_lines(stats, enemy.spawn_tags)
		if not changed_stat_lines.is_empty():
			lines.append("")
			lines.append("[b]Stat Changes[/b] [color=#9aa5b1](base -> wave)[/color]")
			lines.append_array(changed_stat_lines)
	if is_instance_valid(rewards):
		lines.append("")
		lines.append("[b]Expected Rewards[/b]")
		lines.append(
			"Base: cost %d, XP/cost %s, gold/cost %s, item/cost %s%%"
			% [
				rewards.spawn_cost,
				_format_number(rewards.experience_per_spawn_cost),
				_format_number(rewards.gold_per_spawn_cost),
				_format_number(rewards.item_drop_chance_per_spawn_cost)
			]
		)
		var xp := rewards.get_expected_experience(player_stats)
		var gold := rewards.get_expected_gold(player_stats)
		lines.append(
			"XP: %s avg (%s-%s)"
			% [
				_format_number(xp),
				_format_number(xp * (1.0 - rewards.experience_variance)),
				_format_number(xp * (1.0 + rewards.experience_variance))
			]
		)
		lines.append(
			"Gold: %s avg (%s-%s)"
			% [
				_format_number(gold),
				_format_number(gold * (1.0 - rewards.gold_variance)),
				_format_number(gold * (1.0 + rewards.gold_variance))
			]
		)
		lines.append(
			"Item drops: %s expected, %s%% chance"
			% [
				_format_number(rewards.get_expected_item_drop_count(player_stats)),
				_format_number(rewards.get_item_drop_chance_percent(player_stats))
			]
		)
		var rarity_text := _format_rarity_chances(
			rewards.get_item_rarity_chances(player_stats)
		)
		lines.append("Item rarities on drop: %s" % rarity_text)
	return "\n".join(lines)

func _get_changed_stat_lines(
	stats: StatComponent,
	context_tags: Array[StringName]
) -> Array[String]:
	var lines: Array[String] = []
	for stat_id in INSPECTED_STATS:
		var line := _format_changed_stat_line(stats, stat_id, context_tags)
		if line != "":
			lines.append(line)
	return lines

func _format_changed_stat_line(
	stats: StatComponent,
	stat_id: StringName,
	context_tags: Array[StringName]
) -> String:
	var definition := stats.catalog.get_definition(stat_id) if stats.catalog != null else null
	var display_name := definition.display_name if definition != null else String(stat_id).replace("_", " ").capitalize()
	var base := stats.get_base_stat(stat_id)
	var wave_scaled := stats.get_stat(stat_id, context_tags)
	if is_equal_approx(base, wave_scaled):
		return ""
	return "%s: %s -> %s" % [
		display_name,
		_format_stat_value(definition, base),
		_format_stat_value(definition, wave_scaled)
	]

func _format_stat_value(definition: StatDefinition, value: float) -> String:
	if definition != null and definition.display_as_percentage:
		return "%s%%" % _format_number(value)
	if definition != null and definition.default_value == 1.0:
		return "%s%%" % _format_number(value * 100.0)
	return _format_number(value)

func _format_rarity_chances(chances: Dictionary) -> String:
	if chances.is_empty():
		return "none"
	var parts: Array[String] = []
	for rarity in ItemRarityManager.RARITY_ORDER:
		if not chances.has(rarity):
			continue
		parts.append("%s %s%%" % [
			ItemDefinition.get_rarity_name(rarity),
			_format_number(float(chances[rarity]))
		])
	return ", ".join(parts)

func _format_tags(tags: Array[StringName]) -> String:
	if tags.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for tag in tags:
		parts.append(String(tag))
	return ", ".join(parts)

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")

func _get_player_stats() -> StatComponent:
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("StatComponent") as StatComponent

func _get_clamped_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var wanted := get_viewport().get_mouse_position() + cursor_offset
	var panel_size := _panel.size
	if panel_size == Vector2.ZERO:
		panel_size = _panel.get_combined_minimum_size()
	if wanted.x + panel_size.x > viewport_size.x:
		wanted.x = get_viewport().get_mouse_position().x - panel_size.x - cursor_offset.x
	if wanted.y + panel_size.y > viewport_size.y:
		wanted.y = get_viewport().get_mouse_position().y - panel_size.y - cursor_offset.y
	wanted.x = clampf(wanted.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	wanted.y = clampf(wanted.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	return wanted
