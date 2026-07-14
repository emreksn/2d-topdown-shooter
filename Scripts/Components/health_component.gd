class_name HealthComponent
extends Node

signal health_changed(current_health: float, maximum_health: float)
signal arcane_shield_changed(
	current_arcane_shield: float,
	maximum_arcane_shield: float
)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died(source: Node)

const BASE_ARCANE_SHIELD_RECHARGE_DELAY := 3.0

@export var stat_component: StatComponent
@export_range(0.0, 1000000.0, 1.0, "or_greater") var fallback_maximum_health: float = 100.0

var current_health: float
var current_arcane_shield: float = 0.0
var is_dead: bool = false
var _last_maximum_health: float = 0.0
var _last_maximum_arcane_shield: float = 0.0
var _arcane_shield_recharge_start_delay_remaining: float = 0.0
var maximum_health: float:
	get:
		if not is_instance_valid(stat_component):
			stat_component = _find_stat_component()
		return (
			stat_component.get_stat(StatIds.MAXIMUM_HEALTH)
			if is_instance_valid(stat_component)
			else fallback_maximum_health
		)
var maximum_arcane_shield: float:
	get:
		if not is_instance_valid(stat_component):
			stat_component = _find_stat_component()
		return (
			stat_component.get_stat(StatIds.MAXIMUM_ARCANE_SHIELD)
			if is_instance_valid(stat_component)
			else 0.0
		)

func _process(delta: float) -> void:
	if is_dead or current_arcane_shield >= maximum_arcane_shield:
		return
	if _arcane_shield_recharge_start_delay_remaining > 0.0:
		_arcane_shield_recharge_start_delay_remaining = maxf(
			_arcane_shield_recharge_start_delay_remaining - delta,
			0.0
		)
		return
	_recharge_arcane_shield(delta)

func _ready() -> void:
	if not is_instance_valid(stat_component):
		stat_component = _find_stat_component()
	if is_instance_valid(stat_component):
		stat_component.stat_changed.connect(_on_stat_changed)
	reset()

func take_damage(amount: float, source: Node = null) -> float:
	if is_dead or amount <= 0.0:
		return 0.0

	var previous_health := current_health
	current_health = maxf(current_health - amount, 0.0)
	var applied_damage := previous_health - current_health

	damaged.emit(applied_damage, source)
	health_changed.emit(current_health, maximum_health)

	if current_health <= 0.0:
		is_dead = true
		died.emit(source)

	return applied_damage

func take_resolved_damage(result: DamageResult, source: Node = null) -> float:
	if result == null or is_dead:
		return 0.0
	var elemental_damage := float(
		result.damage_by_type.get(DamageTypeIds.ELEMENTAL, 0.0)
	)
	var arcane_absorb := _absorb_arcane_shield(elemental_damage)
	result.arcane_shield_damage = arcane_absorb
	result.life_damage = maxf(result.life_damage - arcane_absorb, 0.0)
	result.total_damage = result.life_damage + result.arcane_shield_damage
	if result.life_damage <= 0.0:
		return 0.0
	return take_damage(result.life_damage, source)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	var previous_health := current_health
	current_health = minf(current_health + amount, maximum_health)
	var applied_healing := current_health - previous_health

	if applied_healing > 0.0:
		healed.emit(applied_healing)
		health_changed.emit(current_health, maximum_health)

func reset() -> void:
	is_dead = false
	current_health = maximum_health
	_last_maximum_health = maximum_health
	current_arcane_shield = maximum_arcane_shield
	_last_maximum_arcane_shield = maximum_arcane_shield
	_arcane_shield_recharge_start_delay_remaining = 0.0
	health_changed.emit(current_health, maximum_health)
	arcane_shield_changed.emit(current_arcane_shield, maximum_arcane_shield)

func _find_stat_component() -> StatComponent:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is StatComponent:
			return sibling
	return null

func _on_stat_changed(stat_id: StringName) -> void:
	if stat_id == StatIds.MAXIMUM_HEALTH:
		_update_maximum_health()
	elif stat_id == StatIds.MAXIMUM_ARCANE_SHIELD:
		_update_maximum_arcane_shield()

func _update_maximum_health() -> void:
	var previous_maximum := _last_maximum_health
	var resolved_maximum := maximum_health
	var was_full := (
		previous_maximum <= 0.0
		or current_health >= previous_maximum - 0.001
	)
	current_health = resolved_maximum if was_full else minf(current_health, resolved_maximum)
	_last_maximum_health = resolved_maximum
	health_changed.emit(current_health, resolved_maximum)

func _update_maximum_arcane_shield() -> void:
	var previous_maximum := _last_maximum_arcane_shield
	var resolved_maximum := maximum_arcane_shield
	var was_full := (
		previous_maximum <= 0.0
		or current_arcane_shield >= previous_maximum - 0.001
	)
	current_arcane_shield = (
		resolved_maximum
		if was_full
		else minf(current_arcane_shield, resolved_maximum)
	)
	_last_maximum_arcane_shield = resolved_maximum
	arcane_shield_changed.emit(current_arcane_shield, resolved_maximum)

func _absorb_arcane_shield(elemental_damage: float) -> float:
	if elemental_damage <= 0.0 or current_arcane_shield <= 0.0:
		return 0.0
	var absorbed := minf(current_arcane_shield, elemental_damage)
	current_arcane_shield -= absorbed
	_arcane_shield_recharge_start_delay_remaining = _get_arcane_shield_recharge_start_delay()
	arcane_shield_changed.emit(current_arcane_shield, maximum_arcane_shield)
	return absorbed

func _recharge_arcane_shield(delta: float) -> void:
	var maximum := maximum_arcane_shield
	if maximum <= 0.0:
		return
	var recharge_rate := _get_arcane_shield_recharge_rate()
	if recharge_rate <= 0.0:
		return
	var previous_shield := current_arcane_shield
	current_arcane_shield = minf(
		current_arcane_shield + maximum * recharge_rate / 100.0 * delta,
		maximum
	)
	if current_arcane_shield > previous_shield:
		arcane_shield_changed.emit(current_arcane_shield, maximum)

func _get_arcane_shield_recharge_start_delay() -> float:
	var start_speed := (
		stat_component.get_stat(StatIds.ARCANE_SHIELD_RECHARGE_START_SPEED)
		if is_instance_valid(stat_component)
		else 0.0
	)
	return BASE_ARCANE_SHIELD_RECHARGE_DELAY / (1.0 + maxf(start_speed, 0.0) / 100.0)

func _get_arcane_shield_recharge_rate() -> float:
	return (
		stat_component.get_stat(StatIds.ARCANE_SHIELD_RECHARGE_RATE)
		if is_instance_valid(stat_component)
		else 25.0
	)
