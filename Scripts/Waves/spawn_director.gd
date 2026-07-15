class_name SpawnDirector
extends Node

const MONSTER_RARITY_NORMAL := Enemy.MonsterRarity.NORMAL
const MONSTER_RARITY_UNCOMMON := Enemy.MonsterRarity.UNCOMMON
const MONSTER_RARITY_RARE := Enemy.MonsterRarity.RARE
const MONSTER_RARITY_AUTO := -1
const MONSTER_RARITY_COST_MULTIPLIERS := {
	MONSTER_RARITY_NORMAL: 1,
	MONSTER_RARITY_UNCOMMON: 3,
	MONSTER_RARITY_RARE: 5
}
const MONSTER_RARITY_STAY_WEIGHT := 70.0
const MONSTER_RARITY_UNCOMMON_WEIGHT := 22.0
const MONSTER_RARITY_RARE_WEIGHT := 6.0
const MONSTER_RARITY_MULTIPLIER_STRENGTH := 1.0
const MONSTER_RARITY_MAX_EFFECTIVE_MULTIPLIER := 3.0
const NATURAL_DEFENSE_RATING_STEP_WAVES := 5
const NATURAL_DEFENSE_RATING_PER_STEP := 25.0
const NATURAL_RESISTANCE_STEP_WAVES := 10
const NATURAL_RESISTANCE_PER_STEP := 10.0
const UNCOMMON_RARITY_ARMOUR := 50.0
const UNCOMMON_RARITY_EVASION := 50.0
const RARE_RARITY_ARMOUR := 100.0
const RARE_RARITY_EVASION := 100.0
const RARITY_RESISTANCE_BONUS := 15.0

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
@export_range(1, 200, 1, "or_greater") var cleanup_free_batch_size: int = 24
@export_range(0, 512, 1, "or_greater") var max_pooled_enemies_per_scene: int = 96

var forced_monster_rarity: int = MONSTER_RARITY_AUTO
var forced_monster_rarity_upgrade: int = MONSTER_RARITY_AUTO
var forced_rare_modifier_ids: Array[StringName] = []
var forced_rare_modifier_count: int = -1

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
var _monster_base_health_multiplier: float = 1.0
var _discard_generation: int = 0
var _enemy_pools: Dictionary = {}
var _enemy_pool_keys: Dictionary = {}

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

func _exit_tree() -> void:
	for pool_value in _enemy_pools.values():
		var pool: Array[Node2D] = []
		pool.assign(pool_value)
		for enemy in pool:
			if is_instance_valid(enemy):
				enemy.queue_free()
	_enemy_pools.clear()
	_enemy_pool_keys.clear()

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
	_monster_base_health_multiplier = maxf(definition.monster_base_health_multiplier, 0.0)
	_wave_context_tags = [&"monster", StringName("wave_%d" % wave_number)]
	for tag in definition.context_tags:
		if not _wave_context_tags.has(tag):
			_wave_context_tags.append(tag)
	_wave_modifier_sources.clear()
	_add_natural_wave_defense_source(wave_number)
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
	_discard_generation += 1
	if not is_instance_valid(enemy_container):
		_active_enemy_ids.clear()
		active_enemy_count_changed.emit(active_enemy_count)
		return

	var enemies := enemy_container.get_children()
	if enemies.is_empty():
		_prune_inactive_enemies()
		return

	_discard_active_enemies_batched.call_deferred(
		enemies,
		_discard_generation
	)

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
	warning_duration: float = 0.0,
	rarity_roll: Dictionary = {},
	reward_multiplier_override: float = -1.0
) -> bool:
	if entry == null or entry.enemy_scene == null:
		return false
	var clamped_position := _clamp_to_arena(spawn_position)
	if warning_duration <= 0.0:
		return _spawn_enemy(
			entry,
			clamped_position,
			additional_tags,
			rarity_roll,
			reward_multiplier_override
		)

	var indicators: Array[Node2D] = []
	var indicator := _create_spawn_indicator(clamped_position)
	if indicator != null:
		indicator.configure(warning_duration)
		indicators.append(indicator)
	pack_warning_started.emit([clamped_position], warning_duration)
	_pending_packs.append({
		"time_remaining": warning_duration,
		"spawns": [{
			"entry": entry,
			"rarity_roll": (
				rarity_roll
				if not rarity_roll.is_empty()
				else _build_monster_rarity_roll(_get_forced_or_natural_rarity())
			),
			"budget_cost": 0,
			"reward_multiplier_override": reward_multiplier_override
		}],
		"positions": [clamped_position],
		"indicators": indicators,
		"additional_tags": additional_tags.duplicate()
	})
	return true

func get_monster_rarity_chances() -> Dictionary:
	return {
		&"uncommon": _get_base_uncommon_chance(),
		&"rare": _get_base_rare_chance(),
		&"upgrade_multiplier": _get_effective_monster_rarity_multiplier(),
		&"normal_upgrade_weights": _get_monster_rarity_upgrade_weights(MONSTER_RARITY_NORMAL)
	}

func get_bonus_spawn_position(additional_margin: float = 0.0) -> Vector2:
	return _choose_spawn_position(additional_margin)

func build_specific_monster_rarity_roll(rarity: int) -> Dictionary:
	return _build_monster_rarity_roll(
		clampi(rarity, MONSTER_RARITY_NORMAL, MONSTER_RARITY_RARE)
	)

func _finish_scheduling() -> void:
	if not _is_spawning:
		return
	_is_spawning = false
	spawning_finished.emit()

func _spawn_enemy(
	entry: EnemySpawnEntry,
	spawn_position: Vector2,
	additional_tags: Array[StringName] = [],
	rarity_roll: Dictionary = {},
	reward_multiplier_override: float = -1.0
) -> bool:
	var enemy := _acquire_enemy(entry.enemy_scene)
	if enemy == null:
		push_warning("EnemySpawnEntry scene must have a Node2D root.")
		return false

	_apply_monster_base_health_scaling(enemy)
	if rarity_roll.is_empty():
		rarity_roll = _build_monster_rarity_roll(_get_forced_or_natural_rarity())

	var context_tags := _wave_context_tags.duplicate()
	context_tags.append(&"pack")
	for tag in entry.tags:
		if not context_tags.has(tag):
			context_tags.append(tag)
	for tag in additional_tags:
		if not context_tags.has(tag):
			context_tags.append(tag)
	if not context_tags.has(rarity_roll["tag"]):
		context_tags.append(rarity_roll["tag"])
	var modifier_sources := _wave_modifier_sources.duplicate()
	var rarity_sources: Dictionary = rarity_roll["modifier_sources"]
	for source_id in rarity_sources:
		modifier_sources[source_id] = rarity_sources[source_id]
	if is_instance_valid(runtime_modifier_registry):
		var runtime_sources := runtime_modifier_registry.get_applicable_sources(
			&"monster",
			context_tags
		)
		for source_id in runtime_sources:
			modifier_sources[source_id] = runtime_sources[source_id]
	if enemy.has_method("configure_monster_rarity"):
		var modifier_names: Array[String] = []
		modifier_names.assign(rarity_roll["modifier_names"])
		enemy.configure_monster_rarity(
			rarity_roll["rarity"],
			rarity_roll["display_name"],
			modifier_names
		)
	if enemy.has_method("configure_spawn_context"):
		enemy.configure_spawn_context(
			context_tags,
			modifier_sources,
			runtime_modifier_registry
		)
	if enemy.has_method("configure_spawn_reward"):
		enemy.configure_spawn_reward(
			entry.cost,
			(
				reward_multiplier_override
				if reward_multiplier_override >= 0.0
				else float(rarity_roll["reward_multiplier"])
			),
			_wave_number
		)

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

func _apply_monster_base_health_scaling(enemy: Node) -> void:
	if is_equal_approx(_monster_base_health_multiplier, 1.0):
		return
	var stats := enemy.get_node_or_null("StatComponent") as StatComponent
	if stats == null:
		return
	var fallback := 0.0
	if stats.catalog != null:
		var definition := stats.catalog.get_definition(StatIds.MAXIMUM_HEALTH)
		if definition != null:
			fallback = definition.default_value
	var base_health := stats.get_base_stat(StatIds.MAXIMUM_HEALTH)
	if base_health <= 0.0:
		base_health = fallback
	if base_health <= 0.0:
		return
	var profile := (
		stats.base_profile.duplicate(true) as StatProfile
		if stats.base_profile != null
		else StatProfile.new()
	)
	_set_profile_base_value(
		profile,
		StatIds.MAXIMUM_HEALTH,
		base_health * _monster_base_health_multiplier
	)
	stats.base_profile = profile

func _set_profile_base_value(
	profile: StatProfile,
	stat_id: StringName,
	value: float
) -> void:
	for entry in profile.values:
		if entry != null and entry.stat_id == stat_id:
			entry.value = value
			return
	var entry := StatValue.new()
	entry.stat_id = stat_id
	entry.value = value
	profile.values.append(entry)

func _plan_scheduled_pack(pack: Dictionary) -> bool:
	var spawns: Array[Dictionary] = []
	spawns.assign(pack["spawns"])
	if spawns.is_empty():
		return false
	var pack_anchor := _choose_spawn_position(_pack_spread)
	var positions: Array[Vector2] = []
	for member_index: int in range(spawns.size()):
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
		_spawn_planned_pack(spawns, positions)
		_free_indicators(indicators)
	else:
		_pending_packs.append({
			"time_remaining": _spawn_warning_duration,
			"spawns": spawns,
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

	var planned_spawns := _plan_spawns_for_budget(definition.spawn_budget)
	planned_spawns.shuffle()

	var planned_packs: Array[Dictionary] = []
	while not planned_spawns.is_empty():
		var pack_spawns: Array[Dictionary] = []
		var desired_pack_size: int = _random.randi_range(
			_minimum_pack_size,
			_maximum_pack_size
		)
		while (
			pack_spawns.size() < desired_pack_size
			and not planned_spawns.is_empty()
		):
			pack_spawns.append(planned_spawns.pop_back())
		planned_packs.append({"spawns": pack_spawns})

	var window_count := ceili(
		spawn_duration / maxf(definition.spawn_window_duration, 0.1)
	)
	window_count = maxi(window_count, 1)
	for index: int in range(planned_packs.size()):
		var window_index := index % window_count
		var cycle_index := floori(float(index) / float(window_count))
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

func _plan_spawns_for_budget(budget: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var remaining_budget := budget
	var safety := 0
	while remaining_budget > 0 and safety < 10000:
		safety += 1
		var natural_rarity := _roll_budgeted_natural_rarity(remaining_budget)
		var entry := _choose_spawn_entry(
			remaining_budget,
			_get_monster_rarity_cost_multiplier(natural_rarity)
		)
		if entry == null:
			break
		var spawn_cost := entry.cost * _get_monster_rarity_cost_multiplier(natural_rarity)
		var final_rarity := _upgrade_monster_rarity(natural_rarity)
		result.append({
			"entry": entry,
			"rarity_roll": _build_monster_rarity_roll(final_rarity),
			"budget_cost": spawn_cost
		})
		remaining_budget -= spawn_cost
		_remaining_budget = maxi(_remaining_budget - spawn_cost, 0)
	return result

func _update_pending_packs(delta: float) -> void:
	for index in range(_pending_packs.size() - 1, -1, -1):
		var pack := _pending_packs[index]
		pack["time_remaining"] = float(pack["time_remaining"]) - delta
		if float(pack["time_remaining"]) > 0.0:
			continue

		var spawns: Array[Dictionary] = []
		spawns.assign(pack["spawns"])
		var positions: Array[Vector2] = []
		positions.assign(pack["positions"])
		var indicators: Array[Node2D] = []
		indicators.assign(pack["indicators"])
		var additional_tags: Array[StringName] = []
		if pack.has("additional_tags"):
			additional_tags.assign(pack["additional_tags"])
		_spawn_planned_pack(
			spawns,
			positions,
			additional_tags
		)
		_free_indicators(indicators)
		_pending_packs.remove_at(index)

func _spawn_planned_pack(
	spawns: Array[Dictionary],
	positions: Array[Vector2],
	additional_tags: Array[StringName] = []
) -> void:
	for index: int in range(mini(spawns.size(), positions.size())):
		var spawn := spawns[index]
		_spawn_enemy(
			spawn["entry"],
			positions[index],
			additional_tags,
			spawn["rarity_roll"],
			float(spawn.get("reward_multiplier_override", -1.0))
		)

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

func _acquire_enemy(enemy_scene: PackedScene) -> Node2D:
	if enemy_scene == null:
		return null
	var scene_key := _get_enemy_scene_key(enemy_scene)
	var pool: Array[Node2D] = []
	if _enemy_pools.has(scene_key):
		pool.assign(_enemy_pools[scene_key])

	while not pool.is_empty():
		var pooled := pool.pop_back() as Node2D
		_enemy_pools[scene_key] = pool
		if not is_instance_valid(pooled):
			continue
		if pooled.has_method("reset_for_pool_spawn"):
			pooled.reset_for_pool_spawn()
		return pooled

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return null
	if enemy.has_method("capture_pool_baseline"):
		enemy.capture_pool_baseline()
	_enemy_pool_keys[enemy.get_instance_id()] = scene_key
	if enemy.has_method("enable_pool_recycling"):
		enemy.enable_pool_recycling()
	if enemy.has_signal("recycle_requested"):
		var recycle_callable := Callable(self, "_on_enemy_recycle_requested")
		if not enemy.is_connected("recycle_requested", recycle_callable):
			enemy.connect("recycle_requested", recycle_callable)
	return enemy

func _release_enemy_to_pool(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy):
		return false
	var scene_key := String(_enemy_pool_keys.get(enemy.get_instance_id(), ""))
	if scene_key.is_empty() or max_pooled_enemies_per_scene <= 0:
		enemy.queue_free()
		return false

	var parent := enemy.get_parent()
	if parent != null:
		parent.remove_child(enemy)
	if enemy.has_method("reset_for_pool_spawn"):
		enemy.reset_for_pool_spawn()

	var pool: Array[Node2D] = []
	if _enemy_pools.has(scene_key):
		pool.assign(_enemy_pools[scene_key])
	if pool.size() >= max_pooled_enemies_per_scene:
		enemy.queue_free()
		return false
	pool.append(enemy)
	_enemy_pools[scene_key] = pool
	return true

func _get_enemy_scene_key(enemy_scene: PackedScene) -> String:
	if not enemy_scene.resource_path.is_empty():
		return enemy_scene.resource_path
	return str(enemy_scene.get_instance_id())

func _on_enemy_recycle_requested(enemy: Enemy) -> void:
	_release_enemy_to_pool(enemy)

func _discard_active_enemies_batched(
	enemies: Array[Node],
	generation: int
) -> void:
	var tree := get_tree()
	var batch_size := maxi(cleanup_free_batch_size, 1)
	for index: int in range(enemies.size()):
		if generation != _discard_generation:
			return
		var enemy := enemies[index]
		if is_instance_valid(enemy):
			var pooled_enemy := enemy as Node2D
			if not _release_enemy_to_pool(pooled_enemy):
				enemy.queue_free()
		if (
			tree != null
			and index < enemies.size() - 1
			and (index + 1) % batch_size == 0
		):
			await tree.process_frame

func _choose_spawn_entry(
	remaining_budget: int,
	rarity_cost_multiplier: int = 1
) -> EnemySpawnEntry:
	var candidates: Array[EnemySpawnEntry] = []
	var total_weight: float = 0.0

	for entry in _enemy_pool:
		if (
			entry != null
			and entry.is_available(
				_wave_number,
				floori(float(remaining_budget) / float(rarity_cost_multiplier))
			)
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

func _get_forced_or_natural_rarity() -> int:
	if forced_monster_rarity != MONSTER_RARITY_AUTO:
		return forced_monster_rarity
	return _upgrade_monster_rarity(_roll_natural_monster_rarity())

func _roll_natural_monster_rarity() -> int:
	var chances := get_monster_rarity_chances()
	var rare_chance := float(chances[&"rare"])
	var uncommon_chance := float(chances[&"uncommon"])
	if _random.randf() * 100.0 < rare_chance:
		return MONSTER_RARITY_RARE
	if _random.randf() * 100.0 < uncommon_chance:
		return MONSTER_RARITY_UNCOMMON
	return MONSTER_RARITY_NORMAL

func _roll_budgeted_natural_rarity(remaining_budget: int) -> int:
	var rarity := (
		forced_monster_rarity
		if forced_monster_rarity != MONSTER_RARITY_AUTO
		else _roll_natural_monster_rarity()
	)
	while rarity > MONSTER_RARITY_NORMAL and not _can_afford_rarity(remaining_budget, rarity):
		rarity -= 1
	return rarity

func _can_afford_rarity(remaining_budget: int, rarity: int) -> bool:
	var rarity_cost_multiplier := _get_monster_rarity_cost_multiplier(rarity)
	for entry in _enemy_pool:
		if (
			entry != null
			and entry.is_available(
				_wave_number,
				floori(float(remaining_budget) / float(rarity_cost_multiplier))
			)
		):
			return true
	return false

func _upgrade_monster_rarity(rarity: int) -> int:
	if forced_monster_rarity_upgrade != MONSTER_RARITY_AUTO:
		return clampi(
			maxi(rarity, forced_monster_rarity_upgrade),
			MONSTER_RARITY_NORMAL,
			MONSTER_RARITY_RARE
		)
	if rarity >= MONSTER_RARITY_RARE:
		return rarity

	var weights := _get_monster_rarity_upgrade_weights(rarity)
	var total_weight := 0.0
	for weighted_rarity in weights:
		total_weight += maxf(float(weights[weighted_rarity]), 0.0)
	if total_weight <= 0.0:
		return rarity

	var roll := _random.randf_range(0.0, total_weight)
	for weighted_rarity in [
		MONSTER_RARITY_NORMAL,
		MONSTER_RARITY_UNCOMMON,
		MONSTER_RARITY_RARE
	]:
		if not weights.has(weighted_rarity):
			continue
		roll -= maxf(float(weights[weighted_rarity]), 0.0)
		if roll <= 0.0:
			return int(weighted_rarity)
	return rarity

func _get_monster_rarity_upgrade_weights(rarity: int) -> Dictionary:
	var weights := {rarity: MONSTER_RARITY_STAY_WEIGHT}
	var multiplier_bonus := maxf(
		_get_effective_monster_rarity_multiplier() - 1.0,
		0.0
	)
	if multiplier_bonus <= 0.0:
		return weights

	for target_rarity in range(rarity + 1, MONSTER_RARITY_RARE + 1):
		var relative_index := target_rarity - rarity
		weights[target_rarity] = (
			_get_monster_rarity_base_weight(target_rarity)
			* multiplier_bonus
			* float(relative_index)
			* MONSTER_RARITY_MULTIPLIER_STRENGTH
		)
	return weights

func _get_monster_rarity_base_weight(rarity: int) -> float:
	match rarity:
		MONSTER_RARITY_UNCOMMON:
			return MONSTER_RARITY_UNCOMMON_WEIGHT
		MONSTER_RARITY_RARE:
			return MONSTER_RARITY_RARE_WEIGHT
	return MONSTER_RARITY_STAY_WEIGHT

func _get_monster_rarity_cost_multiplier(rarity: int) -> int:
	return int(MONSTER_RARITY_COST_MULTIPLIERS.get(rarity, 1))

func _build_monster_rarity_roll(rarity: int) -> Dictionary:
	match rarity:
		MONSTER_RARITY_UNCOMMON:
			return {
				"rarity": MONSTER_RARITY_UNCOMMON,
				"display_name": "Uncommon",
				"tag": &"uncommon",
				"reward_multiplier": 1.35,
				"modifier_sources": {
					&"monster_rarity:uncommon": _make_uncommon_modifier_set()
				},
				"modifier_names": []
			}
		MONSTER_RARITY_RARE:
			var rare_sources := {
				&"monster_rarity:rare": _make_rare_base_modifier_set()
			}
			var modifier_names := _roll_rare_modifier_names()
			for modifier_name in modifier_names:
				var modifier_id := _get_rare_modifier_id(modifier_name)
				rare_sources[StringName("monster_rare:%s" % modifier_id)] = (
					_make_rare_modifier_set(modifier_id)
				)
			return {
				"rarity": MONSTER_RARITY_RARE,
				"display_name": "Rare",
				"tag": &"rare",
				"reward_multiplier": 2.0,
				"modifier_sources": rare_sources,
				"modifier_names": modifier_names
			}
	return {
		"rarity": MONSTER_RARITY_NORMAL,
		"display_name": "Normal",
		"tag": &"normal",
		"reward_multiplier": 1.0,
		"modifier_sources": {},
		"modifier_names": []
	}

func _get_base_uncommon_chance() -> float:
	return clampf(float(_wave_number - 2) * 4.0, 0.0, 25.0)

func _get_base_rare_chance() -> float:
	return clampf(float(_wave_number - 5) * 2.0, 0.0, 12.0)

func _get_monster_rarity_multiplier() -> float:
	if not is_instance_valid(spawn_focus):
		return 1.0
	var stats := spawn_focus.get_node_or_null("StatComponent") as StatComponent
	if not is_instance_valid(stats):
		return 1.0
	return maxf(stats.get_stat(StatIds.MONSTER_RARITY_MULTIPLIER), 0.0)

func _get_effective_monster_rarity_multiplier() -> float:
	return clampf(
		_get_monster_rarity_multiplier(),
		0.0,
		MONSTER_RARITY_MAX_EFFECTIVE_MULTIPLIER
	)

func _roll_rare_modifier_names() -> Array[String]:
	var wanted_count := (
		forced_rare_modifier_count
		if forced_rare_modifier_count >= 0
		else _roll_rare_modifier_count()
	)
	if wanted_count <= 0:
		return []
	var available_names := (
		_get_forced_rare_modifier_names()
		if not forced_rare_modifier_ids.is_empty()
		else _get_all_rare_modifier_names()
	)
	available_names.shuffle()
	return available_names.slice(0, mini(wanted_count, available_names.size()))

func _roll_rare_modifier_count() -> int:
	if _wave_number >= 22:
		return 2
	if _wave_number >= 17:
		return 2 if _random.randf() < 0.4 else 1
	if _wave_number >= 13:
		return 1
	if _wave_number >= 9:
		return 1 if _random.randf() < 0.6 else 0
	if _wave_number >= 6:
		return 1 if _random.randf() < 0.3 else 0
	return 0

func _get_all_rare_modifier_names() -> Array[String]:
	return [
		"Armoured",
		"Elusive",
		"Resistant",
		"Brutal",
		"Arcane Barrier",
		"Swift"
	]

func _get_forced_rare_modifier_names() -> Array[String]:
	var result: Array[String] = []
	for modifier_id in forced_rare_modifier_ids:
		var modifier_name := _get_rare_modifier_name(modifier_id)
		if modifier_name != "" and not result.has(modifier_name):
			result.append(modifier_name)
	return result

func _get_rare_modifier_id(modifier_name: String) -> StringName:
	match modifier_name:
		"Armoured":
			return &"armoured"
		"Elusive":
			return &"elusive"
		"Resistant":
			return &"resistant"
		"Brutal":
			return &"brutal"
		"Arcane Barrier":
			return &"arcane_barrier"
		"Swift":
			return &"swift"
	return &""

func _get_rare_modifier_name(modifier_id: StringName) -> String:
	match modifier_id:
		&"armoured":
			return "Armoured"
		&"elusive":
			return "Elusive"
		&"resistant":
			return "Resistant"
		&"brutal":
			return "Brutal"
		&"arcane_barrier":
			return "Arcane Barrier"
		&"swift":
			return "Swift"
	return ""

func _make_uncommon_modifier_set() -> ModifierSet:
	return _make_modifier_set([
		_make_modifier(StatIds.MAXIMUM_HEALTH, StatModifier.Operation.INCREASED, 25.0),
		_make_modifier(StatIds.ARMOUR, StatModifier.Operation.FLAT, UNCOMMON_RARITY_ARMOUR),
		_make_modifier(StatIds.EVASION, StatModifier.Operation.FLAT, UNCOMMON_RARITY_EVASION),
		_make_modifier(StatIds.PHYSICAL_RESISTANCE, StatModifier.Operation.FLAT, RARITY_RESISTANCE_BONUS),
		_make_modifier(StatIds.ELEMENTAL_RESISTANCE, StatModifier.Operation.FLAT, RARITY_RESISTANCE_BONUS)
	])

func _make_rare_base_modifier_set() -> ModifierSet:
	return _make_modifier_set([
		_make_modifier(StatIds.MAXIMUM_HEALTH, StatModifier.Operation.INCREASED, 50.0),
		_make_modifier(StatIds.ARMOUR, StatModifier.Operation.FLAT, RARE_RARITY_ARMOUR),
		_make_modifier(StatIds.EVASION, StatModifier.Operation.FLAT, RARE_RARITY_EVASION),
		_make_modifier(StatIds.PHYSICAL_RESISTANCE, StatModifier.Operation.FLAT, RARITY_RESISTANCE_BONUS),
		_make_modifier(StatIds.ELEMENTAL_RESISTANCE, StatModifier.Operation.FLAT, RARITY_RESISTANCE_BONUS)
	])

func _make_rare_modifier_set(modifier_id: StringName) -> ModifierSet:
	match modifier_id:
		&"armoured":
			return _make_modifier_set([
				_make_modifier(StatIds.ARMOUR, StatModifier.Operation.FLAT, 150.0)
			])
		&"elusive":
			return _make_modifier_set([
				_make_modifier(StatIds.EVASION, StatModifier.Operation.FLAT, 150.0)
			])
		&"resistant":
			return _make_modifier_set([
				_make_modifier(StatIds.PHYSICAL_RESISTANCE, StatModifier.Operation.FLAT, 15.0),
				_make_modifier(StatIds.ELEMENTAL_RESISTANCE, StatModifier.Operation.FLAT, 15.0)
			])
		&"brutal":
			return _make_modifier_set([
				_make_modifier(StatIds.MELEE_DAMAGE, StatModifier.Operation.INCREASED, 25.0)
			])
		&"arcane_barrier":
			return _make_modifier_set([
				_make_modifier(StatIds.MAXIMUM_ARCANE_SHIELD, StatModifier.Operation.FLAT, 40.0)
			])
		&"swift":
			return _make_modifier_set([
				_make_modifier(StatIds.MOVEMENT_SPEED, StatModifier.Operation.MORE, 15.0)
			])
	return ModifierSet.new()

func _make_modifier_set(modifiers: Array[StatModifier]) -> ModifierSet:
	var modifier_set := ModifierSet.new()
	modifier_set.modifiers = modifiers
	return modifier_set

func _add_natural_wave_defense_source(wave_number: int) -> void:
	var rating_step := floori(float(wave_number) / float(NATURAL_DEFENSE_RATING_STEP_WAVES))
	var resistance_step := floori(float(wave_number) / float(NATURAL_RESISTANCE_STEP_WAVES))
	var rating_bonus := float(rating_step) * NATURAL_DEFENSE_RATING_PER_STEP
	var resistance_bonus := float(resistance_step) * NATURAL_RESISTANCE_PER_STEP
	var modifiers: Array[StatModifier] = []
	if rating_bonus > 0.0:
		modifiers.append(_make_modifier(StatIds.ARMOUR, StatModifier.Operation.FLAT, rating_bonus))
		modifiers.append(_make_modifier(StatIds.EVASION, StatModifier.Operation.FLAT, rating_bonus))
	if resistance_bonus > 0.0:
		modifiers.append(_make_modifier(
			StatIds.PHYSICAL_RESISTANCE,
			StatModifier.Operation.FLAT,
			resistance_bonus
		))
		modifiers.append(_make_modifier(
			StatIds.ELEMENTAL_RESISTANCE,
			StatModifier.Operation.FLAT,
			resistance_bonus
		))
	if modifiers.is_empty():
		return
	_wave_modifier_sources[StringName("wave:%d:natural_defenses" % wave_number)] = (
		_make_modifier_set(modifiers)
	)

func _make_modifier(
	stat_id: StringName,
	operation: StatModifier.Operation,
	value: float
) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = stat_id
	modifier.operation = operation
	modifier.value = value
	modifier.target_domain = &"monster"
	modifier.scope = StatModifier.Scope.GLOBAL
	return modifier

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
