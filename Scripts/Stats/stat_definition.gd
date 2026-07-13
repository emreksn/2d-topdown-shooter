class_name StatDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var default_value: float = 0.0
@export var has_minimum: bool = false
@export var minimum: float = 0.0
@export var has_maximum: bool = false
@export var maximum: float = 0.0
@export var display_as_percentage: bool = false

func clamp_value(value: float) -> float:
	var result := value
	if has_minimum:
		result = maxf(result, minimum)
	if has_maximum:
		result = minf(result, maximum)
	return result
