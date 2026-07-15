class_name StarterSkillChoiceUI
extends CanvasLayer

@export var active_skill_loadout: ActiveSkillLoadoutComponent
@export var weapon_loadout: WeaponLoadoutComponent
@export var available_skills: Array[ActiveSkillDefinition] = []
@export_range(1, 4, 1, "or_greater") var choices_required: int = 2
@export var replace_existing_skills: bool = true

var _root_panel: PanelContainer
var _title_label: Label
var _summary_label: Label
var _choice_row: HBoxContainer
var _selected_skill_ids: Dictionary = {}
var _selected_count: int = 0
var _completed := false
var _started := false
var _show_queued := false

func _ready() -> void:
	layer = 33
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	GameSettings.settings_changed.connect(_resize_panel)
	if is_instance_valid(weapon_loadout):
		weapon_loadout.loadout_changed.connect(_on_weapon_loadout_changed)
	_queue_show_if_ready()

func _resolve_dependencies() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player == null:
		return
	if not is_instance_valid(active_skill_loadout):
		active_skill_loadout = player.get_node_or_null(
			"ActiveSkillLoadoutComponent"
		) as ActiveSkillLoadoutComponent
	if not is_instance_valid(weapon_loadout):
		weapon_loadout = player.get_node_or_null(
			"WeaponLoadoutComponent"
		) as WeaponLoadoutComponent

func _build_ui() -> void:
	_root_panel = PanelContainer.new()
	UiPresentation.apply_panel_style(_root_panel)
	_root_panel.visible = false
	add_child(_root_panel)
	_resize_panel()

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin)
	_root_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_heading(_title_label, 26)
	layout.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_body_label(_summary_label, true, 14)
	layout.add_child(_summary_label)

	_choice_row = HBoxContainer.new()
	_choice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_row.add_theme_constant_override("separation", 10)
	layout.add_child(_choice_row)

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, Vector2(820.0, 340.0))

func _on_weapon_loadout_changed() -> void:
	_queue_show_if_ready()

func _queue_show_if_ready() -> void:
	if _show_queued:
		return
	_show_queued = true
	_try_show_selection.call_deferred()

func _try_show_selection() -> void:
	_show_queued = false
	_resolve_dependencies()
	if not _should_show_selection():
		return
	if not _started:
		_started = true
		_selected_count = 0
		_selected_skill_ids.clear()
		if replace_existing_skills:
			for index: int in range(ActiveSkillLoadoutComponent.SLOT_COUNT):
				active_skill_loadout.equip_skill(index, null)
	_refresh_choices()
	_root_panel.visible = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true

func _should_show_selection() -> bool:
	return (
		not _completed
		and is_instance_valid(active_skill_loadout)
		and is_instance_valid(weapon_loadout)
		and weapon_loadout.get_equipped_count() > 0
		and not available_skills.is_empty()
	)

func _refresh_choices() -> void:
	_title_label.text = "CHOOSE SKILL %d OF %d" % [
		_selected_count + 1,
		min(choices_required, ActiveSkillLoadoutComponent.SLOT_COUNT)
	]
	_summary_label.text = "Pick one skill for this slot."
	for child in _choice_row.get_children():
		child.queue_free()
	for skill in available_skills:
		if skill != null:
			_choice_row.add_child(_make_skill_button(skill))

func _make_skill_button(skill: ActiveSkillDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(240.0, 160.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var unavailable_reason := _get_unavailable_reason(skill)
	button.disabled = not unavailable_reason.is_empty()
	button.text = "%s\nCooldown %.1fs\n%s" % [
		skill.display_name,
		skill.cooldown_duration,
		_get_skill_requirement_text(skill, unavailable_reason)
	]
	button.tooltip_text = button.text
	button.add_theme_font_size_override("font_size", 14)
	var color := Color(0.12, 0.78, 0.95, 1.0)
	if button.disabled:
		color = Color(0.34, 0.36, 0.4, 1.0)
	UiPresentation.apply_button_style(button, color)
	button.pressed.connect(_on_skill_chosen.bind(skill))
	return button

func _get_unavailable_reason(skill: ActiveSkillDefinition) -> String:
	if _selected_skill_ids.has(skill.id):
		return "Already chosen"
	if skill.requires_weapon and active_skill_loadout.get_eligible_weapon_slots(skill).is_empty():
		return "Needs eligible weapon"
	return ""

func _get_skill_requirement_text(
	skill: ActiveSkillDefinition,
	unavailable_reason: String
) -> String:
	if not unavailable_reason.is_empty():
		return unavailable_reason
	if not skill.requires_weapon:
		return "No weapon required"
	var eligible_slots := active_skill_loadout.get_eligible_weapon_slots(skill)
	if eligible_slots.size() == 1:
		return "Uses weapon slot %d" % (eligible_slots[0] + 1)
	return "Uses %d eligible weapons" % eligible_slots.size()

func _on_skill_chosen(skill: ActiveSkillDefinition) -> void:
	if not is_instance_valid(active_skill_loadout):
		return
	if _selected_count >= ActiveSkillLoadoutComponent.SLOT_COUNT:
		return
	if not active_skill_loadout.equip_skill(_selected_count, skill):
		return
	_selected_skill_ids[skill.id] = true
	_selected_count += 1
	if (
		_selected_count >= choices_required
		or _selected_count >= ActiveSkillLoadoutComponent.SLOT_COUNT
	):
		_complete_selection()
		return
	_refresh_choices()

func _complete_selection() -> void:
	_completed = true
	_root_panel.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
