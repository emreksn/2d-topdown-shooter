class_name ContentExtraModifierDefinition
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var compatible_content_kinds: Array[ContentDefinition.ContentKind] = [
	ContentDefinition.ContentKind.RIFT
]

@export_category("Rift")
@export_range(-20, 20, 1) var rift_portal_count_delta: int = 0
@export_range(-20, 20, 1) var rift_monsters_per_portal_delta: int = 0

@export_category("Modifiers")
@export var modifier_set: ModifierSet

func can_apply_to(content: ContentDefinition) -> bool:
	return (
		content != null
		and compatible_content_kinds.has(content.kind)
	)

func apply_to_wave(definition: WaveDefinition) -> void:
	if definition == null:
		return
	definition.rift_portal_count = maxi(
		0,
		definition.rift_portal_count + rift_portal_count_delta
	)
	definition.rift_monsters_per_portal = maxi(
		1,
		definition.rift_monsters_per_portal + rift_monsters_per_portal_delta
	)
	if modifier_set != null:
		definition.monster_modifier_sets.append(modifier_set)

func get_lines() -> Array[String]:
	var lines: Array[String] = []
	if rift_portal_count_delta != 0:
		lines.append("%s to Rift portals" % _format_signed_int(rift_portal_count_delta))
	if rift_monsters_per_portal_delta != 0:
		lines.append("%s to Rift monsters per portal" % _format_signed_int(rift_monsters_per_portal_delta))
	if modifier_set != null:
		for modifier in modifier_set.modifiers:
			if modifier != null:
				lines.append(ItemDefinition._format_modifier_line(modifier))
	return lines

func _format_signed_int(value: int) -> String:
	if value >= 0:
		return "+%d" % value
	return "%d" % value
