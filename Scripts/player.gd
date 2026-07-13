extends CharacterBody2D

@export var characterSpeed : float = 100.0
@export_category("Walk Squash")
@export_range(0.0, 0.25, 0.005) var walkSquashStrength: float = 0.08
@export_range(0.0, 30.0, 0.5) var walkSquashRate: float = 12.0
@export_range(0.0, 20.0, 0.5) var walkSquashTransitionSpeed: float = 8.0

var characterDirection: Vector2
var movementAmount: float = 0.0
var walkMaterial: ShaderMaterial
var dashVelocity := Vector2.ZERO
var dashTimeRemaining: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var statComponent: StatComponent = $StatComponent

func _ready() -> void:
	walkMaterial = sprite.material.duplicate() as ShaderMaterial
	sprite.material = walkMaterial
	walkMaterial.set_shader_parameter("squash_strength", walkSquashStrength)
	walkMaterial.set_shader_parameter("walk_speed", walkSquashRate)
	walkMaterial.set_shader_parameter("bottom_anchor", sprite.get_rect().end.y)

func _physics_process(delta: float) -> void:
	characterDirection = Vector2(
		int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")),
		int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	).normalized()

	var movementSpeed := (
		statComponent.get_stat(StatIds.MOVEMENT_SPEED)
		if is_instance_valid(statComponent)
		else characterSpeed
	)
	if dashTimeRemaining > 0.0:
		dashTimeRemaining = maxf(dashTimeRemaining - delta, 0.0)
		velocity = dashVelocity
		if dashTimeRemaining <= 0.0:
			dashVelocity = Vector2.ZERO
	else:
		velocity = characterDirection * movementSpeed
	move_and_slide()

	var targetMovementAmount := 0.0 if characterDirection.is_zero_approx() else 1.0
	movementAmount = move_toward(
		movementAmount,
		targetMovementAmount,
		delta * walkSquashTransitionSpeed
	)
	if walkMaterial != null:
		walkMaterial.set_shader_parameter("movement_amount", movementAmount)

func start_dash(
	direction: Vector2,
	distance: float,
	duration: float
) -> void:
	var dash_direction := direction.normalized()
	if dash_direction.is_zero_approx():
		dash_direction = Vector2.RIGHT
	var dash_duration := maxf(duration, 0.01)
	dashVelocity = dash_direction * (distance / dash_duration)
	dashTimeRemaining = dash_duration
