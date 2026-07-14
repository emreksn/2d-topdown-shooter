class_name DamageResult
extends RefCounted

var total_damage: float = 0.0
var damage_by_type: Dictionary = {}
var life_damage: float = 0.0
var arcane_shield_damage: float = 0.0
var was_evaded: bool = false
var was_deflected: bool = false
var evade_chance: float = 0.0
var deflect_chance: float = 0.0
var armour_reduction: float = 0.0
