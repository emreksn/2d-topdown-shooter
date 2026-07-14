class_name DamageResolver
extends RefCounted

const ARMOUR_RATING_SCALE := 800.0
const EVASION_RATING_SCALE := 500.0
const MAXIMUM_ARMOUR_REDUCTION := 0.9
const MAXIMUM_EVADE_CHANCE := 0.75
const DEFAULT_DEFLECTION_DAMAGE_REDUCTION := 20.0

static func build_outgoing_packet(
	weapon_stats: StatComponent,
	actor_stats: StatComponent,
	conversions: Array[DamageConversion],
	tags: Array[StringName],
	source: Node,
	allowed_base_damage_types: Array[StringName] = [],
	added_damage_multiplier: float = 1.0
) -> DamagePacket:
	var slices: Array[DamageSlice] = []
	var resolved_base_damage_types := (
		DamageTypeIds.ORDER
		if allowed_base_damage_types == null or allowed_base_damage_types.is_empty()
		else allowed_base_damage_types
	)
	for damage_type in DamageTypeIds.ORDER:
		if not resolved_base_damage_types.has(damage_type):
			continue
		var stat_id := DamageTypeIds.get_damage_stat_id(damage_type)
		var amount: float = 0.0
		if weapon_stats != null:
			amount = weapon_stats.get_stat(
				stat_id,
				tags,
				StatModifier.Scope.LOCAL
			)
		if actor_stats != null:
			amount += _get_actor_added_damage(
				actor_stats,
				stat_id,
				damage_type,
				tags,
			) * added_damage_multiplier
		if amount > 0.0:
			slices.append(DamageSlice.new(amount, damage_type))

	slices = _apply_conversions(slices, conversions)

	var packet := DamagePacket.new()
	packet.slices = slices
	packet.tags = tags.duplicate()
	packet.source = source
	return packet

static func _get_actor_added_damage(
	actor_stats: StatComponent,
	stat_id: StringName,
	damage_type: StringName,
	tags: Array[StringName]
) -> float:
	var amount := actor_stats.get_flat_modifier_total(
		stat_id,
		tags,
		StatModifier.Scope.GLOBAL
	)
	if amount <= 0.0:
		return amount

	var stat_ids: Array[StringName] = [StatIds.DAMAGE]
	if stat_id != &"" and not stat_ids.has(stat_id):
		stat_ids.append(stat_id)

	var damage_context_tags := tags.duplicate()
	if not damage_context_tags.has(damage_type):
		damage_context_tags.append(damage_type)

	var increased: float = 0.0
	var more_multiplier: float = 1.0
	for modifier in actor_stats.get_applicable_modifiers(
		stat_ids,
		damage_context_tags,
		StatModifier.Scope.GLOBAL
	):
		match modifier.operation:
			StatModifier.Operation.INCREASED:
				increased += modifier.value
			StatModifier.Operation.MORE:
				more_multiplier *= maxf(0.0, 1.0 + modifier.value / 100.0)

	return amount * (1.0 + increased / 100.0) * more_multiplier

static func resolve_incoming(
	packet: DamagePacket,
	defender_stats: StatComponent,
	evade_roll: float = -1.0,
	deflect_roll: float = -1.0
) -> DamageResult:
	var result := DamageResult.new()
	if packet == null:
		return result

	var attacker_stats := _get_packet_source_stats(packet)
	var accuracy := _get_attacker_stat(attacker_stats, StatIds.ACCURACY, packet.tags)
	var evasion := maxf(
		_get_defender_stat(defender_stats, StatIds.EVASION) - accuracy,
		0.0
	)
	result.evade_chance = _calculate_evasion_chance(evasion)
	if result.evade_chance > 0.0:
		var resolved_evade_roll := randf() if evade_roll < 0.0 else evade_roll
		if resolved_evade_roll < result.evade_chance:
			result.was_evaded = true
			return result

	var after_resistance_by_type: Dictionary = {}
	for slice in packet.slices:
		var resistance: float = 0.0
		var maximum_resistance: float = 75.0
		if defender_stats != null:
			resistance = defender_stats.get_stat(
				DamageTypeIds.get_resistance_stat_id(slice.current_type)
			)
			maximum_resistance = defender_stats.get_stat(
				DamageTypeIds.get_maximum_resistance_stat_id(slice.current_type)
			)
		var penetration := _get_attacker_stat(
			attacker_stats,
			_get_resistance_penetration_stat_id(slice.current_type),
			_get_damage_context_tags(packet.tags, slice.current_type)
		)
		var effective_resistance := maxf(
			minf(resistance, maximum_resistance) - penetration,
			-100.0
		)
		var after_resistance := slice.amount * (1.0 - effective_resistance / 100.0)
		after_resistance_by_type[slice.current_type] = (
			float(after_resistance_by_type.get(slice.current_type, 0.0))
			+ after_resistance
		)

	var deflection_multiplier := 1.0
	result.deflect_chance = result.evade_chance
	if result.deflect_chance > 0.0:
		var resolved_deflect_roll := randf() if deflect_roll < 0.0 else deflect_roll
		if resolved_deflect_roll < result.deflect_chance:
			result.was_deflected = true
			var deflection_reduction := (
				_get_defender_stat(
					defender_stats,
					StatIds.DEFLECTION_DAMAGE_REDUCTION,
					DEFAULT_DEFLECTION_DAMAGE_REDUCTION
				)
			)
			deflection_multiplier = maxf(0.0, 1.0 - deflection_reduction / 100.0)

	var physical_after_deflection := (
		float(after_resistance_by_type.get(DamageTypeIds.PHYSICAL, 0.0))
		* deflection_multiplier
	)
	var elemental_after_deflection := (
		float(after_resistance_by_type.get(DamageTypeIds.ELEMENTAL, 0.0))
		* deflection_multiplier
	)

	var armour_penetration := _get_attacker_stat(
		attacker_stats,
		StatIds.ARMOUR_PENETRATION,
		packet.tags
	)
	var armour := maxf(
		_get_defender_stat(defender_stats, StatIds.ARMOUR) - armour_penetration,
		0.0
	)
	result.armour_reduction = _calculate_armour_reduction(armour)
	var physical_after_armour := (
		physical_after_deflection
		* (1.0 - result.armour_reduction)
	)
	var elemental_after_armour := elemental_after_deflection

	var toughness: float = 0.0
	var effectiveness: float = 0.0
	if defender_stats != null:
		toughness = defender_stats.get_stat(StatIds.TOUGHNESS)
		effectiveness = defender_stats.get_stat(StatIds.MONSTER_EFFECTIVENESS)

	var combined_toughness := toughness + effectiveness
	var toughness_multiplier := (
		1.0 / (1.0 + combined_toughness / 100.0)
		if combined_toughness >= 0.0
		else 1.0 - combined_toughness / 100.0
	)
	var physical_final := (
		physical_after_armour
		* toughness_multiplier
	)
	var elemental_final := (
		elemental_after_armour
		* toughness_multiplier
	)
	result.damage_by_type[DamageTypeIds.PHYSICAL] = physical_final
	result.damage_by_type[DamageTypeIds.ELEMENTAL] = elemental_final
	result.life_damage = physical_final + elemental_final
	result.total_damage = result.life_damage
	return result

static func _get_defender_stat(
	defender_stats: StatComponent,
	stat_id: StringName,
	fallback: float = 0.0
) -> float:
	return defender_stats.get_stat(stat_id) if defender_stats != null else fallback

static func _get_attacker_stat(
	attacker_stats: StatComponent,
	stat_id: StringName,
	context_tags: Array[StringName]
) -> float:
	if attacker_stats == null or stat_id == &"":
		return 0.0
	return attacker_stats.get_stat(stat_id, context_tags, StatModifier.Scope.GLOBAL)

static func _get_packet_source_stats(packet: DamagePacket) -> StatComponent:
	if packet == null or packet.source == null:
		return null
	if packet.source is StatComponent:
		return packet.source as StatComponent
	return packet.source.get_node_or_null("StatComponent") as StatComponent

static func _get_resistance_penetration_stat_id(damage_type: StringName) -> StringName:
	match damage_type:
		DamageTypeIds.PHYSICAL:
			return StatIds.PHYSICAL_RESISTANCE_PENETRATION
		DamageTypeIds.ELEMENTAL:
			return StatIds.ELEMENTAL_RESISTANCE_PENETRATION
		_:
			return &""

static func _get_damage_context_tags(
	base_tags: Array[StringName],
	damage_type: StringName
) -> Array[StringName]:
	var context_tags := base_tags.duplicate()
	if damage_type != &"" and not context_tags.has(damage_type):
		context_tags.append(damage_type)
	return context_tags

static func _calculate_evasion_chance(evasion: float) -> float:
	if evasion <= 0.0:
		return 0.0
	return clampf(
		MAXIMUM_EVADE_CHANCE * evasion / (evasion + EVASION_RATING_SCALE),
		0.0,
		MAXIMUM_EVADE_CHANCE
	)

static func _calculate_armour_reduction(armour: float) -> float:
	if armour <= 0.0:
		return 0.0
	return clampf(
		MAXIMUM_ARMOUR_REDUCTION * armour / (armour + ARMOUR_RATING_SCALE),
		0.0,
		MAXIMUM_ARMOUR_REDUCTION
	)

static func build_direct_packet(
	base_amount: float,
	damage_type: StringName,
	actor_stats: StatComponent,
	tags: Array[StringName],
	source: Node
) -> DamagePacket:
	var slice := DamageSlice.new(base_amount, damage_type)
	slice.amount = _apply_global_damage_modifiers(slice, actor_stats, tags)
	var packet := DamagePacket.new()
	packet.slices = [slice]
	packet.tags = tags.duplicate()
	packet.source = source
	return packet

static func _apply_conversions(
	initial_slices: Array[DamageSlice],
	conversions: Array[DamageConversion]
) -> Array[DamageSlice]:
	var skill_conversions := _filter_conversions(
		conversions,
		DamageConversion.Mode.CONVERT,
		DamageConversion.Priority.SKILL
	)
	var other_conversions := _filter_conversions(
		conversions,
		DamageConversion.Mode.CONVERT,
		DamageConversion.Priority.OTHER
	)
	var gain_conversions := _filter_conversions(
		conversions,
		DamageConversion.Mode.GAIN_AS_EXTRA
	)

	var slices := _apply_conversion_stage(initial_slices, skill_conversions)
	slices = _apply_conversion_stage(slices, other_conversions)
	return _apply_gain_stage(slices, gain_conversions)

static func _filter_conversions(
	conversions: Array[DamageConversion],
	mode: DamageConversion.Mode,
	priority: int = -1
) -> Array[DamageConversion]:
	var result: Array[DamageConversion] = []
	for conversion in conversions:
		if conversion == null or not conversion.is_valid_conversion():
			continue
		if conversion.mode != mode:
			continue
		if priority >= 0 and conversion.priority != priority:
			continue
		result.append(conversion)
	return result

static func _apply_conversion_stage(
	slices: Array[DamageSlice],
	conversions: Array[DamageConversion]
) -> Array[DamageSlice]:
	if conversions.is_empty():
		return slices
	var result: Array[DamageSlice] = []
	for slice in slices:
		var source_conversions := _get_source_conversions(
			conversions,
			slice.current_type
		)
		if source_conversions.is_empty():
			result.append(slice)
			continue
		result.append_array(_convert_slice(slice, source_conversions))
	return result

static func _apply_gain_stage(
	slices: Array[DamageSlice],
	conversions: Array[DamageConversion]
) -> Array[DamageSlice]:
	if conversions.is_empty():
		return slices
	var result := slices.duplicate()
	var frozen_source_pool := slices.duplicate()
	for slice in frozen_source_pool:
		for conversion in _get_source_conversions(conversions, slice.current_type):
			result.append(
				DamageSlice.new(
					slice.amount * conversion.percentage / 100.0,
					conversion.destination_type
				)
			)
	return result

static func _get_source_conversions(
	conversions: Array[DamageConversion],
	source_type: StringName
) -> Array[DamageConversion]:
	var result: Array[DamageConversion] = []
	for conversion in conversions:
		if conversion.source_type == source_type:
			result.append(conversion)
	return result

static func _convert_slice(
	slice: DamageSlice,
	conversions: Array[DamageConversion]
) -> Array[DamageSlice]:
	var result: Array[DamageSlice] = []
	var conversion_total: float = 0.0

	for conversion in conversions:
		conversion_total += conversion.percentage

	var conversion_scale := 1.0
	if conversion_total > 100.0:
		conversion_scale = 100.0 / conversion_total
	var converted_percentage: float = 0.0
	for conversion in conversions:
		var fraction := conversion.percentage / 100.0 * conversion_scale
		converted_percentage += fraction
		result.append(
			slice.converted_copy(
				conversion.destination_type,
				slice.amount * fraction
			)
		)

	var remaining_amount := slice.amount * maxf(0.0, 1.0 - converted_percentage)
	if remaining_amount > 0.0:
		result.append(DamageSlice.new(remaining_amount, slice.current_type))
	return result

static func _apply_global_damage_modifiers(
	slice: DamageSlice,
	actor_stats: StatComponent,
	tags: Array[StringName]
) -> float:
	if actor_stats == null:
		return slice.amount

	var stat_ids: Array[StringName] = []
	stat_ids.append(StatIds.DAMAGE)
	var damage_context_tags := tags.duplicate()
	var damage_type := slice.current_type
	if not damage_context_tags.has(damage_type):
		damage_context_tags.append(damage_type)
	var stat_id := DamageTypeIds.get_damage_stat_id(damage_type)
	if stat_id != &"" and not stat_ids.has(stat_id):
		stat_ids.append(stat_id)

	var increased: float = 0.0
	var more_multiplier: float = 1.0
	for modifier in actor_stats.get_applicable_modifiers(
		stat_ids,
		damage_context_tags,
		StatModifier.Scope.GLOBAL
	):
		match modifier.operation:
			StatModifier.Operation.INCREASED:
				increased += modifier.value
			StatModifier.Operation.MORE:
				more_multiplier *= maxf(0.0, 1.0 + modifier.value / 100.0)

	return slice.amount * (1.0 + increased / 100.0) * more_multiplier
