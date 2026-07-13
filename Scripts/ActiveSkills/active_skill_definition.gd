class_name ActiveSkillDefinition
extends Resource

@export var id: StringName
@export var display_name: String = "Active Skill"
@export_range(0.0, 120.0, 0.1, "or_greater") var cooldown_duration: float = 8.0

func can_activate(_loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	return _loadout.get_cooldown_remaining(slot_index) <= 0.0

func activate(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	loadout.start_cooldown(slot_index, cooldown_duration)
	return true

func tick(_loadout: ActiveSkillLoadoutComponent, _slot_index: int, _delta: float) -> void:
	pass

func cancel(_loadout: ActiveSkillLoadoutComponent, _slot_index: int) -> void:
	pass

func get_status_text(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> String:
	var cooldown := loadout.get_cooldown_remaining(slot_index)
	if cooldown > 0.0:
		return "%.1fs" % cooldown
	return "Ready"
