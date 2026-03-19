extends Node
class_name EnemyNavigationComponent

var enemy: Enemy
var movement_component: MovementComponent
var navigation_agent: NavigationAgent2D
var has_target_position: bool = false
var current_target_position: Vector2 = Vector2.ZERO

func setup(owner_enemy: Enemy, owner_movement_component: MovementComponent, owner_navigation_agent: NavigationAgent2D) -> void:
	enemy = owner_enemy
	movement_component = owner_movement_component
	navigation_agent = owner_navigation_agent

func configure_agent() -> void:
	if navigation_agent == null or movement_component == null:
		return

	navigation_agent.path_desired_distance = enemy.path_desired_distance
	navigation_agent.target_desired_distance = enemy.target_desired_distance
	navigation_agent.max_speed = movement_component.get_move_speed()
	navigation_agent.avoidance_enabled = false

func set_target_position(target: Vector2) -> void:
	if navigation_agent == null:
		return

	has_target_position = true
	current_target_position = target
	navigation_agent.target_position = target

func move_to_target(_delta: float, speed_scale: float = 1.0) -> void:
	if navigation_agent == null or movement_component == null or not has_target_position:
		stop()
		return

	navigation_agent.max_speed = movement_component.get_move_speed() * maxf(speed_scale, 0.0)
	if navigation_agent.is_navigation_finished():
		stop()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var movement_direction := _get_movement_direction(next_path_position)
	if movement_direction == Vector2.ZERO:
		return

	enemy.update_facing(movement_direction)
	movement_component.set_move_direction(movement_direction)

func stop() -> void:
	has_target_position = false
	current_target_position = Vector2.ZERO
	if movement_component != null:
		movement_component.set_move_direction(Vector2.ZERO)
	if navigation_agent != null:
		navigation_agent.velocity = Vector2.ZERO

func _get_movement_direction(next_path_position: Vector2) -> Vector2:
	var next_path_offset := next_path_position - enemy.global_position
	if next_path_offset.length_squared() > 0.01:
		return next_path_offset.normalized()

	var direct_offset := current_target_position - enemy.global_position
	if direct_offset.length_squared() <= 0.01:
		stop()
		return Vector2.ZERO

	return direct_offset.normalized()
