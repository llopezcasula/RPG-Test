extends Node
class_name EnemyNavigationComponent

# Runtime state
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
	if enemy == null or movement_component == null or navigation_agent == null:
		return

	navigation_agent.path_desired_distance = enemy.path_desired_distance
	navigation_agent.target_desired_distance = enemy.target_desired_distance
	navigation_agent.max_speed = movement_component.get_move_speed()
	navigation_agent.avoidance_enabled = false

func set_target_position(target: Vector2, force: bool = false) -> void:
	if navigation_agent == null:
		return

	if not force and has_target_position and current_target_position.distance_squared_to(target) <= 1.0:
		return

	has_target_position = true
	current_target_position = target
	navigation_agent.target_position = target

func move_to_target(_delta: float, speed_scale: float = 1.0) -> void:
	if enemy == null or movement_component == null or navigation_agent == null or not has_target_position:
		stop()
		return

	if navigation_agent.is_navigation_finished():
		stop()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var move_offset := next_path_position - enemy.global_position
	if move_offset.length_squared() <= 0.0001:
		stop()
		return

	var move_direction := move_offset.normalized() * clampf(speed_scale, 0.0, 1.0)
	enemy.update_facing(move_direction)
	movement_component.set_move_direction(move_direction)

func stop() -> void:
	has_target_position = false
	current_target_position = Vector2.ZERO
	if movement_component != null:
		movement_component.stop_immediately()
