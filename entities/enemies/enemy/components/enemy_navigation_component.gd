extends Node
class_name EnemyNavigationComponent

var enemy: Enemy
var movement_component: MovementComponent
var navigation_agent: NavigationAgent2D
var steering_component: EnemySteeringComponent

func setup(owner_enemy: Enemy, owner_movement_component: MovementComponent, owner_navigation_agent: NavigationAgent2D, owner_steering_component: EnemySteeringComponent) -> void:
	enemy = owner_enemy
	movement_component = owner_movement_component
	navigation_agent = owner_navigation_agent
	steering_component = owner_steering_component

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
	var next_target: Vector2 = requested_position
	var navigation_path: PackedVector2Array = _get_navigation_path_to(requested_position)
	if navigation_path.size() > 0:
		# Keep the requested world-space target whenever it is already reachable.
		# Snapping every target to the navmesh can bias the enemy toward an incorrect stop point.
		var path_endpoint: Vector2 = navigation_path[navigation_path.size() - 1]
		var endpoint_error: float = path_endpoint.distance_to(requested_position)
		if endpoint_error > enemy.target_desired_distance:
			next_target = path_endpoint
	elif _has_navigation_map():
		next_target = _get_closest_navigation_point(requested_position)

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

func _follow_navigation(speed_scale: float = 1.0, steering_context: Dictionary = {}) -> void:
	if not enemy.has_navigation_target:
		movement_component.set_move_direction(Vector2.ZERO)
		if steering_component != null:
			steering_component.clear_debug_data()
		return

	var move_speed: float = movement_component.get_move_speed()
	navigation_agent.max_speed = move_speed * maxf(speed_scale, 0.0)

	var steering_target: Vector2 = enemy.navigation_target_position
	if _can_use_navigation_path():
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		if not navigation_agent.is_navigation_finished() and next_path_position.distance_squared_to(enemy.global_position) > 0.01:
			steering_target = next_path_position

	_follow_directly(steering_target, steering_context)

func _stop_navigation() -> void:
	enemy.has_navigation_target = false
	enemy._clear_navigation_motion()
	if steering_component != null:
		steering_component.clear_debug_data()

func _get_closest_navigation_point(requested_position: Vector2) -> Vector2:
	var navigation_map: RID = navigation_agent.get_navigation_map()
	if navigation_map.is_valid():
		return NavigationServer2D.map_get_closest_point(navigation_map, requested_position)
	return requested_position

func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	enemy.safe_navigation_velocity = safe_velocity

func _can_use_navigation_path() -> bool:
	var navigation_path: PackedVector2Array = navigation_agent.get_current_navigation_path()
	if navigation_path.size() > 1:
		return true
	return navigation_agent.is_target_reachable()

func _get_navigation_path_to(target_position: Vector2) -> PackedVector2Array:
	var navigation_map: RID = navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return PackedVector2Array()
	return NavigationServer2D.map_get_path(navigation_map, enemy.global_position, target_position, true)

func _has_navigation_map() -> bool:
	return navigation_agent != null and navigation_agent.get_navigation_map().is_valid()

func _follow_directly(target_position: Vector2, steering_context: Dictionary = {}) -> void:
	var to_target: Vector2 = target_position - enemy.global_position
	if to_target.length_squared() <= 0.01:
		enemy._clear_navigation_motion()
		if steering_component != null:
			steering_component.clear_debug_data()
		return

	var desired_direction := to_target.normalized()
	if steering_component != null:
		desired_direction = steering_component.get_steering_direction(target_position, steering_context)
		if desired_direction == Vector2.ZERO and to_target.length_squared() > 0.01:
			desired_direction = to_target.normalized()

	var desired_velocity: Vector2 = desired_direction * navigation_agent.max_speed
	_apply_navigation_velocity(desired_velocity)

func _apply_navigation_velocity(desired_velocity: Vector2) -> void:
	navigation_agent.velocity = desired_velocity

	var applied_velocity: Vector2 = enemy.safe_navigation_velocity if navigation_agent.avoidance_enabled else desired_velocity
	if applied_velocity == Vector2.ZERO:
		applied_velocity = desired_velocity

	if applied_velocity != Vector2.ZERO:
		enemy._update_facing(applied_velocity.normalized())
	var move_speed: float = maxf(movement_component.get_move_speed(), 0.001)
	movement_component.set_move_direction(applied_velocity / move_speed)
