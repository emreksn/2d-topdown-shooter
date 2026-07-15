class_name StatusEffectComponent
extends Node

signal slow_changed(magnitude: float, remaining: float)

const SLOW_SOURCE_ID := &"status:slow"
const MAXIMUM_SLOW_MAGNITUDE := 70.0
const MAXIMUM_ACTION_SLOW := 40.0

@export var stat_component: StatComponent

var _slow_magnitude: float = 0.0
var _slow_remaining: float = 0.0

func _ready() -> void:
	if not is_instance_valid(stat_component):
		stat_component = _find_stat_component()

func _process(delta: float) -> void:
	if _slow_remaining <= 0.0:
		return
	_slow_remaining = maxf(_slow_remaining - delta, 0.0)
	if _slow_remaining <= 0.0:
		_clear_slow()

func apply_slow(magnitude: float, duration: float) -> void:
	if magnitude <= 0.0 or duration <= 0.0:
		return
	_slow_magnitude = maxf(
		_slow_magnitude,
		clampf(magnitude, 0.0, MAXIMUM_SLOW_MAGNITUDE)
	)
	_slow_remaining = maxf(_slow_remaining, duration)
	_refresh_slow_modifier()
	slow_changed.emit(get_slow_magnitude(), _slow_remaining)

func get_slow_magnitude() -> float:
	return _slow_magnitude if _slow_remaining > 0.0 else 0.0

func get_action_speed_multiplier() -> float:
	var action_slow := _get_action_slow(get_slow_magnitude())
	return maxf(0.0, 1.0 - action_slow / 100.0)

func reset_for_pool_spawn() -> void:
	_clear_slow()
	set_process(true)

func _refresh_slow_modifier() -> void:
	if not is_instance_valid(stat_component):
		stat_component = _find_stat_component()
	if not is_instance_valid(stat_component):
		return
	var modifier := StatModifier.new()
	modifier.stat_id = StatIds.MOVEMENT_SPEED
	modifier.operation = StatModifier.Operation.MORE
	modifier.value = -_slow_magnitude
	modifier.scope = StatModifier.Scope.GLOBAL
	modifier.target_domain = &"monster"

	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = [modifier]
	stat_component.add_modifier_source(SLOW_SOURCE_ID, modifier_set)

func _clear_slow() -> void:
	_slow_magnitude = 0.0
	_slow_remaining = 0.0
	if is_instance_valid(stat_component):
		stat_component.remove_modifier_source(SLOW_SOURCE_ID)
	slow_changed.emit(0.0, 0.0)

func _get_action_slow(magnitude: float) -> float:
	if magnitude >= 50.0:
		return minf(30.0, MAXIMUM_ACTION_SLOW)
	if magnitude >= 25.0:
		return minf(15.0, MAXIMUM_ACTION_SLOW)
	return 0.0

func _find_stat_component() -> StatComponent:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is StatComponent:
			return sibling
	return null
