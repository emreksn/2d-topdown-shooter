class_name ActiveSkillDefinition
extends Resource

@export var id: StringName
@export var display_name: String = "Active Skill"
@export_range(0.0, 120.0, 0.1, "or_greater") var cooldown_duration: float = 8.0
@export var requires_weapon: bool = false
@export var required_weapon_tags: Array[StringName] = []
@export var required_damage_types: Array[StringName] = []

func can_activate(_loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	return (
		_loadout.get_cooldown_remaining(slot_index) <= 0.0
		and are_requirements_met(_loadout, slot_index)
	)

func activate(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	loadout.start_cooldown(slot_index, _resolve_cooldown_duration(loadout))
	return true

func tick(_loadout: ActiveSkillLoadoutComponent, _slot_index: int, _delta: float) -> void:
	pass

func cancel(_loadout: ActiveSkillLoadoutComponent, _slot_index: int) -> void:
	pass

func get_status_text(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> String:
	var cooldown := loadout.get_cooldown_remaining(slot_index)
	if cooldown > 0.0:
		return "%.1fs" % cooldown
	if not are_requirements_met(loadout, slot_index):
		return "No eligible weapon"
	return "Ready"

func are_requirements_met(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	if not requires_weapon:
		return true
	return loadout.get_bound_weapon(slot_index) != null

func is_weapon_eligible(weapon: Weapon) -> bool:
	if not is_instance_valid(weapon):
		return false
	for tag in required_weapon_tags:
		if not weapon.has_weapon_tag(tag):
			return false
	if required_damage_types.is_empty():
		return true
	for damage_type in required_damage_types:
		if _weapon_supports_damage_type(weapon, damage_type):
			return true
	return false

func _weapon_supports_damage_type(weapon: Weapon, damage_type: StringName) -> bool:
	if weapon.has_weapon_tag(damage_type):
		return true
	var projectile_weapon := weapon as ProjectileWeapon
	if projectile_weapon != null:
		return (
			projectile_weapon.allowed_base_damage_types != null
			and projectile_weapon.allowed_base_damage_types.has(damage_type)
		)
	if is_instance_valid(weapon.stat_component):
		var stat_id := DamageTypeIds.get_damage_stat_id(damage_type)
		return stat_id != &"" and weapon.stat_component.get_stat(stat_id) > 0.0
	return false

func _resolve_cooldown_duration(loadout: ActiveSkillLoadoutComponent) -> float:
	if cooldown_duration <= 0.0 or not is_instance_valid(loadout.stat_component):
		return cooldown_duration
	var tags: Array[StringName] = [&"active_skill"]
	if id != &"":
		tags.append(id)
	var increased: float = 0.0
	var more_multiplier: float = 1.0
	for modifier in loadout.stat_component.get_applicable_modifiers(
		[StatIds.COOLDOWN_DURATION],
		tags,
		StatModifier.Scope.GLOBAL
	):
		match modifier.operation:
			StatModifier.Operation.INCREASED:
				increased += modifier.value
			StatModifier.Operation.MORE:
				more_multiplier *= maxf(0.0, 1.0 + modifier.value / 100.0)
	return maxf(cooldown_duration * (1.0 + increased / 100.0) * more_multiplier, 0.0)
