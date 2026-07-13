class_name BulletstormVolleySkill
extends ActiveSkillDefinition

const PLAYER_SOURCE_ID := &"active_skill:bulletstorm_volley:player"

@export_range(0.1, 30.0, 0.1, "or_greater") var duration: float = 4.0
@export_range(0.0, 5000.0, 1.0, "or_greater") var attack_rate_more: float = 500.0
@export_range(0.0, 100.0, 1.0) var damage_less: float = 25.0
@export_range(0, 64, 1) var sector_count: int = 12
@export_range(0.0, 1.0, 0.01) var sector_target_chance: float = 0.5
@export var debug_prints: bool = true

var _remaining_by_slot: Dictionary = {}

func activate(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	if not super.activate(loadout, slot_index):
		return false
	_remaining_by_slot[slot_index] = duration
	loadout.mark_slot_active(slot_index)
	_apply_player_buff(loadout)
	_apply_weapon_buff(loadout)
	return true

func tick(loadout: ActiveSkillLoadoutComponent, slot_index: int, delta: float) -> void:
	if not _remaining_by_slot.has(slot_index):
		return
	var remaining := maxf(float(_remaining_by_slot[slot_index]) - delta, 0.0)
	_remaining_by_slot[slot_index] = remaining
	if remaining <= 0.0:
		cancel(loadout, slot_index)

func cancel(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> void:
	_remaining_by_slot.erase(slot_index)
	loadout.clear_slot_active(slot_index)
	if is_instance_valid(loadout.stat_component):
		loadout.stat_component.remove_modifier_source(PLAYER_SOURCE_ID)
	for weapon in loadout.get_equipped_weapons():
		var projectile_weapon := weapon as ProjectileWeapon
		weapon.active_skill_sector_targeting = false
		weapon.active_skill_sector_bag.clear()
		weapon.active_skill_debug_prints = false
		weapon.active_skill_forced_attack_direction = Vector2.ZERO
		weapon.active_skill_use_actor_attack_rate = false
		weapon.active_skill_last_projectile_debug_label = ""
		if projectile_weapon != null:
			projectile_weapon.active_skill_aim_jitter_degrees = 0.0
			projectile_weapon.active_skill_force_single_projectile = false

func get_status_text(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> String:
	if _remaining_by_slot.has(slot_index):
		return "Channel %.1fs" % float(_remaining_by_slot[slot_index])
	return super.get_status_text(loadout, slot_index)

func _apply_player_buff(loadout: ActiveSkillLoadoutComponent) -> void:
	if not is_instance_valid(loadout.stat_component):
		return
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [
		_make_modifier(
			StatIds.DAMAGE,
			StatModifier.Operation.MORE,
			-damage_less,
			StatModifier.Scope.GLOBAL,
			&"player"
		),
		_make_modifier(
			StatIds.ATTACK_RATE,
			StatModifier.Operation.MORE,
			attack_rate_more,
			StatModifier.Scope.GLOBAL,
			&"player"
		)
	]
	loadout.stat_component.add_modifier_source(PLAYER_SOURCE_ID, modifier_set)

func _apply_weapon_buff(loadout: ActiveSkillLoadoutComponent) -> void:
	for weapon in loadout.get_equipped_weapons():
		weapon.active_skill_random_targeting = false
		weapon.active_skill_sector_targeting = true
		weapon.active_skill_use_actor_attack_rate = true
		weapon.active_skill_sector_count = sector_count
		weapon.active_skill_sector_index = 0
		weapon.active_skill_sector_bag.clear()
		weapon.active_skill_sector_target_chance = sector_target_chance
		weapon.active_skill_debug_prints = debug_prints
		weapon.active_skill_forced_attack_direction = Vector2.ZERO
		weapon.active_skill_last_projectile_debug_label = ""
		var projectile_weapon := weapon as ProjectileWeapon
		if projectile_weapon != null:
			projectile_weapon.active_skill_aim_jitter_degrees = 0.0
			projectile_weapon.active_skill_force_single_projectile = true

func _make_modifier(
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float,
	scope: int,
	target_domain: StringName
) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = scope
	modifier.target_domain = target_domain
	return modifier
