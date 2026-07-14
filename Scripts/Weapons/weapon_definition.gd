class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String = "Weapon"
@export var tags: Array[StringName] = []
@export var weapon_scene: PackedScene
@export_range(1, 1000000, 1, "or_greater") var base_cost: int = 20
@export var implicit_modifier_set: ModifierSet
