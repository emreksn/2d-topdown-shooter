class_name ContactDamageComponent
extends Area2D

@export_range(0.0, 1000000.0, 1.0, "or_greater") var damage: float = 10.0
@export_range(0.05, 60.0, 0.05, "or_greater") var hit_interval: float = 0.5

var _target_cooldowns: Dictionary[Hurtbox, float] = {}
var _stat_component: StatComponent
var _status_effects: StatusEffectComponent

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	for sibling in get_parent().get_children():
		if sibling is StatComponent:
			_stat_component = sibling
		elif sibling is StatusEffectComponent:
			_status_effects = sibling
		if is_instance_valid(_stat_component) and is_instance_valid(_status_effects):
			break

func reset_for_pool_spawn() -> void:
	_target_cooldowns.clear()

func _physics_process(delta: float) -> void:
	for hurtbox in _target_cooldowns.keys():
		if not is_instance_valid(hurtbox):
			_target_cooldowns.erase(hurtbox)
			continue

		var cooldown: float = (
			_target_cooldowns[hurtbox]
			- delta * _get_action_speed_multiplier()
		)
		if cooldown <= 0.0:
			var resolved_damage := (
				_stat_component.get_stat(
					StatIds.MELEE_DAMAGE,
					[&"attack", &"melee", &"hit", &"monster"]
				)
				if is_instance_valid(_stat_component)
				else damage
			)
			var packet := DamageResolver.build_direct_packet(
				resolved_damage,
				DamageTypeIds.PHYSICAL,
				_stat_component,
				[&"attack", &"melee", &"hit", &"monster"],
				get_parent()
			)
			hurtbox.receive_damage(packet)
			cooldown = hit_interval

		_target_cooldowns[hurtbox] = cooldown

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		_target_cooldowns[area as Hurtbox] = 0.0

func _on_area_exited(area: Area2D) -> void:
	if area is Hurtbox:
		_target_cooldowns.erase(area as Hurtbox)

func _get_action_speed_multiplier() -> float:
	return (
		_status_effects.get_action_speed_multiplier()
		if is_instance_valid(_status_effects)
		else 1.0
	)
