class_name ReloadSceneOnDeath
extends Node

@export var health_component: HealthComponent
@export_range(0.0, 10.0, 0.1, "or_greater") var delay: float = 0.75
@export var replacement_scene: PackedScene

var _death_handled: bool = false

func _ready() -> void:
	if not is_instance_valid(health_component):
		health_component = _find_health_component()

	if is_instance_valid(health_component):
		health_component.died.connect(_on_died)
	else:
		push_warning("ReloadSceneOnDeath has no HealthComponent.")

func _find_health_component() -> HealthComponent:
	var actor := get_parent()
	if actor == null:
		return null

	for sibling in actor.get_children():
		if sibling is HealthComponent:
			return sibling

	return null

func _on_died(_source: Node) -> void:
	if _death_handled:
		return

	_death_handled = true
	await get_tree().create_timer(delay).timeout

	if replacement_scene != null:
		get_tree().change_scene_to_packed(replacement_scene)
	else:
		get_tree().reload_current_scene()
