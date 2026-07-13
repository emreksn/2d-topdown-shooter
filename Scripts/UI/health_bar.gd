class_name HealthBar
extends ProgressBar

@export var health_component: HealthComponent
@onready var value_label: Label = %ValueLabel

func _ready() -> void:
	if not is_instance_valid(health_component):
		health_component = _find_health_component()

	if not is_instance_valid(health_component):
		push_warning("HealthBar has no HealthComponent.")
		return

	health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(
		health_component.current_health,
		health_component.maximum_health
	)

func _find_health_component() -> HealthComponent:
	var ancestor := get_parent()
	while ancestor != null:
		for child in ancestor.get_children():
			if child is HealthComponent:
				return child
		ancestor = ancestor.get_parent()

	return null

func _on_health_changed(current_health: float, maximum_health: float) -> void:
	max_value = maximum_health
	value = current_health
	value_label.text = "%d / %d" % [
		ceili(current_health),
		ceili(maximum_health)
	]
