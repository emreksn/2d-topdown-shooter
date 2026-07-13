class_name ContentDefinition
extends Resource

enum ContentKind {
	RIFT
}

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: ContentKind = ContentKind.RIFT

@export_category("Rift")
@export_range(0, 20, 1) var rift_portal_count: int = 3
@export_range(1, 20, 1) var rift_monsters_per_portal: int = 3

func apply_to_wave(definition: WaveDefinition) -> void:
	if definition == null:
		return
	match kind:
		ContentKind.RIFT:
			definition.rift_portal_count += rift_portal_count
			definition.rift_monsters_per_portal = maxi(
				definition.rift_monsters_per_portal,
				rift_monsters_per_portal
			)
