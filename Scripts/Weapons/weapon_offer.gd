class_name WeaponOffer
extends Resource

const SCALING_STATS: Array[StringName] = [
	StatIds.PHYSICAL_DAMAGE,
	StatIds.ELEMENTAL_DAMAGE,
	StatIds.ATTACK_RATE,
	StatIds.TARGETING_RANGE,
	StatIds.PROJECTILE_SPEED,
	StatIds.PROJECTILE_PIERCE,
	StatIds.PROJECTILE_FORK,
	StatIds.PROJECTILE_CHAIN
]

const AFFIX_STATS: Array[StringName] = [
	StatIds.PHYSICAL_DAMAGE,
	StatIds.ELEMENTAL_DAMAGE,
	StatIds.ATTACK_RATE,
	StatIds.TARGETING_RANGE,
	StatIds.PROJECTILE_SPEED
]

var definition: WeaponDefinition
var rarity: ItemDefinition.Rarity = ItemDefinition.Rarity.COMMON
var stat_multiplier: float = 1.0
var modifier_set: ModifierSet
var implicit_modifiers: Array[StatModifier] = []
var affix_modifiers: Array[StatModifier] = []

static func create(
	weapon_definition: WeaponDefinition,
	rolled_rarity: ItemDefinition.Rarity,
	rng: RandomNumberGenerator
) -> WeaponOffer:
	var offer := WeaponOffer.new()
	offer.definition = weapon_definition
	offer.rarity = rolled_rarity
	offer.stat_multiplier = get_stat_multiplier(rolled_rarity)
	offer.modifier_set = ModifierSet.new()
	offer.modifier_set.modifiers = []
	offer._add_implicit_modifiers()
	offer._add_rarity_scaling_modifiers()
	offer._roll_affixes(rng)
	return offer

static func get_stat_multiplier(value: ItemDefinition.Rarity) -> float:
	match value:
		ItemDefinition.Rarity.UNCOMMON:
			return 1.25
		ItemDefinition.Rarity.RARE:
			return 1.6
		ItemDefinition.Rarity.LEGENDARY:
			return 2.1
		_:
			return 1.0

static func get_affix_count(value: ItemDefinition.Rarity) -> int:
	match value:
		ItemDefinition.Rarity.UNCOMMON:
			return 1
		ItemDefinition.Rarity.RARE:
			return 2
		ItemDefinition.Rarity.LEGENDARY:
			return 3
		_:
			return 0

func get_shop_price(wave_number: int) -> int:
	if definition == null:
		return 1
	var wave_markup := maxi(wave_number - 1, 0) * 2
	return maxi(1, roundi(float(definition.base_cost + wave_markup) * stat_multiplier))

func get_sell_value(wave_number: int = 1) -> int:
	return maxi(1, roundi(float(get_shop_price(wave_number)) * 0.5))

func get_display_name() -> String:
	var rarity_name := ItemDefinition.get_rarity_name(rarity)
	var weapon_name := definition.display_name if definition != null else "Weapon"
	return "%s %s" % [rarity_name, weapon_name]

func get_offer_text(wave_number: int) -> String:
	return "%s - %dg\n%s" % [
		get_display_name(),
		get_shop_price(wave_number),
		get_stat_display_text()
	]

func get_inventory_label() -> String:
	return get_display_name()

func get_stat_display_text() -> String:
	var lines: Array[String] = []
	if not is_equal_approx(stat_multiplier, 1.0):
		lines.append(
			"%sx base weapon stats"
			% _format_number(stat_multiplier)
		)
	for modifier in implicit_modifiers:
		lines.append("Implicit: %s" % ItemDefinition._format_modifier_line(modifier))
	for modifier in affix_modifiers:
		lines.append(ItemDefinition._format_modifier_line(modifier))
	if lines.is_empty():
		return "Common baseline weapon."
	return "\n".join(lines)

func instantiate_weapon() -> Weapon:
	if definition == null or definition.weapon_scene == null:
		return null
	var weapon := definition.weapon_scene.instantiate() as Weapon
	if weapon == null:
		return null
	return weapon

func _add_implicit_modifiers() -> void:
	if definition == null or definition.implicit_modifier_set == null:
		return
	for modifier in definition.implicit_modifier_set.modifiers:
		if modifier == null:
			continue
		var copy := modifier.duplicate(true) as StatModifier
		implicit_modifiers.append(copy)
		modifier_set.modifiers.append(copy)

func _add_rarity_scaling_modifiers() -> void:
	if is_equal_approx(stat_multiplier, 1.0):
		return
	var increased_value := (stat_multiplier - 1.0) * 100.0
	for stat_id in SCALING_STATS:
		var modifier := _make_modifier(
			stat_id,
			StatModifier.Operation.INCREASED,
			increased_value
		)
		modifier_set.modifiers.append(modifier)

func _roll_affixes(rng: RandomNumberGenerator) -> void:
	var count := get_affix_count(rarity)
	if count <= 0:
		return
	var available_stats := AFFIX_STATS.duplicate()
	for _index in range(mini(count, available_stats.size())):
		var stat_index := rng.randi_range(0, available_stats.size() - 1)
		var stat_id: StringName = available_stats[stat_index]
		available_stats.remove_at(stat_index)
		var modifier := _make_modifier(
			stat_id,
			_get_affix_operation(stat_id),
			_get_affix_value(stat_id, rarity)
		)
		affix_modifiers.append(modifier)
		modifier_set.modifiers.append(modifier)

func _make_modifier(
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float
) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.scope = StatModifier.Scope.LOCAL
	modifier.target_domain = &"weapon"
	return modifier

func _get_affix_value(
	stat_id: StringName,
	value_rarity: ItemDefinition.Rarity
) -> float:
	var tier := 1.0
	match value_rarity:
		ItemDefinition.Rarity.RARE:
			tier = 2.0
		ItemDefinition.Rarity.LEGENDARY:
			tier = 3.5
		_:
			tier = 1.0
	match stat_id:
		StatIds.PHYSICAL_DAMAGE:
			return 10.0 * tier
		StatIds.ELEMENTAL_DAMAGE:
			return 8.0 * tier
		StatIds.ATTACK_RATE:
			return 12.0 * tier
		StatIds.TARGETING_RANGE:
			return 10.0 * tier
		StatIds.PROJECTILE_SPEED:
			return 10.0 * tier
		StatIds.PROJECTILE_PIERCE, StatIds.PROJECTILE_FORK, StatIds.PROJECTILE_CHAIN:
			return 1.0
		_:
			return 1.0 * tier

func _get_affix_operation(stat_id: StringName) -> StatModifier.Operation:
	if stat_id in [
		StatIds.ATTACK_RATE,
		StatIds.TARGETING_RANGE,
		StatIds.PROJECTILE_SPEED
	]:
		return StatModifier.Operation.INCREASED
	return StatModifier.Operation.FLAT

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")
