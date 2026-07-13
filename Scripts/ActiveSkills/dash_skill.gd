class_name DashSkill
extends ActiveSkillDefinition

@export_range(1.0, 1000.0, 1.0, "or_greater") var dash_distance: float = 220.0
@export_range(0.01, 1.0, 0.01, "or_greater") var dash_duration: float = 0.16

func activate(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	if not super.activate(loadout, slot_index):
		return false
	if not is_instance_valid(loadout.player):
		return false
	var direction := loadout.get_dash_direction()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	if not loadout.player.has_method("start_dash"):
		return false
	loadout.player.start_dash(direction, dash_distance, dash_duration)
	return true
