class_name ContentOffer
extends RefCounted

var content: ContentDefinition
var variant: ContentVariantDefinition
var extra_modifiers: Array[ContentExtraModifierDefinition] = []

func _init(
	content_definition: ContentDefinition = null,
	variant_definition: ContentVariantDefinition = null,
	extra_modifier_definitions: Array[ContentExtraModifierDefinition] = []
) -> void:
	content = content_definition
	variant = variant_definition
	extra_modifiers = extra_modifier_definitions.duplicate()

func get_display_name() -> String:
	if content == null:
		return "No Extra Content"
	if variant == null or variant.display_name.is_empty():
		return content.display_name
	return "%s %s" % [variant.display_name, content.display_name]

func apply_to_wave(definition: WaveDefinition) -> void:
	if definition == null or content == null:
		return
	content.apply_to_wave(definition)
	if variant != null:
		variant.apply_to_wave(definition)
	for extra_modifier in extra_modifiers:
		if extra_modifier != null:
			extra_modifier.apply_to_wave(definition)

func get_grant_heading() -> String:
	return "%s Grants:" % get_display_name()

func get_grant_lines() -> Array[String]:
	if content == null:
		return ["Start a normal wave."]
	var lines: Array[String] = []
	if variant != null:
		lines.append_array(variant.get_wave_change_lines())
		lines.append_array(variant.get_grant_lines())
	if lines.is_empty() and not content.description.is_empty():
		lines.append(content.description)
	return lines

func get_extra_lines() -> Array[String]:
	var lines: Array[String] = []
	if variant != null:
		lines.append_array(variant.get_extra_lines())
	for extra_modifier in extra_modifiers:
		if extra_modifier == null:
			continue
		var modifier_lines := extra_modifier.get_lines()
		if extra_modifier.display_name.is_empty():
			lines.append_array(modifier_lines)
		else:
			lines.append("%s:" % extra_modifier.display_name)
			lines.append_array(modifier_lines)
	return lines
