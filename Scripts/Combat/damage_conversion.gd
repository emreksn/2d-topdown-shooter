class_name DamageConversion
extends Resource

enum Mode {
	CONVERT,
	GAIN_AS_EXTRA
}

enum Priority {
	SKILL,
	OTHER
}

@export var source_type: StringName = DamageTypeIds.PHYSICAL
@export var destination_type: StringName = DamageTypeIds.ELEMENTAL
@export_range(0.0, 1000.0, 0.1, "or_greater") var percentage: float = 0.0
@export var mode: Mode = Mode.CONVERT
@export var priority: Priority = Priority.OTHER

func is_valid_conversion() -> bool:
	return (
		percentage > 0.0
		and DamageTypeIds.is_valid_conversion(
			source_type,
			destination_type,
			mode == Mode.GAIN_AS_EXTRA
		)
	)
