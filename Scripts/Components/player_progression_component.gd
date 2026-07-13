class_name PlayerProgressionComponent
extends Node

signal gold_changed(total_gold: int)
signal experience_changed(
	current_experience: float,
	experience_to_next_level: float,
	level: int
)
signal level_gained(new_level: int)

@export_range(1.0, 1000000.0, 1.0) var base_experience_to_level: float = 100.0
@export_range(1.0, 5.0, 0.05) var level_experience_exponent: float = 1.25

var gold: int = 0
var experience: float = 0.0
var level: int = 1
var pending_level_ups: int = 0

var experience_to_next_level: float:
	get:
		return base_experience_to_level * pow(float(level), level_experience_exponent)

func _ready() -> void:
	gold_changed.emit(gold)
	experience_changed.emit(experience, experience_to_next_level, level)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func add_experience(amount: float) -> void:
	if amount <= 0.0:
		return
	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		pending_level_ups += 1
		level_gained.emit(level)
	experience_changed.emit(experience, experience_to_next_level, level)

func has_pending_level_ups() -> bool:
	return pending_level_ups > 0

func consume_pending_level_up() -> bool:
	if pending_level_ups <= 0:
		return false
	pending_level_ups -= 1
	return true
