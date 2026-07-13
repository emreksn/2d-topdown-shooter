class_name RiftDirector
extends Node

@export var wave_director: WaveDirector
@export var spawn_director: SpawnDirector
@export var portal_container: Node2D
@export var portal_scene: PackedScene
@export var spawn_points_root: Node2D
@export_range(0.0, 30.0, 0.1) var first_portal_delay: float = 2.0

var _random := RandomNumberGenerator.new()
var _wave_token: int = 0
var _spawn_points: Array[Node2D] = []

func _ready() -> void:
	_random.randomize()
	call_deferred("_initialize")

func _initialize() -> void:
	if not is_instance_valid(wave_director):
		wave_director = get_tree().get_first_node_in_group(
			&"wave_director"
		) as WaveDirector
	if not is_instance_valid(spawn_director):
		spawn_director = get_node_or_null(
			"../SpawnDirector"
		) as SpawnDirector
	if not is_instance_valid(spawn_points_root):
		spawn_points_root = get_node_or_null(
			"../../World/RiftSpawnPoints"
		) as Node2D
	if not is_instance_valid(portal_container):
		portal_container = get_node_or_null(
			"../../World/Content"
		) as Node2D

	_spawn_points.clear()
	if is_instance_valid(spawn_points_root):
		for child in spawn_points_root.get_children():
			if child is Node2D:
				_spawn_points.append(child)

	if is_instance_valid(wave_director):
		wave_director.wave_started.connect(_on_wave_started)
	else:
		push_warning("RiftDirector has no WaveDirector.")
	if _spawn_points.is_empty():
		push_warning("RiftDirector has no spawn points.")

func _on_wave_started(
	_wave_number: int,
	definition: WaveDefinition
) -> void:
	_wave_token += 1
	if (
		definition == null
		or definition.rift_portal_count <= 0
		or _spawn_points.is_empty()
	):
		return
	_schedule_rifts(definition, _wave_token)

func _schedule_rifts(definition: WaveDefinition, token: int) -> void:
	var points := _spawn_points.duplicate()
	points.shuffle()
	var portal_count := mini(definition.rift_portal_count, points.size())
	var available_duration := maxf(
		definition.duration - first_portal_delay,
		0.0
	)
	var interval := (
		available_duration / float(portal_count)
		if portal_count > 1
		else 0.0
	)

	for index in portal_count:
		var delay := first_portal_delay if index == 0 else interval
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		if token != _wave_token:
			return
		_spawn_rift(points[index], definition)

func _spawn_rift(point: Node2D, definition: WaveDefinition) -> void:
	if (
		not is_instance_valid(point)
		or portal_scene == null
		or not is_instance_valid(spawn_director)
	):
		return

	var portal := portal_scene.instantiate() as RiftPortal
	if portal == null:
		push_warning("Rift portal scene must have a RiftPortal root.")
		return

	var parent := portal_container
	if not is_instance_valid(parent):
		parent = get_tree().current_scene
	parent.add_child(portal)
	portal.global_position = point.global_position

	var entries: Array[EnemySpawnEntry] = []
	for _index in definition.rift_monsters_per_portal:
		var entry := _choose_entry(definition.enemy_pool)
		if entry != null:
			entries.append(entry)
	portal.activate(spawn_director, entries)

func _choose_entry(pool: Array[EnemySpawnEntry]) -> EnemySpawnEntry:
	var candidates: Array[EnemySpawnEntry] = []
	var total_weight: float = 0.0
	for entry in pool:
		if entry != null and entry.enemy_scene != null:
			candidates.append(entry)
			total_weight += entry.weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null

	var roll := _random.randf_range(0.0, total_weight)
	for entry in candidates:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return candidates.back()
