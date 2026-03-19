extends Node
class_name MovementComponent

@export_category("Movement")
@export var move_speed_stat_id: StringName = StatsIds.MOVE_SPEED
@export var acceleration_stat_id: StringName = StatsIds.ACCELERATION
@export var deceleration_stat_id: StringName = StatsIds.DECELERATION
@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var use_input_actions: bool = false
@export var left_action: StringName = &"left"
@export var right_action: StringName = &"right"
@export var up_action: StringName = &"up"
@export var down_action: StringName = &"down"
@export_node_path("CharacterBody2D") var body_path: NodePath
@export_node_path("StatsComponent") var stats_component_path: NodePath = ^"../StatsComponent"

var move_direction: Vector2 = Vector2.ZERO

@onready var body: CharacterBody2D = _resolve_body()
@onready var stats_component: StatsComponent = _resolve_stats_component()

func _ready() -> void:
	if body == null:
		push_warning("MovementComponent requires a CharacterBody2D parent or an assigned body_path.")

func physics_update(delta: float) -> void:
	if body == null:
		return

	if use_input_actions:
		move_direction = Input.get_vector(left_action, right_action, up_action, down_action)

	var move_speed := _get_stat_value(move_speed_stat_id, speed)
	var move_acceleration := _get_stat_value(acceleration_stat_id, acceleration)
	var move_deceleration := _get_stat_value(deceleration_stat_id, deceleration)

	var target_velocity: Vector2 = move_direction * move_speed
	var rate: float = move_acceleration if move_direction != Vector2.ZERO else move_deceleration
	body.velocity = body.velocity.move_toward(target_velocity, rate * delta)
	body.move_and_slide()

	if move_direction == Vector2.ZERO and body.velocity.length_squared() < 1.0:
		body.velocity = Vector2.ZERO

func decelerate_to_stop(delta: float) -> void:
	if body == null:
		return

	move_direction = Vector2.ZERO
	var move_deceleration := _get_stat_value(deceleration_stat_id, deceleration)
	body.velocity = body.velocity.move_toward(Vector2.ZERO, move_deceleration * delta)
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

func _resolve_stats_component() -> StatsComponent:
	if stats_component_path != NodePath():
		return get_node_or_null(stats_component_path) as StatsComponent
	return get_node_or_null("../StatsComponent") as StatsComponent

func _get_stat_value(stat_id: StringName, fallback_value: float) -> float:
	if stats_component == null:
		return fallback_value
	return stats_component.get_stat_value(stat_id, fallback_value)
