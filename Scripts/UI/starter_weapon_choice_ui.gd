class_name StarterWeaponChoiceUI
extends CanvasLayer

@export var weapon_loadout: WeaponLoadoutComponent
@export var starter_weapons: Array[WeaponDefinition] = []

var _root_panel: PanelContainer
var _choice_grid: GridContainer
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()
	_resolve_dependencies()
	_build_ui()
	get_viewport().size_changed.connect(_resize_panel)
	GameSettings.settings_changed.connect(_resize_panel)
	if _should_show_choice():
		_show_choice()
	else:
		_root_panel.visible = false

func _resolve_dependencies() -> void:
	if is_instance_valid(weapon_loadout):
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player != null:
		weapon_loadout = player.get_node_or_null(
			"WeaponLoadoutComponent"
		) as WeaponLoadoutComponent

func _build_ui() -> void:
	_root_panel = PanelContainer.new()
	UiPresentation.apply_panel_style(_root_panel)
	add_child(_root_panel)
	_resize_panel()

	var margin := MarginContainer.new()
	UiPresentation.apply_standard_margins(margin)
	_root_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "CHOOSE STARTING WEAPON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_heading(title, 26)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Pick the weapon that defines your opening build."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiPresentation.apply_body_label(subtitle, true, 14)
	layout.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 310.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)

	_choice_grid = GridContainer.new()
	_choice_grid.columns = 4
	_choice_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_grid.add_theme_constant_override("h_separation", 10)
	_choice_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_choice_grid)

	for definition in starter_weapons:
		if definition != null:
			_choice_grid.add_child(_make_weapon_button(definition))

func _resize_panel() -> void:
	UiPresentation.resize_center_panel(_root_panel, Vector2(980.0, 540.0))

func _should_show_choice() -> bool:
	return (
		is_instance_valid(weapon_loadout)
		and weapon_loadout.get_equipped_count() == 0
		and not starter_weapons.is_empty()
	)

func _show_choice() -> void:
	_root_panel.visible = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true

func _make_weapon_button(definition: WeaponDefinition) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220.0, 150.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var offer := WeaponOffer.create(
		definition,
		ItemDefinition.Rarity.COMMON,
		_random
	)
	button.text = "%s\n\n%s" % [
		definition.display_name,
		offer.get_stat_display_text()
	]
	button.tooltip_text = offer.get_stat_display_text()
	button.add_theme_font_size_override("font_size", 14)
	UiPresentation.apply_rarity_button_style(
		button,
		ItemDefinition.Rarity.COMMON
	)
	button.pressed.connect(_on_weapon_chosen.bind(definition))
	return button

func _on_weapon_chosen(definition: WeaponDefinition) -> void:
	if not is_instance_valid(weapon_loadout):
		return
	var offer := WeaponOffer.create(
		definition,
		ItemDefinition.Rarity.COMMON,
		_random
	)
	if not weapon_loadout.equip_offer(offer):
		return
	_root_panel.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
