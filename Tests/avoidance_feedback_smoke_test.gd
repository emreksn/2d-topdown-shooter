extends SceneTree

func _initialize() -> void:
	if not await _test_evade_and_deflect_feedback_text():
		return
	print("avoidance_feedback_smoke_test: PASS")
	quit(0)

func _test_evade_and_deflect_feedback_text() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world

	var effects := Node2D.new()
	effects.add_to_group(&"effects_container")
	world.add_child(effects)

	var actor := Node2D.new()
	world.add_child(actor)

	var emitter := DamageNumberEmitter.new()
	emitter.damage_number_scene = load("res://Scenes/Feedback/damage_number.tscn")
	actor.add_child(emitter)

	var evaded := DamageResult.new()
	evaded.was_evaded = true
	emitter._on_damage_resolved(evaded, 0.0, null)
	await process_frame
	if effects.get_child_count() != 1:
		return _fail("Evaded hit did not spawn feedback.")
	if _get_damage_number_text(effects.get_child(0)) != "EVADED":
		return _fail("Evaded hit feedback text was incorrect.")

	var deflected := DamageResult.new()
	deflected.was_deflected = true
	deflected.total_damage = 8.0
	deflected.life_damage = 8.0
	deflected.damage_by_type[DamageTypeIds.PHYSICAL] = 8.0
	emitter._on_damage_resolved(deflected, 8.0, null)
	await process_frame
	if effects.get_child_count() != 3:
		return _fail("Deflected hit should spawn status text and damage number.")
	if _get_damage_number_text(effects.get_child(1)) != "DEFLECTED":
		return _fail("Deflected hit feedback text was incorrect.")

	world.queue_free()
	await process_frame
	return true

func _get_damage_number_text(node: Node) -> String:
	var label := node.get_node_or_null("Label") as Label
	return label.text if label != null else ""

func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
