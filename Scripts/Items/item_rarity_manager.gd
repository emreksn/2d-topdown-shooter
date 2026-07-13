class_name ItemRarityManager
extends Resource

const RARITY_ORDER: Array[ItemDefinition.Rarity] = [
	ItemDefinition.Rarity.COMMON,
	ItemDefinition.Rarity.UNCOMMON,
	ItemDefinition.Rarity.RARE,
	ItemDefinition.Rarity.LEGENDARY,
	ItemDefinition.Rarity.TRADEOFF,
	ItemDefinition.Rarity.UNIQUE
]

@export_range(0.0, 1000000.0, 0.1, "or_greater") var common_weight: float = 70.0
@export_range(0.0, 1000000.0, 0.1, "or_greater") var uncommon_weight: float = 22.0
@export_range(0.0, 1000000.0, 0.1, "or_greater") var rare_weight: float = 6.0
@export_range(0.0, 1000000.0, 0.1, "or_greater") var legendary_weight: float = 1.5
@export_range(0.0, 1000000.0, 0.1, "or_greater") var tradeoff_weight: float = 0.4
@export_range(0.0, 1000000.0, 0.1, "or_greater") var unique_weight: float = 0.1
@export_range(0.0, 10.0, 0.01, "or_greater") var rarity_multiplier_strength: float = 1.0
@export_range(1.0, 1000.0, 0.05, "or_greater") var maximum_effective_multiplier: float = 3.0
@export_range(1, 1000000, 1, "or_greater") var common_minimum_wave: int = 1
@export_range(1, 1000000, 1, "or_greater") var uncommon_minimum_wave: int = 1
@export_range(1, 1000000, 1, "or_greater") var rare_minimum_wave: int = 3
@export_range(1, 1000000, 1, "or_greater") var legendary_minimum_wave: int = 6
@export_range(1, 1000000, 1, "or_greater") var tradeoff_minimum_wave: int = 8
@export_range(1, 1000000, 1, "or_greater") var unique_minimum_wave: int = 10

func roll_rarity(
	rng: RandomNumberGenerator,
	rarity_multiplier: float = 1.0,
	wave_number: int = 1
) -> ItemDefinition.Rarity:
	var weights := get_adjusted_weights(rarity_multiplier, wave_number)
	var total_weight := 0.0
	for rarity in RARITY_ORDER:
		total_weight += maxf(float(weights[rarity]), 0.0)

	if total_weight <= 0.0:
		return ItemDefinition.Rarity.COMMON

	var roll := rng.randf_range(0.0, total_weight)
	for rarity in RARITY_ORDER:
		roll -= maxf(float(weights[rarity]), 0.0)
		if roll <= 0.0:
			return rarity
	return RARITY_ORDER.back()

func choose_item(
	items: Array[ItemDefinition],
	rng: RandomNumberGenerator,
	rarity_multiplier: float = 1.0,
	wave_number: int = 1
) -> ItemDefinition:
	if items.is_empty():
		return null

	var available_items := _get_wave_available_items(items, wave_number)
	if available_items.is_empty():
		return null

	var rarity := _roll_rarity_for_items(
		available_items,
		rng,
		rarity_multiplier,
		wave_number
	)
	var candidates := _get_items_by_rarity(available_items, rarity)
	if candidates.is_empty():
		candidates = _get_nearest_available_rarity_items(
			available_items,
			rarity
		)
	if candidates.is_empty():
		candidates = available_items
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func get_adjusted_weights(
	rarity_multiplier: float = 1.0,
	wave_number: int = 1
) -> Dictionary:
	var multiplier := clampf(
		maxf(rarity_multiplier, 0.0),
		0.0,
		maximum_effective_multiplier
	)
	var weights := {}
	for index: int in range(RARITY_ORDER.size()):
		var rarity: ItemDefinition.Rarity = RARITY_ORDER[index]
		if not is_rarity_unlocked(rarity, wave_number):
			weights[rarity] = 0.0
			continue
		var base_weight: float = _get_base_weight(rarity)
		if index == 0:
			weights[rarity] = base_weight
			continue
		var rarity_factor := 1.0 + (
			maxf(multiplier - 1.0, 0.0)
			* float(index)
			* rarity_multiplier_strength
		)
		weights[rarity] = base_weight * rarity_factor
	return weights

func _roll_rarity_for_items(
	items: Array[ItemDefinition],
	rng: RandomNumberGenerator,
	rarity_multiplier: float,
	wave_number: int
) -> ItemDefinition.Rarity:
	var available_rarities := {}
	for item in items:
		if item != null:
			available_rarities[item.rarity] = true

	var weights := get_adjusted_weights(rarity_multiplier, wave_number)
	var total_weight := 0.0
	for rarity in RARITY_ORDER:
		if available_rarities.has(rarity):
			total_weight += maxf(float(weights[rarity]), 0.0)

	if total_weight <= 0.0:
		return ItemDefinition.Rarity.COMMON

	var roll := rng.randf_range(0.0, total_weight)
	for rarity in RARITY_ORDER:
		if not available_rarities.has(rarity):
			continue
		roll -= maxf(float(weights[rarity]), 0.0)
		if roll <= 0.0:
			return rarity
	return RARITY_ORDER.front()

func is_rarity_unlocked(
	rarity: ItemDefinition.Rarity,
	wave_number: int
) -> bool:
	return wave_number >= get_minimum_wave_for_rarity(rarity)

func get_minimum_wave_for_rarity(rarity: ItemDefinition.Rarity) -> int:
	match rarity:
		ItemDefinition.Rarity.COMMON:
			return common_minimum_wave
		ItemDefinition.Rarity.UNCOMMON:
			return uncommon_minimum_wave
		ItemDefinition.Rarity.RARE:
			return rare_minimum_wave
		ItemDefinition.Rarity.LEGENDARY:
			return legendary_minimum_wave
		ItemDefinition.Rarity.TRADEOFF:
			return tradeoff_minimum_wave
		ItemDefinition.Rarity.UNIQUE:
			return unique_minimum_wave
		_:
			return common_minimum_wave

func _get_items_by_rarity(
	items: Array[ItemDefinition],
	rarity: ItemDefinition.Rarity
) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in items:
		if item != null and item.rarity == rarity:
			result.append(item)
	return result

func _get_wave_available_items(
	items: Array[ItemDefinition],
	wave_number: int
) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in items:
		if (
			item != null
			and is_rarity_unlocked(item.rarity, wave_number)
		):
			result.append(item)
	return result

func _get_nearest_available_rarity_items(
	items: Array[ItemDefinition],
	target_rarity: ItemDefinition.Rarity
) -> Array[ItemDefinition]:
	var target_index: int = RARITY_ORDER.find(target_rarity)
	if target_index < 0:
		return []
	for offset: int in range(RARITY_ORDER.size()):
		for direction: int in [-1, 1]:
			var index: int = target_index + offset * direction
			if index < 0 or index >= RARITY_ORDER.size():
				continue
			var candidates: Array[ItemDefinition] = _get_items_by_rarity(
				items,
				RARITY_ORDER[index]
			)
			if not candidates.is_empty():
				return candidates
	return []

func _get_base_weight(rarity: ItemDefinition.Rarity) -> float:
	match rarity:
		ItemDefinition.Rarity.COMMON:
			return common_weight
		ItemDefinition.Rarity.UNCOMMON:
			return uncommon_weight
		ItemDefinition.Rarity.RARE:
			return rare_weight
		ItemDefinition.Rarity.LEGENDARY:
			return legendary_weight
		ItemDefinition.Rarity.TRADEOFF:
			return tradeoff_weight
		ItemDefinition.Rarity.UNIQUE:
			return unique_weight
		_:
			return common_weight
