class_name ContentManager
extends Node

signal choices_changed(options: Array)
signal selection_started(next_wave_number: int, options: Array)
signal selection_completed(next_wave_number: int, selected_offer: ContentOffer)

@export var available_content: Array[ContentDefinition] = []
@export var available_variants: Array[ContentVariantDefinition] = []
@export var available_extra_modifiers: Array[ContentExtraModifierDefinition] = []
@export_range(0, 3, 1) var extra_modifier_count: int = 1
@export_range(1, 4, 1) var offer_count: int = 2
@export var include_no_content_option: bool = true
@export_range(1, 1000, 1, "or_greater") var boss_content_unlock_wave: int = 11
@export_range(1, 1000, 1, "or_greater") var boss_milestone_interval: int = 10

var current_options: Array = []
var next_wave_number: int = 0

var _selected_offer_by_wave: Dictionary = {}
var _selection_active := false
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	_random.randomize()
	add_to_group(&"content_manager")

func has_choices() -> bool:
	return not available_content.is_empty() or include_no_content_option

func begin_selection(wave_number: int) -> bool:
	if not has_choices():
		return false
	next_wave_number = wave_number
	_selection_active = true
	_roll_options()
	selection_started.emit(next_wave_number, current_options)
	choices_changed.emit(current_options)
	return true

func choose_option(index: int) -> bool:
	if not _selection_active:
		return false
	if index < 0 or index >= current_options.size():
		return false

	var selected := current_options[index] as ContentOffer
	if selected != null and selected.content != null:
		_selected_offer_by_wave[next_wave_number] = selected
	else:
		_selected_offer_by_wave.erase(next_wave_number)

	_selection_active = false
	current_options.clear()
	selection_completed.emit(next_wave_number, selected)
	return true

func apply_content_to_wave(wave_number: int, definition: WaveDefinition) -> void:
	if definition == null:
		return
	var selected := _selected_offer_by_wave.get(wave_number) as ContentOffer
	_selected_offer_by_wave.erase(wave_number)
	if selected != null:
		selected.apply_to_wave(definition)

func _roll_options() -> void:
	current_options.clear()
	var pool: Array[ContentOffer] = []
	for content in available_content:
		if content != null and _is_content_available(content):
			var added_for_content := false
			for variant in available_variants:
				if variant != null and variant.can_apply_to(content):
					pool.append(
						ContentOffer.new(
							content,
							variant,
							_roll_extra_modifiers(content)
						)
					)
					added_for_content = true
			if not added_for_content:
				pool.append(
					ContentOffer.new(
						content,
						null,
						_roll_extra_modifiers(content)
					)
				)
	pool.shuffle()

	var wanted_count := mini(offer_count, pool.size())
	for index: int in range(wanted_count):
		current_options.append(pool[index])
	if include_no_content_option:
		current_options.append(ContentOffer.new())

func _is_content_available(content: ContentDefinition) -> bool:
	if content == null:
		return false
	if content.kind != ContentDefinition.ContentKind.BOSS:
		return true
	if next_wave_number < boss_content_unlock_wave:
		return false
	if boss_milestone_interval > 0 and next_wave_number % boss_milestone_interval == 0:
		return false
	return true

func _roll_extra_modifiers(
	content: ContentDefinition
) -> Array[ContentExtraModifierDefinition]:
	var result: Array[ContentExtraModifierDefinition] = []
	if extra_modifier_count <= 0:
		return result

	var candidates: Array[ContentExtraModifierDefinition] = []
	for extra_modifier in available_extra_modifiers:
		if extra_modifier != null and extra_modifier.can_apply_to(content):
			candidates.append(extra_modifier)
	candidates.shuffle()

	var wanted_count := mini(extra_modifier_count, candidates.size())
	for index: int in range(wanted_count):
		result.append(candidates[index])
	return result
