extends SceneTree

func _initialize() -> void:
	if not _test_weapon_tags(
		"res://Data/Weapons/pistol.tres",
		[&"attack", &"weapon", &"projectile", &"pistol"],
		&"pistol"
	):
		return
	if not _test_weapon_tags(
		"res://Data/Weapons/machine_gun.tres",
		[&"attack", &"weapon", &"projectile", &"machine_gun"],
		&"machine_gun"
	):
		return
	if not _test_weapon_tags(
		"res://Data/Weapons/shotgun.tres",
		[&"attack", &"weapon", &"projectile", &"shotgun"],
		&"shotgun"
	):
		return
	if not _test_weapon_tags(
		"res://Data/Weapons/op_test_pistol.tres",
		[&"attack", &"weapon", &"projectile", &"pistol", &"op_test_pistol"],
		&"op_test_pistol"
	):
		return

	print("weapon_definition_smoke_test: PASS")
	quit(0)

func _test_weapon_tags(
	definition_path: String,
	expected_tags: Array[StringName],
	family_tag: StringName
) -> bool:
	var definition := load(definition_path) as WeaponDefinition
	if definition == null:
		_fail("%s must load as a WeaponDefinition." % definition_path)
		return false
	if definition.weapon_scene == null:
		_fail("%s must reference a weapon scene." % definition_path)
		return false
	var weapon := definition.weapon_scene.instantiate() as Weapon
	if weapon == null:
		_fail("%s weapon scene must instantiate as a Weapon." % definition_path)
		return false
	weapon.weapon_definition = definition
	root.add_child(weapon)

	var tags := weapon.get_attack_tags()
	for expected_tag in expected_tags:
		if not tags.has(expected_tag):
			_fail("%s attack tags are missing %s." % [definition_path, expected_tag])
			return false

	if tags.has(&"hit"):
		_fail("%s attack tags should not include hit." % definition_path)
		return false
	if not weapon.has_weapon_tag(&"projectile"):
		_fail("%s should match the projectile weapon tag." % definition_path)
		return false
	if not weapon.has_weapon_tag(family_tag):
		_fail("%s should match its family weapon tag." % definition_path)
		return false
	if weapon.has_weapon_tag(&"hit"):
		_fail("%s should not match the hit tag." % definition_path)
		return false
	if weapon.has_weapon_tag(&"melee"):
		_fail("%s should not match the melee tag." % definition_path)
		return false

	weapon.free()
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
