class_name WaveDirector
extends Node

signal preparation_started(next_wave_number: int, duration: float)
signal wave_started(wave_number: int, definition: WaveDefinition)
signal wave_completed(wave_number: int)
signal end_wave_cleanup_started(wave_number: int)
signal end_wave_cleanup_completed(wave_number: int)
signal item_evaluation_started(wave_number: int)
signal item_evaluation_completed(wave_number: int)
signal level_up_choices_started(wave_number: int)
signal level_up_choices_completed(wave_number: int)
signal shop_started(completed_wave_number: int, next_wave_number: int)
signal shop_ended(next_wave_number: int)
signal content_choices_started(next_wave_number: int)
signal content_choices_completed(next_wave_number: int)
signal wave_time_changed(time_remaining: float)
signal remaining_enemies_changed(count: int)
signal run_completed

enum State {
	PREPARATION,
	ACTIVE,
	CLEARING,
	POST_WAVE,
	SHOP,
	CONTENT_CHOICE,
	FINISHED
}

@export var spawn_director: SpawnDirector
@export var content_manager: ContentManager
@export var player: Node2D
@export var wave_definitions: Array[WaveDefinition] = []
@export_range(0.0, 120.0, 0.5, "or_greater") var preparation_duration: float = 4.0
@export_range(0.0, 5.0, 0.05) var reward_collection_show_duration: float = 0.65
@export_range(0, 500, 1, "or_greater") var animated_auto_collect_limit: int = 40
@export var repeat_last_definition: bool = true
@export_range(0, 1000000, 1, "or_greater") var repeated_wave_budget_increase: int = 10
@export_range(0.0, 1000.0, 0.5, "or_greater") var monster_base_health_increase_per_wave: float = 10.0

var state: State = State.PREPARATION
var current_wave_number: int = 0
var time_remaining: float = 0.0

func _ready() -> void:
	if not is_instance_valid(spawn_director):
		spawn_director = _find_spawn_director()
	if not is_instance_valid(content_manager):
		content_manager = get_tree().get_first_node_in_group(
			&"content_manager"
		) as ContentManager
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node2D

	if not is_instance_valid(spawn_director):
		push_error("WaveDirector requires a SpawnDirector.")
		set_process(false)
		return

	spawn_director.active_enemy_count_changed.connect(_on_enemy_count_changed)
	call_deferred("_begin_initial_preparation")

func _process(delta: float) -> void:
	match state:
		State.PREPARATION:
			time_remaining = maxf(time_remaining - delta, 0.0)
			wave_time_changed.emit(time_remaining)
			if time_remaining <= 0.0:
				_start_next_wave()
		State.ACTIVE:
			time_remaining = maxf(time_remaining - delta, 0.0)
			wave_time_changed.emit(time_remaining)
			if time_remaining <= 0.0:
				spawn_director.stop_spawning()
				spawn_director.discard_active_enemies()
				state = State.CLEARING
				_try_complete_wave()
		State.CLEARING:
			_try_complete_wave()
		State.POST_WAVE:
			pass
		State.SHOP:
			pass
		State.CONTENT_CHOICE:
			pass
		State.FINISHED:
			pass

func _begin_initial_preparation() -> void:
	if wave_definitions.is_empty():
		push_error("WaveDirector has no WaveDefinition resources.")
		state = State.FINISHED
		return
	_begin_preparation()

func _begin_preparation() -> void:
	state = State.PREPARATION
	time_remaining = preparation_duration
	preparation_started.emit(current_wave_number + 1, preparation_duration)
	wave_time_changed.emit(time_remaining)

func _start_next_wave() -> void:
	var definition := _get_prepared_definition_for_wave(current_wave_number + 1)
	if definition == null:
		state = State.FINISHED
		run_completed.emit()
		return

	current_wave_number += 1
	state = State.ACTIVE
	time_remaining = definition.duration
	spawn_director.begin_wave(definition, current_wave_number)
	wave_started.emit(current_wave_number, definition)
	wave_time_changed.emit(time_remaining)

func _try_complete_wave() -> void:
	if state != State.CLEARING:
		return
	if spawn_director.active_enemy_count > 0:
		return

	state = State.POST_WAVE
	_complete_wave_after_cleanup.call_deferred(current_wave_number)

func _complete_wave_after_cleanup(completed_wave_number: int) -> void:
	wave_completed.emit(completed_wave_number)
	await _run_end_wave_cleanup(completed_wave_number)
	if current_wave_number != completed_wave_number or state != State.POST_WAVE:
		return
	await _resolve_item_evaluation(completed_wave_number)
	if current_wave_number != completed_wave_number or state != State.POST_WAVE:
		return
	await _resolve_pending_level_ups(completed_wave_number)
	if current_wave_number != completed_wave_number or state != State.POST_WAVE:
		return

	var next_wave_number := completed_wave_number + 1
	if _get_definition_for_wave(next_wave_number) == null:
		state = State.FINISHED
		run_completed.emit()
	else:
		state = State.SHOP
		shop_started.emit(completed_wave_number, next_wave_number)

func finish_shop_phase() -> void:
	if state != State.SHOP:
		return
	var next_wave_number := current_wave_number + 1
	shop_ended.emit(next_wave_number)
	if await _resolve_content_choice(next_wave_number):
		if state != State.CONTENT_CHOICE:
			return
	_begin_preparation()

func _run_end_wave_cleanup(completed_wave_number: int) -> void:
	end_wave_cleanup_started.emit(completed_wave_number)
	var animated_drops := _auto_collect_drops()
	if reward_collection_show_duration > 0.0:
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(reward_collection_show_duration).timeout
	await _wait_for_auto_collect_drops(animated_drops)
	end_wave_cleanup_completed.emit(completed_wave_number)

func _resolve_pending_level_ups(completed_wave_number: int) -> void:
	var level_up_director := get_tree().get_first_node_in_group(
		&"level_up_director"
	) as LevelUpDirector
	if (
		not is_instance_valid(level_up_director)
		or not level_up_director.has_pending_level_ups()
	):
		return
	level_up_choices_started.emit(completed_wave_number)
	level_up_director.begin_sequence()
	await level_up_director.sequence_completed
	level_up_choices_completed.emit(completed_wave_number)

func _resolve_item_evaluation(completed_wave_number: int) -> void:
	var evaluation_director: ItemEvaluationDirector = get_tree().get_first_node_in_group(
		&"item_evaluation_director"
	) as ItemEvaluationDirector
	if (
		not is_instance_valid(evaluation_director)
		or not evaluation_director.has_pending_items()
	):
		return
	item_evaluation_started.emit(completed_wave_number)
	evaluation_director.begin_evaluation(completed_wave_number)
	await evaluation_director.evaluation_completed
	item_evaluation_completed.emit(completed_wave_number)

func _resolve_content_choice(next_wave_number: int) -> bool:
	if (
		not is_instance_valid(content_manager)
		or not content_manager.has_choices()
	):
		return false
	state = State.CONTENT_CHOICE
	content_choices_started.emit(next_wave_number)
	content_manager.begin_selection(next_wave_number)
	await content_manager.selection_completed
	content_choices_completed.emit(next_wave_number)
	return true

func _auto_collect_drops() -> Array[Node]:
	var tree := get_tree()
	if tree == null:
		return []
	if not is_instance_valid(player):
		player = tree.get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(player):
		return []

	var drops := _get_collectable_drops()
	if drops.size() > animated_auto_collect_limit:
		_batch_collect_drops(drops)
		return []

	for drop in drops:
		if is_instance_valid(drop):
			drop.collect_for(player)
	return drops

func _batch_collect_drops(drops: Array[Node]) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not is_instance_valid(player):
		player = tree.get_first_node_in_group(&"player") as Node2D
	if not is_instance_valid(player):
		return

	var progression := player.get_node_or_null(
		"PlayerProgressionComponent"
	) as PlayerProgressionComponent
	var inventory := player.get_node_or_null(
		"PlayerInventoryComponent"
	) as PlayerInventoryComponent
	var evaluation_director := tree.get_first_node_in_group(
		&"item_evaluation_director"
	) as ItemEvaluationDirector

	var gold_total := 0
	var experience_total := 0.0
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		var reward_pickup := drop as RewardPickup
		if is_instance_valid(reward_pickup):
			if reward_pickup.reward_type == RewardPickup.RewardType.GOLD:
				gold_total += maxi(1, roundi(reward_pickup.amount))
			else:
				experience_total += reward_pickup.amount
			reward_pickup.queue_free()
			continue

		var item_pickup := drop as ItemPickup
		if is_instance_valid(item_pickup):
			if item_pickup.item != null:
				if is_instance_valid(evaluation_director):
					evaluation_director.queue_item(item_pickup.item)
				elif is_instance_valid(inventory):
					inventory.add_item(item_pickup.item)
			item_pickup.queue_free()
			continue

		if drop.has_method("collect_for"):
			drop.collect_for(player)

	if is_instance_valid(progression):
		if gold_total > 0:
			progression.add_gold(gold_total)
		if experience_total > 0.0:
			progression.add_experience(experience_total)

func _wait_for_auto_collect_drops(drops: Array[Node]) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if drops.is_empty():
		return
	var timeout := 1.0
	while timeout > 0.0 and _has_pending_collected_drops(drops):
		var step := 0.05
		await tree.create_timer(step).timeout
		timeout -= step

func _get_collectable_drops() -> Array[Node]:
	var tree := get_tree()
	if tree == null:
		return []
	var drops: Array[Node] = []
	var drop_containers := tree.get_nodes_in_group(&"drops_container")
	for container in drop_containers:
		if not is_instance_valid(container):
			continue
		for drop in container.get_children():
			if drop.has_method("collect_for"):
				drops.append(drop)
	return drops

func _has_pending_collected_drops(drops: Array[Node]) -> bool:
	for drop in drops:
		if (
			is_instance_valid(drop)
			and drop.is_inside_tree()
			and not drop.is_queued_for_deletion()
		):
			return true
	return false

func _get_definition_for_wave(wave_number: int) -> WaveDefinition:
	if wave_number <= wave_definitions.size():
		return wave_definitions[wave_number - 1]
	if repeat_last_definition and not wave_definitions.is_empty():
		return wave_definitions.back()
	return null

func _get_prepared_definition_for_wave(wave_number: int) -> WaveDefinition:
	var base_definition := _get_definition_for_wave(wave_number)
	if base_definition == null:
		return null
	var prepared_definition := base_definition.duplicate(true) as WaveDefinition
	if prepared_definition == null:
		return base_definition
	_apply_repeated_wave_budget_scaling(wave_number, prepared_definition)
	_apply_wave_monster_health_scaling(wave_number, prepared_definition)
	if is_instance_valid(content_manager):
		content_manager.apply_content_to_wave(wave_number, prepared_definition)
	return prepared_definition

func _apply_repeated_wave_budget_scaling(
	wave_number: int,
	definition: WaveDefinition
) -> void:
	if not repeat_last_definition:
		return
	if wave_definitions.is_empty():
		return
	if wave_number <= wave_definitions.size():
		return
	var repeated_wave_index := wave_number - wave_definitions.size()
	definition.spawn_budget += repeated_wave_index * repeated_wave_budget_increase

func _apply_wave_monster_health_scaling(
	wave_number: int,
	definition: WaveDefinition
) -> void:
	if definition == null or monster_base_health_increase_per_wave <= 0.0:
		return
	var increase := (
		float(maxi(wave_number - 1, 0))
		* monster_base_health_increase_per_wave
	)
	if increase <= 0.0:
		return
	definition.monster_base_health_multiplier *= 1.0 + increase / 100.0

func _find_spawn_director() -> SpawnDirector:
	for sibling in get_parent().get_children():
		if sibling is SpawnDirector:
			return sibling
	return null

func _on_enemy_count_changed(count: int) -> void:
	remaining_enemies_changed.emit(count)
	if state == State.CLEARING:
		_try_complete_wave()
