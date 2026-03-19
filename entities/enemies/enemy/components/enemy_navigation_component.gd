extends Node
class_name EnemyNavigationComponent

var enemy: Enemy
var movement_component: MovementComponent
var navigation_agent: NavigationAgent2D

func setup(owner_enemy: Enemy, owner_movement_component: MovementComponent, owner_navigation_agent: NavigationAgent2D) -> void:
	enemy = owner_enemy
	movement_component = owner_movement_component
	navigation_agent = owner_navigation_agent

func _configure_navigation_agent() -> void:
	navigation_agent.path_desired_distance = enemy.path_desired_distance
	navigation_agent.target_desired_distance = enemy.target_desired_distance
	navigation_agent.avoidance_enabled = enemy.avoidance_enabled
	navigation_agent.radius = enemy.agent_radius
	navigation_agent.neighbor_distance = enemy.neighbor_distance
	navigation_agent.max_neighbors = enemy.max_neighbors
	navigation_agent.time_horizon_agents = enemy.time_horizon
	navigation_agent.max_speed = movement_component.get_move_speed()
	if not navigation_agent.velocity_computed.is_connected(_on_navigation_agent_velocity_computed):
		navigation_agent.velocity_computed.connect(_on_navigation_agent_velocity_computed)

func _set_navigation_target(requested_position: Vector2, force_repath: bool = false) -> void:
	var next_target: Vector2 = _get_closest_navigation_point(requested_position)
	var should_repath: bool = force_repath
	should_repath = should_repath or not enemy.has_navigation_target
	should_repath = should_repath or enemy.navigation_repath_remaining <= 0.0
	should_repath = should_repath or enemy.navigation_target_position.distance_to(next_target) >= enemy.target_refresh_distance

	if not should_repath:
		return

	enemy.has_navigation_target = true
	enemy.navigation_target_position = next_target
	enemy.navigation_repath_remaining = enemy.repath_interval
	navigation_agent.target_position = enemy.navigation_target_position

func _follow_navigation(speed_scale: float = 1.0) -> void:
	if not enemy.has_navigation_target:
		movement_component.set_move_direction(Vector2.ZERO)
		return

	navigation_agent.max_speed = movement_component.get_move_speed() * maxf(speed_scale, 0.0)

	# Godot 4 expects get_next_path_position() during physics so the internal
	# path state advances correctly as the agent moves between corners.
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	if navigation_agent.is_navigation_finished():
		enemy._clear_navigation_motion()
		return

	var to_next_point: Vector2 = next_path_position - enemy.global_position
	if to_next_point.length_squared() <= 0.01:
		enemy._clear_navigation_motion()
		return

	var desired_velocity: Vector2 = to_next_point.normalized() * navigation_agent.max_speed
	navigation_agent.velocity = desired_velocity

	# Local avoidance still runs through NavigationAgent2D; the main enemy body
	# only receives the final movement direction after the safe velocity is chosen.
	var applied_velocity: Vector2 = enemy.safe_navigation_velocity if navigation_agent.avoidance_enabled else desired_velocity
	if applied_velocity == Vector2.ZERO:
		applied_velocity = desired_velocity

	enemy._update_facing(applied_velocity.normalized())
	var move_speed: float = maxf(movement_component.get_move_speed(), 0.001)
	movement_component.set_move_direction(applied_velocity / move_speed)

func _stop_navigation() -> void:
	enemy.has_navigation_target = false
	enemy._clear_navigation_motion()

func _get_closest_navigation_point(requested_position: Vector2) -> Vector2:
	var navigation_map: RID = navigation_agent.get_navigation_map()
	if navigation_map.is_valid():
		return NavigationServer2D.map_get_closest_point(navigation_map, requested_position)
	return requested_position

func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	enemy.safe_navigation_velocity = safe_velocity
