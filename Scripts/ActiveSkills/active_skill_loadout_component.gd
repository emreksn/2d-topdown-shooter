class_name ActiveSkillLoadoutComponent
extends Node

signal skill_activated(slot_index: int, skill: ActiveSkillDefinition)
signal skill_failed(slot_index: int, reason: String)
signal skills_changed

const SLOT_COUNT := 2

@export var player: CharacterBody2D
@export var stat_component: StatComponent
@export var weapon_loadout: WeaponLoadoutComponent
@export var skill_slot_1: Resource
@export var skill_slot_2: Resource
@export var skills: Array[ActiveSkillDefinition] = []

var cooldowns: Array[float] = []
var active_skill_slots: Dictionary = {}
var last_move_direction := Vector2.RIGHT
var _starter_skills_resolved := false

func _ready() -> void:
	_resolve_dependencies()
	_ensure_slots()
	_resolve_starter_skills()

func _process(delta: float) -> void:
	_update_last_move_direction()
	var changed := false
	for index: int in range(cooldowns.size()):
		if cooldowns[index] > 0.0:
			cooldowns[index] = maxf(cooldowns[index] - delta, 0.0)
			changed = true

	var active_slots := active_skill_slots.keys()
	for slot_key in active_slots:
		var slot_index := int(slot_key)
		var skill := get_skill(slot_index)
		if skill != null:
			skill.tick(self, slot_index, delta)
	if changed:
		skills_changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("active_skill_1"):
		activate_slot(0)
	elif event.is_action_pressed("active_skill_2"):
		activate_slot(1)

func equip_skill(slot_index: int, skill: ActiveSkillDefinition) -> bool:
	_ensure_slots()
	_resolve_starter_skills()
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	var current := skills[slot_index]
	if current != null and active_skill_slots.has(slot_index):
		current.cancel(self, slot_index)
		active_skill_slots.erase(slot_index)
	skills[slot_index] = skill
	cooldowns[slot_index] = 0.0
	skills_changed.emit()
	return true

func activate_slot(slot_index: int) -> bool:
	_ensure_slots()
	_resolve_dependencies()
	_resolve_starter_skills()
	var skill := get_skill(slot_index)
	if skill == null:
		skill_failed.emit(slot_index, "No skill equipped.")
		return false
	if not skill.can_activate(self, slot_index):
		skill_failed.emit(slot_index, "%s is on cooldown." % skill.display_name)
		return false
	if not skill.activate(self, slot_index):
		skill_failed.emit(slot_index, "%s failed." % skill.display_name)
		return false
	skill_activated.emit(slot_index, skill)
	skills_changed.emit()
	return true

func get_skill(slot_index: int) -> ActiveSkillDefinition:
	_ensure_slots()
	_resolve_starter_skills()
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return skills[slot_index]

func start_cooldown(slot_index: int, duration: float) -> void:
	_ensure_slots()
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	cooldowns[slot_index] = maxf(duration, 0.0)
	skills_changed.emit()

func get_cooldown_remaining(slot_index: int) -> float:
	_ensure_slots()
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return 0.0
	return cooldowns[slot_index]

func mark_slot_active(slot_index: int) -> void:
	active_skill_slots[slot_index] = true
	skills_changed.emit()

func clear_slot_active(slot_index: int) -> void:
	if active_skill_slots.erase(slot_index):
		skills_changed.emit()

func is_slot_active(slot_index: int) -> bool:
	return active_skill_slots.has(slot_index)

func get_dash_direction() -> Vector2:
	_update_last_move_direction()
	return last_move_direction

func get_equipped_weapons() -> Array[Weapon]:
	_resolve_dependencies()
	var result: Array[Weapon] = []
	if not is_instance_valid(weapon_loadout):
		return result
	for index: int in range(WeaponLoadoutComponent.SLOT_COUNT):
		var weapon := weapon_loadout.get_weapon(index)
		if is_instance_valid(weapon):
			result.append(weapon)
	return result

func _resolve_dependencies() -> void:
	if not is_instance_valid(player):
		player = get_parent() as CharacterBody2D
	if is_instance_valid(player):
		if not is_instance_valid(stat_component):
			stat_component = player.get_node_or_null("StatComponent") as StatComponent
		if not is_instance_valid(weapon_loadout):
			weapon_loadout = player.get_node_or_null(
				"WeaponLoadoutComponent"
			) as WeaponLoadoutComponent

func _update_last_move_direction() -> void:
	var input_direction := Vector2(
		int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")),
		int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	).normalized()
	if not input_direction.is_zero_approx():
		last_move_direction = input_direction

func _ensure_slots() -> void:
	while skills.size() < SLOT_COUNT:
		skills.append(null)
	while cooldowns.size() < SLOT_COUNT:
		cooldowns.append(0.0)

func _resolve_starter_skills() -> void:
	if _starter_skills_resolved:
		return
	if skills[0] == null:
		skills[0] = skill_slot_1 as ActiveSkillDefinition
	if skills[1] == null:
		skills[1] = skill_slot_2 as ActiveSkillDefinition
	_starter_skills_resolved = true
