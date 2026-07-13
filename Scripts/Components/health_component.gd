class_name HealthComponent
extends Node

signal health_changed(current_health: float, maximum_health: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died(source: Node)

@export var stat_component: StatComponent
@export_range(0.0, 1000000.0, 1.0, "or_greater") var fallback_maximum_health: float = 100.0

var current_health: float
var is_dead: bool = false
var maximum_health: float:
	get:
		return (
			stat_component.get_stat(StatIds.MAXIMUM_HEALTH)
			if is_instance_valid(stat_component)
			else fallback_maximum_health
		)

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
	health_changed.emit(current_health, maximum_health)

func _find_stat_component() -> StatComponent:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is StatComponent:
			return sibling
	return null

func _on_stat_changed(stat_id: StringName) -> void:
	if stat_id != StatIds.MAXIMUM_HEALTH:
		return
	current_health = minf(current_health, maximum_health)
	health_changed.emit(current_health, maximum_health)
