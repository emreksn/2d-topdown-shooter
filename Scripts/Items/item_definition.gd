class_name ItemDefinition
extends Resource

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
	TRADEOFF,
	UNIQUE
}

enum ItemCategory {
	ITEM,
	RELIC
}

enum RelicSlot {
	NONE,
	COMBAT,
	WEAPON,
	ECONOMY,
	SURVIVAL,
	WAVE
}

@export var id: StringName
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var category: ItemCategory = ItemCategory.ITEM
@export var relic_slot: RelicSlot = RelicSlot.NONE
@export var rarity: Rarity = Rarity.COMMON
@export_range(0, 1000000, 1, "or_greater") var cost: int = 10
@export_range(0.0, 1.0, 0.05) var sell_value_multiplier: float = 0.5
@export var sellable: bool = true
@export var modifier_set: ModifierSet
@export var damage_conversions: Array[DamageConversion] = []

func get_shop_price(wave_number: int) -> int:
	return maxi(1, cost + maxi(wave_number - 1, 0) * 2)

func get_sell_value(wave_number: int = 1) -> int:
	return maxi(1, roundi(float(get_shop_price(wave_number)) * sell_value_multiplier))

func get_inventory_label(count: int = 1) -> String:
	var suffix := " x%d" % count if count > 1 else ""
	if category == ItemCategory.RELIC:
		return "%s %s Relic: %s%s" % [
			get_rarity_display_name(),
			get_relic_slot_display_name(),
			display_name,
			suffix
		]
	return "%s %s%s" % [get_rarity_display_name(), display_name, suffix]

func get_stat_display_text() -> String:
	if modifier_set == null or modifier_set.modifiers.is_empty():
		return description

	var lines: Array[String] = []
	for modifier in modifier_set.modifiers:
		if modifier == null:
			continue
		lines.append(_format_modifier_line(modifier))
	return "\n".join(lines)

func get_rarity_display_name() -> String:
	return get_rarity_name(rarity)

func get_relic_slot_display_name() -> String:
	return get_relic_slot_name(relic_slot)

static func get_rarity_name(value: Rarity) -> String:
	match value:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.LEGENDARY:
			return "Legendary"
		Rarity.TRADEOFF:
			return "Tradeoff"
		Rarity.UNIQUE:
			return "Unique"
		_:
			return "Common"

static func get_relic_slot_name(value: RelicSlot) -> String:
	match value:
		RelicSlot.COMBAT:
			return "Combat"
		RelicSlot.WEAPON:
			return "Weapon"
		RelicSlot.ECONOMY:
			return "Economy"
		RelicSlot.SURVIVAL:
			return "Survival"
		RelicSlot.WAVE:
			return "Wave"
		_:
			return "None"

static func _format_modifier_line(modifier: StatModifier) -> String:
	var stat_name := _get_stat_display_name(modifier.stat_id)
	match modifier.operation:
		StatModifier.Operation.FLAT:
			return _format_flat_modifier_line(modifier.stat_id, modifier.value)
		StatModifier.Operation.INCREASED:
			return _format_scaled_modifier_line(
				modifier.value,
				stat_name,
				"increased",
				"decreased"
			)
		StatModifier.Operation.MORE:
			return _format_scaled_modifier_line(
				modifier.value,
				stat_name,
				"more",
				"less"
			)
		_:
			return _format_flat_modifier_line(modifier.stat_id, modifier.value)

static func _format_scaled_modifier_line(
	value: float,
	stat_name: String,
	positive_word: String,
	negative_word: String
) -> String:
	var word := positive_word if value >= 0.0 else negative_word
	return "%s%% %s %s" % [_format_number(absf(value)), word, stat_name]

static func _format_flat_modifier_line(stat_id: StringName, value: float) -> String:
	var _sign := "+" if value >= 0.0 else "-"
	return "%s%s to %s" % [
		_sign,
		_format_modifier_value(stat_id, absf(value)),
		_get_stat_display_name(stat_id)
	]

static func _format_modifier_value(stat_id: StringName, value: float) -> String:
	if _is_percentage_point_stat(stat_id):
		return "%s%%" % _format_number(value)
	if _is_fractional_multiplier_stat(stat_id):
		return "%s%%" % _format_number(value * 100.0)
	return _format_number(value)

static func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")

static func _is_percentage_point_stat(stat_id: StringName) -> bool:
	return stat_id in [
		StatIds.DAMAGE,
		StatIds.PHYSICAL_RESISTANCE,
		StatIds.ELEMENTAL_RESISTANCE,
		StatIds.MAXIMUM_PHYSICAL_RESISTANCE,
		StatIds.MAXIMUM_ELEMENTAL_RESISTANCE,
		StatIds.PHYSICAL_RESISTANCE_PENETRATION,
		StatIds.ELEMENTAL_RESISTANCE_PENETRATION,
		StatIds.TOUGHNESS,
		StatIds.DEFLECTION_DAMAGE_REDUCTION,
		StatIds.ARCANE_SHIELD_RECHARGE_START_SPEED,
		StatIds.ARCANE_SHIELD_RECHARGE_RATE,
		StatIds.SHOP_FREE_REROLL_CHANCE
	]

static func _is_fractional_multiplier_stat(stat_id: StringName) -> bool:
	return stat_id in [
		StatIds.EXPERIENCE_GRANTED_MULTIPLIER,
		StatIds.EXPERIENCE_GAIN_MULTIPLIER,
		StatIds.ITEM_QUANTITY_MULTIPLIER,
		StatIds.ITEM_RARITY_MULTIPLIER,
		StatIds.MONSTER_ITEM_RARITY_MULTIPLIER,
		StatIds.MONSTER_RELIC_DROP_CHANCE_MULTIPLIER,
		StatIds.MONSTER_WEAPON_DROP_CHANCE_MULTIPLIER,
		StatIds.MONSTER_ACTIVE_SKILL_DROP_CHANCE_MULTIPLIER,
		StatIds.SHOP_ITEM_RARITY_MULTIPLIER,
		StatIds.RELIC_CHANCE_MULTIPLIER,
		StatIds.SHOP_RELIC_CHANCE_MULTIPLIER,
		StatIds.SHOP_REROLL_COST_MULTIPLIER,
		StatIds.GOLD_GRANTED_MULTIPLIER,
		StatIds.MONSTER_RARITY_MULTIPLIER
	]

static func _get_stat_display_name(stat_id: StringName) -> String:
	match stat_id:
		StatIds.MAXIMUM_HEALTH:
			return "maximum health"
		StatIds.MOVEMENT_SPEED:
			return "movement speed"
		StatIds.ATTACK_RATE:
			return "attack rate"
		StatIds.TARGETING_RANGE:
			return "targeting range"
		StatIds.DAMAGE:
			return "damage"
		StatIds.PHYSICAL_DAMAGE:
			return "physical damage"
		StatIds.ELEMENTAL_DAMAGE:
			return "elemental damage"
		StatIds.PROJECTILE_SPEED:
			return "projectile speed"
		StatIds.PROJECTILE_PIERCE:
			return "projectile pierce"
		StatIds.PROJECTILE_FORK:
			return "projectile fork"
		StatIds.PROJECTILE_CHAIN:
			return "projectile chain"
		StatIds.PROJECTILE_CHAIN_RADIUS:
			return "projectile chain radius"
		StatIds.AREA_OF_EFFECT:
			return "area of effect"
		StatIds.COOLDOWN_DURATION:
			return "cooldown duration"
		StatIds.MELEE_DAMAGE:
			return "melee damage"
		StatIds.PHYSICAL_RESISTANCE:
			return "physical resistance"
		StatIds.ELEMENTAL_RESISTANCE:
			return "elemental resistance"
		StatIds.MAXIMUM_PHYSICAL_RESISTANCE:
			return "maximum physical resistance"
		StatIds.MAXIMUM_ELEMENTAL_RESISTANCE:
			return "maximum elemental resistance"
		StatIds.ACCURACY:
			return "accuracy"
		StatIds.PHYSICAL_RESISTANCE_PENETRATION:
			return "physical resistance penetration"
		StatIds.ELEMENTAL_RESISTANCE_PENETRATION:
			return "elemental resistance penetration"
		StatIds.ARMOUR_PENETRATION:
			return "armour penetration"
		StatIds.TOUGHNESS:
			return "toughness"
		StatIds.ARMOUR:
			return "armour"
		StatIds.EVASION:
			return "evasion"
		StatIds.DEFLECTION_DAMAGE_REDUCTION:
			return "deflection damage reduction"
		StatIds.MAXIMUM_ARCANE_SHIELD:
			return "maximum arcane shield"
		StatIds.ARCANE_SHIELD_RECHARGE_START_SPEED:
			return "arcane shield recharge start speed"
		StatIds.ARCANE_SHIELD_RECHARGE_RATE:
			return "arcane shield recharge rate"
		StatIds.MONSTER_EFFECTIVENESS:
			return "monster effectiveness"
		StatIds.EXPERIENCE_GRANTED_MULTIPLIER:
			return "experience granted"
		StatIds.EXPERIENCE_GAIN_MULTIPLIER:
			return "experience gain"
		StatIds.ITEM_QUANTITY_MULTIPLIER:
			return "item quantity"
		StatIds.ITEM_RARITY_MULTIPLIER:
			return "item rarity"
		StatIds.MONSTER_ITEM_RARITY_MULTIPLIER:
			return "monster item rarity"
		StatIds.MONSTER_RELIC_DROP_CHANCE_MULTIPLIER:
			return "monster relic drops"
		StatIds.MONSTER_WEAPON_DROP_CHANCE_MULTIPLIER:
			return "monster weapon drops"
		StatIds.MONSTER_ACTIVE_SKILL_DROP_CHANCE_MULTIPLIER:
			return "monster skill drops"
		StatIds.SHOP_ITEM_RARITY_MULTIPLIER:
			return "shop item rarity"
		StatIds.RELIC_CHANCE_MULTIPLIER:
			return "relic chance"
		StatIds.SHOP_RELIC_CHANCE_MULTIPLIER:
			return "shop relic chance"
		StatIds.SHOP_EXTRA_OFFER_COUNT:
			return "shop options"
		StatIds.SHOP_REROLL_COST_MULTIPLIER:
			return "reroll cost"
		StatIds.SHOP_FREE_REROLL_CHANCE:
			return "free reroll chance"
		StatIds.GOLD_GRANTED_MULTIPLIER:
			return "gold granted"
		StatIds.MONSTER_RARITY_MULTIPLIER:
			return "monster rarity"
		StatIds.PICKUP_RANGE:
			return "pickup range"
		StatIds.INSTANT_PICKUP_CHANCE:
			return "instant pickup chance"
		_:
			return String(stat_id).replace("_", " ")
