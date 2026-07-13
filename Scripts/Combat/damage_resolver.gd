class_name DamageResolver
extends RefCounted

static func build_outgoing_packet(
	weapon_stats: StatComponent,
	actor_stats: StatComponent,
	conversions: Array[DamageConversion],
	tags: Array[StringName],
	source: Node
) -> DamagePacket:
	var slices: Array[DamageSlice] = []
	for damage_type in DamageTypeIds.ORDER:
		var stat_id := DamageTypeIds.get_damage_stat_id(damage_type)
		var amount: float = 0.0
		if weapon_stats != null:
			amount = weapon_stats.get_stat(
				stat_id,
				tags,
				StatModifier.Scope.LOCAL
			)
		if actor_stats != null:
			amount += actor_stats.get_flat_modifier_total(
				stat_id,
				tags,
				StatModifier.Scope.GLOBAL
			)
		if amount > 0.0:
			slices.append(DamageSlice.new(amount, damage_type))

	slices = _apply_conversions(slices, conversions)
	for slice in slices:
		slice.amount = _apply_global_damage_modifiers(
			slice,
			actor_stats,
			tags
		)

	var packet := DamagePacket.new()
	packet.slices = slices
	packet.tags = tags.duplicate()
	packet.source = source
	return packet

static func resolve_incoming(
	packet: DamagePacket,
	defender_stats: StatComponent
) -> DamageResult:
	var result := DamageResult.new()
	if packet == null:
		return result

	var after_resistance_total: float = 0.0
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
		var effective_resistance := minf(resistance, maximum_resistance)
		var after_resistance := slice.amount * (1.0 - effective_resistance / 100.0)
		result.damage_by_type[slice.current_type] = (
			float(result.damage_by_type.get(slice.current_type, 0.0))
			+ after_resistance
		)
		after_resistance_total += after_resistance

	var toughness: float = 0.0
	var effectiveness: float = 0.0
	if defender_stats != null:
		toughness = defender_stats.get_stat(StatIds.TOUGHNESS)
		effectiveness = defender_stats.get_stat(StatIds.MONSTER_EFFECTIVENESS)

	var toughness_multiplier := (
		1.0 / (1.0 + toughness / 100.0)
		if toughness >= 0.0
		else 1.0 - toughness / 100.0
	)
	var effectiveness_toughness_factor := maxf(0.01, 1.0 + effectiveness / 100.0)
	result.total_damage = (
		after_resistance_total
		* toughness_multiplier
		/ effectiveness_toughness_factor
	)
	return result

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
	var slices := initial_slices.duplicate()
	for source_type in DamageTypeIds.ORDER:
		var source_conversions: Array[DamageConversion] = []
		for conversion in conversions:
			if (
				conversion != null
				and conversion.source_type == source_type
				and conversion.is_valid_conversion()
			):
				source_conversions.append(conversion)
		if source_conversions.is_empty():
			continue

		var updated: Array[DamageSlice] = []
		for slice in slices:
			if slice.current_type != source_type:
				updated.append(slice)
				continue
			updated.append_array(
				_convert_slice(slice, source_conversions)
			)
		slices = updated
	return slices

static func _convert_slice(
	slice: DamageSlice,
	conversions: Array[DamageConversion]
) -> Array[DamageSlice]:
	var result: Array[DamageSlice] = []
	var skill_total: float = 0.0
	var other_total: float = 0.0

	for conversion in conversions:
		if conversion.mode != DamageConversion.Mode.CONVERT:
			continue
		if conversion.priority == DamageConversion.Priority.SKILL:
			skill_total += conversion.percentage
		else:
			other_total += conversion.percentage

	var skill_scale := 1.0
	if skill_total > 100.0:
		skill_scale = 100.0 / skill_total
	var used_by_skill := minf(skill_total, 100.0)
	var remaining_capacity := maxf(0.0, 100.0 - used_by_skill)
	var other_scale := 1.0
	if other_total > remaining_capacity and other_total > 0.0:
		other_scale = remaining_capacity / other_total

	var converted_percentage: float = 0.0
	for conversion in conversions:
		var fraction := conversion.percentage / 100.0
		if conversion.mode == DamageConversion.Mode.CONVERT:
			fraction *= (
				skill_scale
				if conversion.priority == DamageConversion.Priority.SKILL
				else other_scale
			)
			converted_percentage += fraction
			result.append(
				slice.converted_copy(
					conversion.destination_type,
					slice.amount * fraction
				)
			)
		else:
			result.append(
				slice.converted_copy(
					conversion.destination_type,
					slice.amount * fraction
				)
			)

	var remaining_amount := slice.amount * maxf(0.0, 1.0 - converted_percentage)
	if remaining_amount > 0.0:
		result.append(
			DamageSlice.new(
				remaining_amount,
				slice.current_type,
				slice.ancestry_types
			)
		)
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
	for damage_type in slice.get_applicable_types():
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
