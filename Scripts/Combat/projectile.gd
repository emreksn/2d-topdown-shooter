class_name Projectile
extends Area2D

@export_range(0.0, 5000.0, 10.0, "or_greater") var speed: float = 650.0
@export var arena_bounds := Rect2(-800.0, -500.0, 1600.0, 1000.0)
@export_range(0.0, 1000.0, 1.0, "or_greater") var arena_exit_margin: float = 96.0
@export_range(0.1, 60.0, 0.1, "or_greater") var failsafe_lifetime: float = 10.0

var _direction := Vector2.RIGHT
var _damage_packet: DamagePacket
var _has_hit: bool = false

func _ready() -> void:
	_resolve_arena_bounds()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(
	direction: Vector2,
	damage_packet: DamagePacket,
	resolved_speed: float
) -> void:
	_direction = direction.normalized()
	_damage_packet = damage_packet
	speed = resolved_speed
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	failsafe_lifetime -= delta
	if failsafe_lifetime <= 0.0 or _is_outside_arena():
		queue_free()

func _resolve_arena_bounds() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var arena := scene.find_child("Arena", true, false) as Polygon2D
	if arena == null or arena.polygon.is_empty():
		return
	var first_point: Vector2 = arena.global_transform * arena.polygon[0]
	var resolved := Rect2(first_point, Vector2.ZERO)
	for point in arena.polygon:
		resolved = resolved.expand(arena.global_transform * point)
	arena_bounds = resolved

func _is_outside_arena() -> bool:
	return not arena_bounds.grow(arena_exit_margin).has_point(global_position)

func _on_area_entered(area: Area2D) -> void:
	if _has_hit or not area is Hurtbox:
		return

	_has_hit = true
	var hurtbox := area as Hurtbox
	hurtbox.receive_damage(_damage_packet)
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
