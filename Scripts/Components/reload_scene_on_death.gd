class_name ReloadSceneOnDeath
extends Node

@export var health_component: HealthComponent
@export_range(0.0, 10.0, 0.1, "or_greater") var delay: float = 1.5
@export var replacement_scene: PackedScene
@export_file("*.tscn") var main_menu_scene_path := "res://Scenes/UI/main_menu.tscn"

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
	_show_death_feedback()
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = true
	await tree.create_timer(delay, true).timeout
	tree.paused = false

	if replacement_scene != null:
		tree.change_scene_to_packed(replacement_scene)
	else:
		tree.change_scene_to_file(main_menu_scene_path)

func _show_death_feedback() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.current_scene.add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var label := Label.new()
	label.text = "YOU DIED\nReturning to main menu..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.86, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(label)
