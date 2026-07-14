class_name Hurtbox
extends Area2D

signal damage_received(amount: float, source: Node)
signal damage_resolved(
	result: DamageResult,
	applied_damage: float,
	source: Node
)
signal invulnerability_started(duration: float)
signal invulnerability_ended

@export var health_component: HealthComponent
@export var stat_component: StatComponent
@export var invulnerable: bool = false
@export_range(0.0, 10.0, 0.05, "or_greater") var invulnerability_duration: float = 0.0

var _invulnerability_remaining: float = 0.0

func _physics_process(delta: float) -> void:
	if _invulnerability_remaining <= 0.0:
		return

	_invulnerability_remaining = maxf(_invulnerability_remaining - delta, 0.0)
	if _invulnerability_remaining <= 0.0:
		invulnerability_ended.emit()

func _ready() -> void:
	var actor := get_parent()
	if actor == null:
		return

	for sibling in actor.get_children():
		if not is_instance_valid(health_component) and sibling is HealthComponent:
			health_component = sibling
		elif not is_instance_valid(stat_component) and sibling is StatComponent:
			stat_component = sibling

func receive_hit(amount: float, source: Node = null) -> float:
	var packet := DamagePacket.new()
	packet.source = source
	packet.tags = [&"hit"]
	packet.slices = [DamageSlice.new(amount, DamageTypeIds.PHYSICAL)]
	return receive_damage(packet)

func receive_damage(packet: DamagePacket) -> float:
	if is_invulnerable() or packet == null or packet.get_total_damage() <= 0.0:
		return 0.0
	if not is_instance_valid(health_component):
		push_warning("Hurtbox has no HealthComponent assigned.")
		return 0.0

	var result := DamageResolver.resolve_incoming(packet, stat_component)
	if result.was_evaded:
		damage_resolved.emit(result, 0.0, packet.source)
		return 0.0
	if result.total_damage <= 0.0:
		return 0.0
	var applied_damage := health_component.take_resolved_damage(result, packet.source)
	if applied_damage <= 0.0 and result.arcane_shield_damage <= 0.0:
		return 0.0

	if applied_damage > 0.0:
		damage_received.emit(applied_damage, packet.source)
	damage_resolved.emit(result, applied_damage, packet.source)
	if invulnerability_duration > 0.0 and not health_component.is_dead:
		_invulnerability_remaining = invulnerability_duration
		invulnerability_started.emit(invulnerability_duration)

	return applied_damage + result.arcane_shield_damage

func is_invulnerable() -> bool:
	return invulnerable or _invulnerability_remaining > 0.0
