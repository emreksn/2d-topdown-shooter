class_name ProjectileWeapon
extends Weapon

@export var projectile_scene: PackedScene
@export_range(0.0, 1000000.0, 1.0, "or_greater") var damage: float = 25.0
@export_range(1, 32, 1) var pellet_count: int = 1
@export_range(0.0, 120.0, 1.0) var spread_degrees: float = 0.0
@export_range(0.0, 120.0, 1.0) var spread_randomness_degrees: float = 0.0
@export var conversions: Array[DamageConversion] = []

@onready var projectile_origin: Marker2D = $ProjectileOrigin

var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	super._ready()

func perform_basic_attack(target_node: Node2D) -> void:
	if projectile_scene == null or not is_instance_valid(target_node):
		return

	var projectile_parent := get_tree().get_first_node_in_group(&"projectiles_container")
	if projectile_parent == null:
		projectile_parent = get_tree().current_scene

	var attack_tags := get_attack_tags()
	var packet := DamageResolver.build_outgoing_packet(
		stat_component,
		actor_stat_component,
		conversions,
		attack_tags,
		_get_actor_source()
	)
	if packet.slices.is_empty():
		packet.slices = [DamageSlice.new(damage, DamageTypeIds.PHYSICAL)]

	var projectile_speed := stat_component.get_stat(
		StatIds.PROJECTILE_SPEED,
		attack_tags,
		StatModifier.Scope.LOCAL
	)
	var base_direction := projectile_origin.global_position.direction_to(
		target_node.global_position
	)
	var clamped_pellet_count: int = maxi(pellet_count, 1)
	var spread_radians := deg_to_rad(spread_degrees)
	for pellet_index: int in range(clamped_pellet_count):
		var projectile := projectile_scene.instantiate() as Projectile
		if projectile == null:
			push_warning("Projectile weapon scene must have a Projectile root.")
			return
		projectile_parent.add_child(projectile)
		projectile.global_position = projectile_origin.global_position
		var t := (
			0.5
			if clamped_pellet_count == 1
			else float(pellet_index) / float(clamped_pellet_count - 1)
		)
		var angle_offset := lerpf(
			-spread_radians * 0.5,
			spread_radians * 0.5,
			t
		)
		if spread_randomness_degrees > 0.0:
			angle_offset += deg_to_rad(
				_random.randf_range(
					-spread_randomness_degrees,
					spread_randomness_degrees
				)
			)
		projectile.setup(
			base_direction.rotated(angle_offset),
			_clone_damage_packet(packet),
			projectile_speed
		)

func _clone_damage_packet(packet: DamagePacket) -> DamagePacket:
	var clone := DamagePacket.new()
	clone.source = packet.source
	clone.tags = packet.tags.duplicate()
	for slice in packet.slices:
		clone.slices.append(
			DamageSlice.new(
				slice.amount,
				slice.current_type,
				slice.ancestry_types
			)
		)
	return clone

func _get_actor_source() -> Node:
	var mount := get_parent()
	return mount.get_parent() if mount != null else null
