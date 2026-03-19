extends Node
class_name MovementComponent

@export_category("Movement")
@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var use_input_actions: bool = false
@export var left_action: StringName = &"left"
@export var right_action: StringName = &"right"
@export var up_action: StringName = &"up"
@export var down_action: StringName = &"down"
@export_node_path("CharacterBody2D") var body_path: NodePath

var move_direction: Vector2 = Vector2.ZERO

@onready var body: CharacterBody2D = _resolve_body()

func _ready() -> void:
	if body == null:
		push_warning("MovementComponent requires a CharacterBody2D parent or an assigned body_path.")

func physics_update(delta: float) -> void:
	if body == null:
		return

	if use_input_actions:
		move_direction = Input.get_vector(left_action, right_action, up_action, down_action)

	var target_velocity: Vector2 = move_direction * speed
	var rate: float = acceleration if move_direction != Vector2.ZERO else deceleration
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
	body.move_and_slide()

	if move_direction == Vector2.ZERO and body.velocity.length_squared() < 1.0:
		body.velocity = Vector2.ZERO

func decelerate_to_stop(delta: float) -> void:
	if body == null:
		return

	move_direction = Vector2.ZERO
	body.velocity = body.velocity.move_toward(Vector2.ZERO, deceleration * delta)
	body.move_and_slide()

	if body.velocity.length_squared() < 1.0:
		body.velocity = Vector2.ZERO

func set_move_direction(direction: Vector2) -> void:
	move_direction = direction.limit_length(1.0)

func stop_immediately() -> void:
	move_direction = Vector2.ZERO
	if body != null:
		body.velocity = Vector2.ZERO

func get_move_direction() -> Vector2:
	return move_direction

func _resolve_body() -> CharacterBody2D:
	if body_path != NodePath():
		return get_node_or_null(body_path) as CharacterBody2D
	return get_parent() as CharacterBody2D
