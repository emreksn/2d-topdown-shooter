class_name ActiveSkillHud
extends Control

@export var active_skill_loadout: ActiveSkillLoadoutComponent

var _labels: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _weapon_button_rows: Array[HBoxContainer] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_resolve_dependencies()
	_build_ui()
	if is_instance_valid(active_skill_loadout):
		active_skill_loadout.skills_changed.connect(_refresh)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _resolve_dependencies() -> void:
	if is_instance_valid(active_skill_loadout):
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player != null:
		active_skill_loadout = player.get_node_or_null(
			"ActiveSkillLoadoutComponent"
		) as ActiveSkillLoadoutComponent

func _build_ui() -> void:
	_labels.clear()
	_bars.clear()
	_weapon_button_rows.clear()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	for index: int in range(ActiveSkillLoadoutComponent.SLOT_COUNT):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(340.0, 58.0)
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiPresentation.apply_subpanel_style(slot_panel, Color(0.035, 0.044, 0.058, 0.86))
		column.add_child(slot_panel)

		var slot_layout := VBoxContainer.new()
		slot_layout.add_theme_constant_override("separation", 4)
		slot_panel.add_child(slot_layout)

		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 8)
		slot_layout.add_child(slot_row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(200.0, 24.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiPresentation.apply_body_label(label, false, 14)
		slot_row.add_child(label)
		_labels.append(label)

		var weapon_buttons := HBoxContainer.new()
		weapon_buttons.add_theme_constant_override("separation", 4)
		slot_row.add_child(weapon_buttons)
		_weapon_button_rows.append(weapon_buttons)

		var cooldown_bar := ProgressBar.new()
		cooldown_bar.custom_minimum_size = Vector2(0.0, 8.0)
		cooldown_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cooldown_bar.show_percentage = false
		UiPresentation.apply_progress_bar_style(cooldown_bar, Color(0.22, 0.78, 0.95, 1.0))
		slot_layout.add_child(cooldown_bar)
		_bars.append(cooldown_bar)

func _refresh() -> void:
	if not is_instance_valid(active_skill_loadout):
		return
	for index: int in range(_labels.size()):
		var skill := active_skill_loadout.get_skill(index)
		var key := "Q" if index == 0 else "E"
		if skill == null:
			_labels[index].text = "%s: Empty" % key
			_bars[index].max_value = 1.0
			_bars[index].value = 0.0
		else:
			_labels[index].text = "%s: %s - %s" % [
				key,
				skill.display_name,
				skill.get_status_text(active_skill_loadout, index)
			]
			var cooldown := active_skill_loadout.get_cooldown_remaining(index)
			_bars[index].max_value = maxf(skill.cooldown_duration, 1.0)
			_bars[index].value = _bars[index].max_value - cooldown
		_refresh_weapon_buttons(index, skill)

func _refresh_weapon_buttons(
	slot_index: int,
	skill: ActiveSkillDefinition
) -> void:
	var row := _weapon_button_rows[slot_index]
	for child in row.get_children():
		child.queue_free()
	if skill == null or not skill.requires_weapon:
		return
	var eligible_slots := active_skill_loadout.get_eligible_weapon_slots(skill)
	var bound_slot := active_skill_loadout.get_bound_weapon_slot(slot_index)
	for weapon_slot in eligible_slots:
		var button := Button.new()
		button.custom_minimum_size = Vector2(72.0, 24.0)
		button.focus_mode = Control.FOCUS_NONE
		button.text = (
			"W%d" % (weapon_slot + 1)
			if weapon_slot == bound_slot
			else "Bind W%d" % (weapon_slot + 1)
		)
		button.disabled = weapon_slot == bound_slot
		UiPresentation.apply_action_button_style(button, Color(0.52, 0.72, 1.0, 1.0))
		button.pressed.connect(
			_on_weapon_button_pressed.bind(slot_index, weapon_slot)
		)
		row.add_child(button)

func _on_weapon_button_pressed(skill_slot_index: int, weapon_slot_index: int) -> void:
	if is_instance_valid(active_skill_loadout):
		active_skill_loadout.bind_skill_to_weapon(skill_slot_index, weapon_slot_index)
