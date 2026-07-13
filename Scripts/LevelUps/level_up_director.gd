class_name LevelUpDirector
extends Node

signal choices_changed(options: Array[LevelUpOption], pending_count: int)
signal sequence_started(pending_count: int)
signal sequence_completed
signal option_selected(option: LevelUpOption)

@export var progression: PlayerProgressionComponent
@export var player_stats: StatComponent
@export_range(1, 6, 1) var offer_count: int = 3

var current_options: Array[LevelUpOption] = []

var _random := RandomNumberGenerator.new()
var _sequence_active := false
var _applied_count := 0
var _option_pool: Array[LevelUpOption] = []

func _ready() -> void:
	_random.randomize()
	add_to_group(&"level_up_director")
	_resolve_dependencies()
	_build_option_pool()

func has_pending_level_ups() -> bool:
	return (
		is_instance_valid(progression)
		and progression.has_pending_level_ups()
	)

func begin_sequence() -> bool:
	if not has_pending_level_ups():
		return false
	_sequence_active = true
	sequence_started.emit(progression.pending_level_ups)
	_roll_options()
	return true

func choose_option(index: int) -> bool:
	if not _sequence_active:
		return false
	if index < 0 or index >= current_options.size():
		return false
	if not is_instance_valid(progression):
		return false

	var option := current_options[index]
	if option == null:
		return false
	if not progression.consume_pending_level_up():
		_complete_sequence()
		return false

	_apply_option(option)
	option_selected.emit(option)
	if progression.has_pending_level_ups():
		_roll_options()
	else:
		_complete_sequence()
	return true

func _resolve_dependencies() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player == null:
		return
	if not is_instance_valid(progression):
		progression = player.get_node_or_null(
			"PlayerProgressionComponent"
		) as PlayerProgressionComponent
	if not is_instance_valid(player_stats):
		player_stats = player.get_node_or_null("StatComponent") as StatComponent

func _roll_options() -> void:
	current_options.clear()
	var used_keys: Dictionary = {}
	var attempts := 0
	while current_options.size() < offer_count and attempts < 80:
		attempts += 1
		var rarity := _roll_rarity()
		var option := _choose_option_for_rarity(rarity, used_keys)
		if option == null:
			option = _choose_any_option(used_keys)
		if option == null:
			break
		current_options.append(option)
		used_keys[_get_option_key(option)] = true
	choices_changed.emit(current_options, progression.pending_level_ups)

func _roll_rarity() -> ItemDefinition.Rarity:
	var roll := _random.randf() * 100.0
	if roll < 64.0:
		return ItemDefinition.Rarity.COMMON
	if roll < 88.0:
		return ItemDefinition.Rarity.UNCOMMON
	if roll < 98.0:
		return ItemDefinition.Rarity.RARE
	return ItemDefinition.Rarity.LEGENDARY

func _choose_option_for_rarity(
	rarity: ItemDefinition.Rarity,
	used_keys: Dictionary
) -> LevelUpOption:
	var candidates: Array[LevelUpOption] = []
	for option in _option_pool:
		if option.rarity == rarity and not used_keys.has(_get_option_key(option)):
			candidates.append(option)
	if candidates.is_empty():
		return null
	return candidates[_random.randi_range(0, candidates.size() - 1)]

func _choose_any_option(used_keys: Dictionary) -> LevelUpOption:
	var candidates: Array[LevelUpOption] = []
	for option in _option_pool:
		if not used_keys.has(_get_option_key(option)):
			candidates.append(option)
	if candidates.is_empty():
		return null
	return candidates[_random.randi_range(0, candidates.size() - 1)]

func _apply_option(option: LevelUpOption) -> void:
	var modifier_set := option.create_modifier_set()
	var source_id := StringName("level_up:%d" % _applied_count)
	_applied_count += 1
	if is_instance_valid(player_stats):
		player_stats.add_modifier_source(source_id, modifier_set)
	for weapon_stats in _get_weapon_stat_components():
		weapon_stats.add_modifier_source(source_id, modifier_set)

func _get_weapon_stat_components() -> Array[StatComponent]:
	var result: Array[StatComponent] = []
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player == null:
		return result
	var weapon_mount := player.get_node_or_null("WeaponMount")
	if weapon_mount == null:
		return result
	for weapon in weapon_mount.get_children():
		for child in weapon.get_children():
			if child is StatComponent:
				result.append(child)
	return result

func _complete_sequence() -> void:
	_sequence_active = false
	current_options.clear()
	sequence_completed.emit()

func _get_option_key(option: LevelUpOption) -> String:
	if option == null or option.modifier == null:
		return ""
	return "%d:%s:%d" % [
		option.rarity,
		String(option.modifier.stat_id),
		option.modifier.operation
	]

func _build_option_pool() -> void:
	_option_pool = [
		_make_option("Health", ItemDefinition.Rarity.COMMON, StatIds.MAXIMUM_HEALTH, StatModifier.Operation.FLAT, 5.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Damage", ItemDefinition.Rarity.COMMON, StatIds.DAMAGE, StatModifier.Operation.INCREASED, 5.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Attack Rate", ItemDefinition.Rarity.COMMON, StatIds.ATTACK_RATE, StatModifier.Operation.INCREASED, 10.0, &"weapon", StatModifier.Scope.LOCAL),

		_make_option("Health", ItemDefinition.Rarity.UNCOMMON, StatIds.MAXIMUM_HEALTH, StatModifier.Operation.FLAT, 10.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Damage", ItemDefinition.Rarity.UNCOMMON, StatIds.DAMAGE, StatModifier.Operation.INCREASED, 10.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Attack Rate", ItemDefinition.Rarity.UNCOMMON, StatIds.ATTACK_RATE, StatModifier.Operation.INCREASED, 20.0, &"weapon", StatModifier.Scope.LOCAL),
		_make_option("Movement Speed", ItemDefinition.Rarity.UNCOMMON, StatIds.MOVEMENT_SPEED, StatModifier.Operation.INCREASED, 5.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Item Rarity", ItemDefinition.Rarity.UNCOMMON, StatIds.ITEM_RARITY_MULTIPLIER, StatModifier.Operation.INCREASED, 8.0, &"player", StatModifier.Scope.GLOBAL),

		_make_option("Health", ItemDefinition.Rarity.RARE, StatIds.MAXIMUM_HEALTH, StatModifier.Operation.FLAT, 20.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Damage", ItemDefinition.Rarity.RARE, StatIds.DAMAGE, StatModifier.Operation.INCREASED, 18.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Attack Rate", ItemDefinition.Rarity.RARE, StatIds.ATTACK_RATE, StatModifier.Operation.INCREASED, 35.0, &"weapon", StatModifier.Scope.LOCAL),
		_make_option("Movement Speed", ItemDefinition.Rarity.RARE, StatIds.MOVEMENT_SPEED, StatModifier.Operation.INCREASED, 10.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Item Rarity", ItemDefinition.Rarity.RARE, StatIds.ITEM_RARITY_MULTIPLIER, StatModifier.Operation.INCREASED, 15.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Experience Gain", ItemDefinition.Rarity.RARE, StatIds.EXPERIENCE_GAIN_MULTIPLIER, StatModifier.Operation.INCREASED, 15.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Gold Granted", ItemDefinition.Rarity.RARE, StatIds.GOLD_GRANTED_MULTIPLIER, StatModifier.Operation.INCREASED, 15.0, &"player", StatModifier.Scope.GLOBAL),

		_make_option("Health", ItemDefinition.Rarity.LEGENDARY, StatIds.MAXIMUM_HEALTH, StatModifier.Operation.FLAT, 35.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Damage", ItemDefinition.Rarity.LEGENDARY, StatIds.DAMAGE, StatModifier.Operation.INCREASED, 30.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Attack Rate", ItemDefinition.Rarity.LEGENDARY, StatIds.ATTACK_RATE, StatModifier.Operation.INCREASED, 60.0, &"weapon", StatModifier.Scope.LOCAL),
		_make_option("Movement Speed", ItemDefinition.Rarity.LEGENDARY, StatIds.MOVEMENT_SPEED, StatModifier.Operation.INCREASED, 18.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Item Rarity", ItemDefinition.Rarity.LEGENDARY, StatIds.ITEM_RARITY_MULTIPLIER, StatModifier.Operation.INCREASED, 25.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Experience Gain", ItemDefinition.Rarity.LEGENDARY, StatIds.EXPERIENCE_GAIN_MULTIPLIER, StatModifier.Operation.INCREASED, 25.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Gold Granted", ItemDefinition.Rarity.LEGENDARY, StatIds.GOLD_GRANTED_MULTIPLIER, StatModifier.Operation.INCREASED, 25.0, &"player", StatModifier.Scope.GLOBAL),
		_make_option("Free Reroll Chance", ItemDefinition.Rarity.LEGENDARY, StatIds.SHOP_FREE_REROLL_CHANCE, StatModifier.Operation.FLAT, 15.0, &"player", StatModifier.Scope.GLOBAL)
	]

func _make_option(
	display_name: String,
	rarity: ItemDefinition.Rarity,
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float,
	target_domain: StringName,
	scope: int
) -> LevelUpOption:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = scope
	modifier.target_domain = target_domain

	var option := LevelUpOption.new()
	option.display_name = display_name
	option.rarity = rarity
	option.modifier = modifier
	return option
