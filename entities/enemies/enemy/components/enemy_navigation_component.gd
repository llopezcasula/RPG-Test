extends Node
class_name EnemyNavigationComponent

var enemy: Enemy
var movement_component: MovementComponent
var navigation_agent: NavigationAgent2D
var has_target_position: bool = false

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
	var movement_vector := next_path_position - enemy.global_position
	if movement_vector.length_squared() <= 0.01:
		stop()
		return

	var movement_direction := movement_vector.normalized()
	enemy.update_facing(movement_direction)
	movement_component.set_move_direction(movement_direction)

func stop() -> void:
	has_target_position = false
	if movement_component != null:
		movement_component.set_move_direction(Vector2.ZERO)
	if navigation_agent != null:
		navigation_agent.velocity = Vector2.ZERO
