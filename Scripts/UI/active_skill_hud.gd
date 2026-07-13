class_name ActiveSkillHud
extends Control

@export var active_skill_loadout: ActiveSkillLoadoutComponent

var _labels: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for index: int in range(ActiveSkillLoadoutComponent.SLOT_COUNT):
		var label := Label.new()
		label.custom_minimum_size = Vector2(180.0, 28.0)
		label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 1.0))
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 15)
		row.add_child(label)
		_labels.append(label)

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
