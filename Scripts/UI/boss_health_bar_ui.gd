class_name BossHealthBarUI
extends CanvasLayer

@export var spawn_director: SpawnDirector

var _panel: PanelContainer
var _name_label: Label
var _bar: ProgressBar
var _value_label: Label
var _boss: Enemy
var _health: HealthComponent

func _ready() -> void:
	layer = 24
	_resolve_dependencies()
	_build_ui()
	_panel.visible = false
	if is_instance_valid(spawn_director):
		spawn_director.enemy_spawned.connect(_on_enemy_spawned)

func _resolve_dependencies() -> void:
	if not is_instance_valid(spawn_director):
		spawn_director = get_tree().get_first_node_in_group(
			&"spawn_director"
		) as SpawnDirector
	if not is_instance_valid(spawn_director):
		var systems := get_node_or_null("../Systems")
		if systems != null:
			spawn_director = systems.get_node_or_null("SpawnDirector") as SpawnDirector

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -320.0
	_panel.offset_right = 320.0
	_panel.offset_top = 24.0
	_panel.offset_bottom = 92.0
	UiPresentation.apply_panel_style(_panel)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_heading(_name_label, 18)
	layout.add_child(_name_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_bar.show_percentage = false
	UiPresentation.apply_progress_bar_style(_bar, Color(1.0, 0.28, 0.32, 1.0))
	layout.add_child(_bar)

	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_body_label(_value_label, true, 12)
	layout.add_child(_value_label)

func _on_enemy_spawned(enemy_node: Node2D) -> void:
	var enemy := enemy_node as Enemy
	if enemy == null or not enemy.spawn_tags.has(&"boss"):
		return
	_bind_boss(enemy)

func _bind_boss(enemy: Enemy) -> void:
	_disconnect_health()
	_boss = enemy
	_health = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if not is_instance_valid(_health):
		return
	_name_label.text = enemy.get_inspection_name()
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_boss_died)
	enemy.tree_exited.connect(_on_boss_exited, CONNECT_ONE_SHOT)
	_on_health_changed(_health.current_health, _health.maximum_health)
	_panel.visible = true

func _on_health_changed(current_health: float, maximum_health: float) -> void:
	_bar.max_value = maximum_health
	_bar.value = current_health
	_value_label.text = "%d / %d" % [ceili(current_health), ceili(maximum_health)]

func _on_boss_died(_source: Node) -> void:
	_hide()

func _on_boss_exited() -> void:
	_hide()

func _hide() -> void:
	_disconnect_health()
	_boss = null
	_health = null
	_panel.visible = false

func _disconnect_health() -> void:
	if not is_instance_valid(_health):
		return
	if _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	if _health.died.is_connected(_on_boss_died):
		_health.died.disconnect(_on_boss_died)
