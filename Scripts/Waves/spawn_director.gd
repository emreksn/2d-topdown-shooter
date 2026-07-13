class_name SpawnDirector
extends Node

signal enemy_spawned(enemy: Node2D)
signal active_enemy_count_changed(count: int)
signal spawning_finished
signal pack_warning_started(positions: Array[Vector2], duration: float)

@export var enemy_container: Node
@export var warning_container: Node
@export var spawn_focus: Node2D
@export var active_camera: Camera2D
@export var spawn_indicator_scene: PackedScene
@export var runtime_modifier_registry: RuntimeModifierRegistry
@export_range(0.0, 1000.0, 1.0) var offscreen_margin: float = 100.0
@export_range(0.0, 2000.0, 1.0) var minimum_focus_distance: float = 420.0
@export_range(0.0, 300.0, 1.0) var spawn_wall_margin: float = 48.0
@export var arena_bounds := Rect2(-770.0, -470.0, 1540.0, 940.0)
@export var debug_enemy_tracking: bool = false

var active_enemy_count: int:
	get:
		return _active_enemy_ids.size()

var _random := RandomNumberGenerator.new()
var _enemy_pool: Array[EnemySpawnEntry] = []
var _active_enemy_ids: Dictionary = {}
var _remaining_budget: int = 0
var _wave_number: int = 0
var _is_spawning: bool = false
var _minimum_pack_size: int = 1
var _maximum_pack_size: int = 1
var _pack_spread: float = 0.0
var _mix_enemy_types_within_pack: bool = false
var _spawn_warning_duration: float = 0.0
var _pending_packs: Array[Dictionary] = []
var _wave_context_tags: Array[StringName] = []
var _wave_modifier_sources: Dictionary = {}
var _is_clearing: bool = false
var _last_tracking_mismatch_count: int = -1
var _spawn_schedule: Array[Dictionary] = []
var _next_scheduled_pack_index: int = 0
var _elapsed_wave_time: float = 0.0
var _spawn_cutoff_time: float = 0.0

func _ready() -> void:
	_random.randomize()
	if not is_instance_valid(enemy_container):
		enemy_container = get_tree().get_first_node_in_group(&"enemies_container")
	if not is_instance_valid(warning_container):
		warning_container = get_tree().get_first_node_in_group(&"effects_container")
	if not is_instance_valid(spawn_focus):
		spawn_focus = get_tree().get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(active_camera) and is_instance_valid(spawn_focus):
		active_camera = spawn_focus.find_child(
			"Camera2D",
			true,
			false
		) as Camera2D
	if not is_instance_valid(runtime_modifier_registry):
		runtime_modifier_registry = get_tree().get_first_node_in_group(
			&"runtime_modifier_registry"
		) as RuntimeModifierRegistry

func _process(delta: float) -> void:
	_prune_inactive_enemies()
	_debug_report_tracking_mismatch()
	_update_pending_packs(delta)

	if not _is_spawning:
		return

	_elapsed_wave_time += delta
	while (
		_next_scheduled_pack_index < _spawn_schedule.size()
		and _elapsed_wave_time >= float(
			_spawn_schedule[_next_scheduled_pack_index]["time"]
		)
	):
		_plan_scheduled_pack(_spawn_schedule[_next_scheduled_pack_index])
		_next_scheduled_pack_index += 1
	if (
		_next_scheduled_pack_index >= _spawn_schedule.size()
		or _elapsed_wave_time >= _spawn_cutoff_time
	):
		_finish_scheduling()

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if (
		debug_enemy_tracking
		and key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_F9
	):
		dump_active_enemy_tracking("F9 debug dump")

func begin_wave(definition: WaveDefinition, wave_number: int) -> void:
	_cancel_pending_packs()
	_last_tracking_mismatch_count = -1
	_enemy_pool = definition.enemy_pool
	_remaining_budget = definition.spawn_budget
	_wave_number = wave_number
	_elapsed_wave_time = 0.0
	_next_scheduled_pack_index = 0
	_spawn_cutoff_time = maxf(
		0.0,
		definition.duration - definition.spawn_cutoff_before_end
	)
	_minimum_pack_size = mini(
		definition.minimum_pack_size,
		definition.maximum_pack_size
	)
	_maximum_pack_size = maxi(
		definition.minimum_pack_size,
		definition.maximum_pack_size
	)
	_pack_spread = definition.pack_spread
	_mix_enemy_types_within_pack = definition.mix_enemy_types_within_pack
	_spawn_warning_duration = definition.spawn_warning_duration
	_wave_context_tags = [&"monster", StringName("wave_%d" % wave_number)]
	for tag in definition.context_tags:
		if not _wave_context_tags.has(tag):
			_wave_context_tags.append(tag)
	_wave_modifier_sources.clear()
	_is_clearing = false
	for index: int in range(definition.monster_modifier_sets.size()):
		var modifier_set := definition.monster_modifier_sets[index]
		if modifier_set != null:
			_wave_modifier_sources[
				StringName("wave:%d:%d" % [wave_number, index])
			] = modifier_set
	_spawn_schedule = _build_spawn_schedule(definition)
	_is_spawning = true

func stop_spawning(cancel_pending: bool = true) -> void:
	var was_spawning := _is_spawning
	_is_spawning = false
	if cancel_pending:
		_cancel_pending_packs()
	if was_spawning:
		spawning_finished.emit()

func begin_clearing() -> void:
	_is_clearing = true
	if not is_instance_valid(enemy_container):
		return
	for enemy in enemy_container.get_children():
		_send_enemy_to_player(enemy)

func discard_active_enemies() -> void:
	stop_spawning(true)
	_is_clearing = false
	if is_instance_valid(enemy_container):
		for enemy in enemy_container.get_children():
			if is_instance_valid(enemy):
				enemy.queue_free()
	if not _active_enemy_ids.is_empty():
		_active_enemy_ids.clear()
		active_enemy_count_changed.emit(active_enemy_count)

func dump_active_enemy_tracking(reason: String = "debug dump") -> void:
	print("[SpawnDirector] %s" % reason)
	print(
		"[SpawnDirector] active_enemy_count=%d enemy_container=%s child_count=%d pending_packs=%d is_spawning=%s is_clearing=%s"
		% [
			active_enemy_count,
			_get_node_debug_path(enemy_container),
			enemy_container.get_child_count() if is_instance_valid(enemy_container) else -1,
			_pending_packs.size(),
			str(_is_spawning),
			str(_is_clearing)
		]
	)
	for enemy_id in _active_enemy_ids:
		var enemy := _active_enemy_ids[enemy_id] as Node
		print(_format_tracked_enemy(enemy_id, enemy))

func spawn_bonus_enemy(
	entry: EnemySpawnEntry,
	spawn_position: Vector2,
	additional_tags: Array[StringName] = [],
	warning_duration: float = 0.0
) -> bool:
	if entry == null or entry.enemy_scene == null:
		return false
	var clamped_position := _clamp_to_arena(spawn_position)
	if warning_duration <= 0.0:
		return _spawn_enemy(entry, clamped_position, additional_tags)

	var indicators: Array[Node2D] = []
	var indicator := _create_spawn_indicator(clamped_position)
	if indicator != null:
		indicator.configure(warning_duration)
		indicators.append(indicator)
	pack_warning_started.emit([clamped_position], warning_duration)
	_pending_packs.append({
		"time_remaining": warning_duration,
		"entries": [entry],
		"positions": [clamped_position],
		"indicators": indicators,
		"additional_tags": additional_tags.duplicate()
	})
	return true

func _finish_scheduling() -> void:
	if not _is_spawning:
		return
	_is_spawning = false
	spawning_finished.emit()

func _spawn_enemy(
	entry: EnemySpawnEntry,
	spawn_position: Vector2,
	additional_tags: Array[StringName] = []
) -> bool:
	var enemy := entry.enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_warning("EnemySpawnEntry scene must have a Node2D root.")
		return false

	var context_tags := _wave_context_tags.duplicate()
	context_tags.append(&"pack")
	for tag in entry.tags:
		if not context_tags.has(tag):
			context_tags.append(tag)
	for tag in additional_tags:
		if not context_tags.has(tag):
			context_tags.append(tag)
	var modifier_sources := _wave_modifier_sources.duplicate()
	if is_instance_valid(runtime_modifier_registry):
		var runtime_sources := runtime_modifier_registry.get_applicable_sources(
			&"monster",
			context_tags
		)
		for source_id in runtime_sources:
			modifier_sources[source_id] = runtime_sources[source_id]
	if enemy.has_method("configure_spawn_context"):
		enemy.configure_spawn_context(
			context_tags,
			modifier_sources,
			runtime_modifier_registry
		)
	if enemy.has_method("configure_spawn_reward"):
		enemy.configure_spawn_reward(entry.cost, 1.0, _wave_number)

	var parent_node := enemy_container if is_instance_valid(enemy_container) else get_tree().current_scene
	parent_node.add_child(enemy)
	enemy.global_position = spawn_position
	if _is_clearing:
		_send_enemy_to_player(enemy)

	var enemy_id := enemy.get_instance_id()
	_active_enemy_ids[enemy_id] = enemy
	enemy.tree_exited.connect(_on_enemy_exited.bind(enemy_id), CONNECT_ONE_SHOT)

	enemy_spawned.emit(enemy)
	active_enemy_count_changed.emit(active_enemy_count)
	return true

func _plan_scheduled_pack(pack: Dictionary) -> bool:
	var entries: Array[EnemySpawnEntry] = []
	entries.assign(pack["entries"])
	if entries.is_empty():
		return false
	var pack_anchor := _choose_spawn_position(_pack_spread)
	var positions: Array[Vector2] = []
	for member_index: int in range(entries.size()):
		var offset := Vector2.ZERO
		if member_index > 0 and _pack_spread > 0.0:
			offset = Vector2.from_angle(
				_random.randf_range(0.0, TAU)
			) * _random.randf_range(_pack_spread * 0.35, _pack_spread)

		positions.append(_clamp_to_arena(pack_anchor + offset))

	var indicators: Array[Node2D] = []
	for spawn_position in positions:
		var indicator := _create_spawn_indicator(spawn_position)
		if indicator != null:
			indicators.append(indicator)

	pack_warning_started.emit(positions, _spawn_warning_duration)

	if _spawn_warning_duration <= 0.0:
		_spawn_planned_pack(entries, positions)
		_free_indicators(indicators)
	else:
		_pending_packs.append({
			"time_remaining": _spawn_warning_duration,
			"entries": entries,
			"positions": positions,
			"indicators": indicators,
			"additional_tags": []
		})

	return true

func _build_spawn_schedule(definition: WaveDefinition) -> Array[Dictionary]:
	var spawn_duration := maxf(
		0.0,
		definition.duration - definition.spawn_cutoff_before_end
	)
	if spawn_duration <= 0.0 or definition.spawn_budget <= 0:
		return []

	var normal_budget := definition.spawn_budget
	var elite_budget := 0
	if definition.elite_budget_share > 0.0:
		elite_budget = roundi(
			float(definition.spawn_budget)
			* clampf(definition.elite_budget_share, 0.0, 1.0)
		)
		normal_budget = maxi(definition.spawn_budget - elite_budget, 0)

	var planned_entries: Array[EnemySpawnEntry] = []
	planned_entries.append_array(
		_plan_entries_for_role(EnemySpawnEntry.SpawnRole.NORMAL, normal_budget)
	)
	planned_entries.append_array(
		_plan_entries_for_role(EnemySpawnEntry.SpawnRole.ELITE, elite_budget)
	)
	planned_entries.shuffle()

	var planned_packs: Array[Dictionary] = []
	while not planned_entries.is_empty():
		var pack_entries: Array[EnemySpawnEntry] = []
		var desired_pack_size: int = _random.randi_range(
			_minimum_pack_size,
			_maximum_pack_size
		)
		while (
			pack_entries.size() < desired_pack_size
			and not planned_entries.is_empty()
		):
			pack_entries.append(planned_entries.pop_back())
		planned_packs.append({"entries": pack_entries})

	var window_count := ceili(
		spawn_duration / maxf(definition.spawn_window_duration, 0.1)
	)
	window_count = maxi(window_count, 1)
	for index: int in range(planned_packs.size()):
		var window_index := index % window_count
		var cycle_index := index / window_count
		var cycle_count := ceili(float(planned_packs.size()) / float(window_count))
		var window_start := (
			float(window_index)
			* maxf(definition.spawn_window_duration, 0.1)
		)
		var window_span := minf(
			maxf(definition.spawn_window_duration, 0.1),
			spawn_duration - window_start
		)
		var window_offset := (
			0.0
			if cycle_count <= 1
			else window_span * float(cycle_index) / float(cycle_count)
		)
		planned_packs[index]["time"] = clampf(
			window_start + window_offset,
			0.0,
			spawn_duration
		)
	planned_packs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"])
	)
	return planned_packs

func _get_pack_time(
	index: int,
	pack_count: int,
	spawn_duration: float
) -> float:
	if pack_count <= 1:
		return 0.0
	var t := float(index) / float(pack_count - 1)
	return clampf(t * spawn_duration, 0.0, spawn_duration)

func _plan_entries_for_role(
	role: EnemySpawnEntry.SpawnRole,
	budget: int
) -> Array[EnemySpawnEntry]:
	var result: Array[EnemySpawnEntry] = []
	var remaining_budget := budget
	var safety := 0
	while remaining_budget > 0 and safety < 10000:
		safety += 1
		var entry := _choose_spawn_entry_for_role(role, remaining_budget)
		if entry == null:
			break
		result.append(entry)
		remaining_budget -= entry.cost
		_remaining_budget = maxi(_remaining_budget - entry.cost, 0)
	return result

func _update_pending_packs(delta: float) -> void:
	for index in range(_pending_packs.size() - 1, -1, -1):
		var pack := _pending_packs[index]
		pack["time_remaining"] = float(pack["time_remaining"]) - delta
		if float(pack["time_remaining"]) > 0.0:
			continue

		var entries: Array[EnemySpawnEntry] = []
		entries.assign(pack["entries"])
		var positions: Array[Vector2] = []
		positions.assign(pack["positions"])
		var indicators: Array[Node2D] = []
		indicators.assign(pack["indicators"])
		var additional_tags: Array[StringName] = []
		if pack.has("additional_tags"):
			additional_tags.assign(pack["additional_tags"])
		_spawn_planned_pack(
			entries,
			positions,
			additional_tags
		)
		_free_indicators(indicators)
		_pending_packs.remove_at(index)

func _spawn_planned_pack(
	entries: Array[EnemySpawnEntry],
	positions: Array[Vector2],
	additional_tags: Array[StringName] = []
) -> void:
	for index: int in range(mini(entries.size(), positions.size())):
		_spawn_enemy(entries[index], positions[index], additional_tags)

func _create_spawn_indicator(spawn_position: Vector2) -> SpawnIndicator:
	if spawn_indicator_scene == null:
		return null

	var indicator := spawn_indicator_scene.instantiate() as SpawnIndicator
	if indicator == null:
		push_warning("Spawn indicator scene must have a SpawnIndicator root.")
		return null

	var parent_node := warning_container if is_instance_valid(warning_container) else get_tree().current_scene
	parent_node.add_child(indicator)
	indicator.global_position = spawn_position
	indicator.configure(_spawn_warning_duration)
	return indicator

func _cancel_pending_packs() -> void:
	for pack in _pending_packs:
		var indicators: Array[Node2D] = []
		indicators.assign(pack["indicators"])
		_free_indicators(indicators)
	_pending_packs.clear()

func _free_indicators(indicators: Array[Node2D]) -> void:
	for indicator in indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()

func _choose_spawn_entry_for_role(
	role: EnemySpawnEntry.SpawnRole,
	remaining_budget: int
) -> EnemySpawnEntry:
	var candidates: Array[EnemySpawnEntry] = []
	var total_weight: float = 0.0

	for entry in _enemy_pool:
		if (
			entry != null
			and entry.spawn_role == role
			and entry.is_available(_wave_number, remaining_budget)
		):
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

func _choose_spawn_position(additional_margin: float = 0.0) -> Vector2:
	var center := Vector2.ZERO
	if is_instance_valid(active_camera):
		center = active_camera.global_position
	elif is_instance_valid(spawn_focus):
		center = spawn_focus.global_position

	var viewport_size := get_viewport().get_visible_rect().size
	var camera_zoom := Vector2.ONE
	if is_instance_valid(active_camera):
		camera_zoom = active_camera.zoom.abs()

	var half_view := Vector2(
		viewport_size.x / maxf(camera_zoom.x, 0.001),
		viewport_size.y / maxf(camera_zoom.y, 0.001)
	) * 0.5
	var extent := (
		half_view
		+ Vector2.ONE * (offscreen_margin + additional_margin)
	)

	var position: Vector2
	match _random.randi_range(0, 3):
		0:
			position = center + Vector2(
				_random.randf_range(-extent.x, extent.x),
				-extent.y
			)
		1:
			position = center + Vector2(
				extent.x,
				_random.randf_range(-extent.y, extent.y)
			)
		2:
			position = center + Vector2(
				_random.randf_range(-extent.x, extent.x),
				extent.y
			)
		_:
			position = center + Vector2(
				-extent.x,
				_random.randf_range(-extent.y, extent.y)
			)

	if is_instance_valid(spawn_focus):
		var from_focus := position - spawn_focus.global_position
		if from_focus.length_squared() < minimum_focus_distance * minimum_focus_distance:
			position = (
				spawn_focus.global_position
				+ from_focus.normalized() * minimum_focus_distance
			)

	return _clamp_to_arena(position)

func _send_enemy_to_player(enemy: Node) -> void:
	if (
		is_instance_valid(spawn_focus)
		and enemy.has_method("enter_wave_clearing")
	):
		enemy.enter_wave_clearing(spawn_focus)

func _clamp_to_arena(position: Vector2) -> Vector2:
	if arena_bounds.size.x <= 0.0 or arena_bounds.size.y <= 0.0:
		return position
	var spawn_bounds := arena_bounds.grow(-spawn_wall_margin)
	if spawn_bounds.size.x <= 0.0 or spawn_bounds.size.y <= 0.0:
		spawn_bounds = arena_bounds
	return Vector2(
		clampf(
			position.x,
			spawn_bounds.position.x,
			spawn_bounds.end.x
		),
		clampf(
			position.y,
			spawn_bounds.position.y,
			spawn_bounds.end.y
		)
	)

func _on_enemy_exited(enemy_id: int) -> void:
	if not _active_enemy_ids.erase(enemy_id):
		return
	if debug_enemy_tracking:
		print("[SpawnDirector] enemy exited id=%d remaining=%d" % [
			enemy_id,
			active_enemy_count
		])
	active_enemy_count_changed.emit(active_enemy_count)

func _prune_inactive_enemies() -> void:
	var stale_ids: Array[int] = []
	for enemy_id in _active_enemy_ids:
		var enemy := _active_enemy_ids[enemy_id] as Node
		if (
			not is_instance_valid(enemy)
			or not enemy.is_inside_tree()
			or enemy.is_queued_for_deletion()
		):
			stale_ids.append(enemy_id)

	if stale_ids.is_empty():
		return
	for enemy_id in stale_ids:
		_active_enemy_ids.erase(enemy_id)
	if debug_enemy_tracking:
		print("[SpawnDirector] pruned stale enemy ids=%s remaining=%d" % [
			str(stale_ids),
			active_enemy_count
		])
	active_enemy_count_changed.emit(active_enemy_count)

func _debug_report_tracking_mismatch() -> void:
	if not debug_enemy_tracking:
		return
	if active_enemy_count <= 0:
		_last_tracking_mismatch_count = -1
		return
	if not is_instance_valid(enemy_container):
		return
	var visible_child_count := enemy_container.get_child_count()
	if visible_child_count > 0:
		_last_tracking_mismatch_count = -1
		return
	if _last_tracking_mismatch_count == active_enemy_count:
		return
	_last_tracking_mismatch_count = active_enemy_count
	dump_active_enemy_tracking("tracked enemies exist but enemy container is empty")

func _format_tracked_enemy(enemy_id: int, enemy: Node) -> String:
	if not is_instance_valid(enemy):
		return "[SpawnDirector] tracked id=%d node=<invalid>" % enemy_id

	var node2d := enemy as Node2D
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	var health_text := "none"
	if is_instance_valid(health):
		health_text = "%.1f/%.1f" % [
			health.current_health,
			health.maximum_health
		]
	var position_text := (
		str(node2d.global_position)
		if is_instance_valid(node2d)
		else "n/a"
	)
	return (
		"[SpawnDirector] tracked id=%d name=%s path=%s parent=%s inside_tree=%s queued=%s pos=%s health=%s groups=%s"
		% [
			enemy_id,
			enemy.name,
			_get_node_debug_path(enemy),
			_get_node_debug_path(enemy.get_parent()),
			str(enemy.is_inside_tree()),
			str(enemy.is_queued_for_deletion()),
			position_text,
			health_text,
			str(enemy.get_groups())
		]
	)

func _get_node_debug_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<invalid>"
	if not node.is_inside_tree():
		return "<outside-tree:%s>" % node.name
	return str(node.get_path())
