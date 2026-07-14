class_name DamageNumberEmitter
extends Node

@export var health_component: HealthComponent
@export var hurtbox: Hurtbox
@export var damage_number_scene: PackedScene
@export var world_offset := Vector2(0.0, -32.0)
@export var fallback_damage_color := Color(1.0, 0.9, 0.45, 1.0)

@export_category("Typed Damage")
@export var physical_color := Color(0.95, 0.95, 0.9, 1.0)
@export var elemental_color := Color("#CFA6FF")
@export var evaded_color := Color(0.72, 0.9, 1.0, 1.0)
@export var deflected_color := Color(0.72, 0.95, 0.78, 1.0)
@export_range(0.0, 1.0, 0.005) var discard_below_ratio: float = 0.02
@export_range(0.1, 1.0, 0.05) var minimum_size_multiplier: float = 0.5
@export_range(0.0, 64.0, 1.0) var number_spacing: float = 22.0

func _ready() -> void:
	if not is_instance_valid(health_component):
		health_component = _find_health_component()
	if not is_instance_valid(hurtbox):
		hurtbox = _find_hurtbox()

	if is_instance_valid(hurtbox):
		hurtbox.damage_resolved.connect(_on_damage_resolved)
	elif is_instance_valid(health_component):
		# Compatibility fallback for actors that do not receive damage through a Hurtbox.
		health_component.damaged.connect(_on_untyped_damage)
	else:
		push_warning("DamageNumberEmitter has no Hurtbox or HealthComponent.")

func _find_health_component() -> HealthComponent:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is HealthComponent:
			return sibling
	return null

func _find_hurtbox() -> Hurtbox:
	var actor := get_parent()
	if actor == null:
		return null
	for sibling in actor.get_children():
		if sibling is Hurtbox:
			return sibling
	return null

func _on_damage_resolved(
	result: DamageResult,
	applied_damage: float,
	_source: Node
) -> void:
	if result == null:
		return
	if result.was_evaded:
		_emit_text("EVADED", evaded_color, 0.9)
		return
	if result.was_deflected:
		_emit_text("DEFLECTED", deflected_color, 0.85)
	if result.total_damage <= 0.0:
		return

	var largest_amount: float = 0.0
	var typed_total: float = 0.0
	for damage_type in DamageTypeIds.ORDER:
		var type_amount := float(
			result.damage_by_type.get(damage_type, 0.0)
		)
		largest_amount = maxf(largest_amount, type_amount)
		typed_total += type_amount
	if largest_amount <= 0.0 or typed_total <= 0.0:
		return

	var displayed_damage := applied_damage + result.arcane_shield_damage
	if displayed_damage <= 0.0:
		return
	var applied_ratio := displayed_damage / typed_total
	var displays: Array[Dictionary] = []
	for damage_type in DamageTypeIds.ORDER:
		var resolved_amount := float(
			result.damage_by_type.get(damage_type, 0.0)
		)
		if resolved_amount <= 0.0:
			continue

		var relative_amount := resolved_amount / largest_amount
		if relative_amount < discard_below_ratio:
			continue

		displays.append({
			"amount": resolved_amount * applied_ratio,
			"color": _get_damage_color(damage_type),
			"size": lerpf(
				minimum_size_multiplier,
				1.0,
				sqrt(relative_amount)
			)
		})

	_emit_display_group(displays)

func _on_untyped_damage(amount: float, _source: Node) -> void:
	_emit_display_group([{
		"amount": amount,
		"color": fallback_damage_color,
		"size": 1.0
	}])

func _emit_display_group(displays: Array[Dictionary]) -> void:
	if damage_number_scene == null or displays.is_empty():
		return

	var actor := get_parent() as Node2D
	if not is_instance_valid(actor):
		return

	var group_width := number_spacing * float(displays.size() - 1)
	for index in displays.size():
		var entry := displays[index]
		var entry_color: Color = entry["color"]
		var offset := Vector2(
			float(index) * number_spacing - group_width * 0.5,
			0.0
		)
		_spawn_damage_number(
			actor.global_position + world_offset + offset,
			float(entry["amount"]),
			entry_color,
			float(entry["size"])
		)

func _spawn_damage_number(
	spawn_position: Vector2,
	amount: float,
	color: Color,
	size_multiplier: float
) -> void:
	var damage_number := _create_damage_number(spawn_position)
	if damage_number == null:
		return
	damage_number.display(amount, color, size_multiplier)

func _emit_text(text: String, color: Color, size_multiplier: float = 1.0) -> void:
	var actor := get_parent() as Node2D
	if not is_instance_valid(actor):
		return
	var damage_number := _create_damage_number(actor.global_position + world_offset)
	if damage_number == null:
		return
	damage_number.display_text(text, color, size_multiplier)

func _create_damage_number(spawn_position: Vector2) -> DamageNumber:
	if damage_number_scene == null:
		return null
	var damage_number := damage_number_scene.instantiate() as DamageNumber
	if damage_number == null:
		push_warning("Damage number scene must have a DamageNumber root.")
		return null

	var effects_parent := get_tree().get_first_node_in_group(&"effects_container")
	if effects_parent == null:
		effects_parent = get_tree().current_scene
	effects_parent.add_child(damage_number)
	damage_number.global_position = spawn_position
	return damage_number

func _get_damage_color(damage_type: StringName) -> Color:
	match damage_type:
		DamageTypeIds.PHYSICAL:
			return physical_color
		DamageTypeIds.ELEMENTAL:
			return elemental_color
	return fallback_damage_color
