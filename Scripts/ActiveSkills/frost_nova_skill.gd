class_name FrostNovaSkill
extends ActiveSkillDefinition

const FROST_NOVA_EFFECT_SCENE := preload("res://Scenes/Feedback/frost_nova_effect.tscn")

@export_range(0.0, 1000000.0, 1.0, "or_greater") var base_damage: float = 18.0
@export_range(0.0, 10.0, 0.05, "or_greater") var elemental_damage_scaling: float = 0.5
@export_range(0.0, 2000.0, 8.0, "or_greater") var radius: float = 260.0
@export_range(0.0, 100.0, 1.0) var slow_magnitude: float = 25.0
@export_range(0.0, 20.0, 0.1, "or_greater") var slow_duration: float = 2.5

func activate(loadout: ActiveSkillLoadoutComponent, slot_index: int) -> bool:
	if not super.activate(loadout, slot_index):
		return false
	if not is_instance_valid(loadout.player):
		return false
	var weapon := loadout.get_bound_weapon(slot_index)
	if not is_instance_valid(weapon):
		return false

	var tags := _get_skill_tags(weapon)
	var packet := _build_damage_packet(loadout, weapon, tags)
	var origin := loadout.player.global_position
	var resolved_radius := _resolve_bound_weapon_scaled_value(
		radius,
		weapon,
		StatIds.AREA_OF_EFFECT,
		tags
	)
	_spawn_visual(loadout, origin, resolved_radius)
	var radius_squared := resolved_radius * resolved_radius
	for candidate_node in loadout.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := candidate_node as Node2D
		if (
			not is_instance_valid(enemy)
			or origin.distance_squared_to(enemy.global_position) > radius_squared
		):
			continue
		var hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
		if hurtbox != null:
			hurtbox.receive_damage(packet)
		var status := enemy.get_node_or_null(
			"StatusEffectComponent"
		) as StatusEffectComponent
		if status != null:
			status.apply_slow(slow_magnitude, slow_duration)
	return true

func _spawn_visual(
	loadout: ActiveSkillLoadoutComponent,
	origin: Vector2,
	resolved_radius: float
) -> void:
	var tree := loadout.get_tree()
	if tree == null:
		return
	var parent := tree.get_first_node_in_group(&"effects_container")
	if parent == null:
		parent = tree.current_scene
	if parent == null:
		parent = tree.root
	var effect := FROST_NOVA_EFFECT_SCENE.instantiate() as FrostNovaEffect
	if effect == null:
		return
	parent.add_child(effect)
	effect.global_position = origin
	effect.play(resolved_radius)

func _build_damage_packet(
	loadout: ActiveSkillLoadoutComponent,
	weapon: Weapon,
	tags: Array[StringName]
) -> DamagePacket:
	var packet := DamagePacket.new()
	var amount := base_damage + _get_actor_elemental_scaling(loadout, tags)
	amount = _resolve_bound_weapon_scaled_value(
		amount,
		weapon,
		StatIds.ELEMENTAL_DAMAGE,
		tags,
		[StatIds.DAMAGE]
	)
	packet.source = loadout.player
	packet.tags = tags
	packet.slices = [
		DamageSlice.new(
			amount,
			DamageTypeIds.ELEMENTAL
		)
	]
	return packet

func _get_skill_tags(weapon: Weapon) -> Array[StringName]:
	var tags := weapon.get_attack_tags()
	for tag in [&"active_skill", &"frost_nova", &"elemental", &"hit", &"aoe", &"area"]:
		if not tags.has(tag):
			tags.append(tag)
	return tags

func _get_actor_elemental_scaling(
	loadout: ActiveSkillLoadoutComponent,
	tags: Array[StringName]
) -> float:
	var scaling_packet := DamageResolver.build_outgoing_packet(
		null,
		loadout.stat_component,
		[],
		tags,
		loadout.player,
		[DamageTypeIds.ELEMENTAL],
		elemental_damage_scaling
	)
	return scaling_packet.get_damage_by_type(DamageTypeIds.ELEMENTAL)

func _resolve_bound_weapon_scaled_value(
	amount: float,
	weapon: Weapon,
	stat_id: StringName,
	tags: Array[StringName],
	extra_stat_ids: Array[StringName] = []
) -> float:
	if amount <= 0.0 or not is_instance_valid(weapon.stat_component):
		return amount
	var stat_ids := extra_stat_ids.duplicate()
	if not stat_ids.has(stat_id):
		stat_ids.append(stat_id)
	var flat: float = 0.0
	var increased: float = 0.0
	var more_multiplier: float = 1.0
	for modifier in weapon.stat_component.get_applicable_modifiers(
		stat_ids,
		tags,
		StatModifier.Scope.LOCAL
	):
		match modifier.operation:
			StatModifier.Operation.FLAT:
				flat += modifier.value
			StatModifier.Operation.INCREASED:
				increased += modifier.value
			StatModifier.Operation.MORE:
				more_multiplier *= maxf(0.0, 1.0 + modifier.value / 100.0)
	return (amount + flat) * (1.0 + increased / 100.0) * more_multiplier
