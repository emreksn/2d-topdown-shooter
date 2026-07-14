class_name ActiveSkillHud
extends Control

@export var active_skill_loadout: ActiveSkillLoadoutComponent

var _labels: Array[Label] = []
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
	_weapon_button_rows.clear()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	for index: int in range(ActiveSkillLoadoutComponent.SLOT_COUNT):
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 8)
		column.add_child(slot_row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(180.0, 28.0)
		label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 1.0))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 15)
		slot_row.add_child(label)
		_labels.append(label)

		var weapon_buttons := HBoxContainer.new()
		weapon_buttons.add_theme_constant_override("separation", 4)
		slot_row.add_child(weapon_buttons)
		_weapon_button_rows.append(weapon_buttons)

func _refresh() -> void:
	if not is_instance_valid(active_skill_loadout):
		return
	for index: int in range(_labels.size()):
		var skill := active_skill_loadout.get_skill(index)
		var key := "Q" if index == 0 else "E"
		if skill == null:
			_labels[index].text = "%s: Empty" % key
		else:
			_labels[index].text = "%s: %s - %s" % [
				key,
				skill.display_name,
				skill.get_status_text(active_skill_loadout, index)
			]
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
		button.custom_minimum_size = Vector2(82.0, 24.0)
		button.focus_mode = Control.FOCUS_NONE
		button.text = (
			"W%d selected" % (weapon_slot + 1)
			if weapon_slot == bound_slot
			else "Use W%d" % (weapon_slot + 1)
		)
		button.disabled = weapon_slot == bound_slot
		button.pressed.connect(
			_on_weapon_button_pressed.bind(slot_index, weapon_slot)
		)
		row.add_child(button)

func _on_weapon_button_pressed(skill_slot_index: int, weapon_slot_index: int) -> void:
	if is_instance_valid(active_skill_loadout):
		active_skill_loadout.bind_skill_to_weapon(skill_slot_index, weapon_slot_index)
