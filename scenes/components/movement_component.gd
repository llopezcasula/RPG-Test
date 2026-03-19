class_name MovementComponent
extends Node

@export_category("Movement")
@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var input_left: StringName = &"left"
@export var input_right: StringName = &"right"
@export var input_up: StringName = &"up"
@export var input_down: StringName = &"down"

var move_direction: Vector2 = Vector2.ZERO

func get_input_direction() -> Vector2:
	move_direction = Input.get_vector(input_left, input_right, input_up, input_down)
	return move_direction

func move_body(body: CharacterBody2D, delta: float, direction: Vector2 = move_direction) -> Vector2:
	move_direction = direction.limit_length(1.0)

	var target_velocity: Vector2 = move_direction * speed
	var rate: float = acceleration if move_direction != Vector2.ZERO else deceleration
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)

	if move_direction == Vector2.ZERO and body.velocity.length_squared() < 1.0:
		body.velocity = Vector2.ZERO

	body.move_and_slide()
	return body.velocity

func stop_body(body: CharacterBody2D, delta: float) -> Vector2:
	return move_body(body, delta, Vector2.ZERO)
