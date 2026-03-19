extends Node
class_name EnemyAIComponent

var enemy
var movement_component: MovementComponent
var navigation_component: EnemyNavigationComponent

func setup(owner_enemy, owner_movement_component: MovementComponent, owner_navigation_component: EnemyNavigationComponent) -> void:
	enemy = owner_enemy
	movement_component = owner_movement_component
	navigation_component = owner_navigation_component

func _resolve_target() -> void:
	enemy.current_target = enemy.get_tree().get_first_node_in_group(enemy.player_group) as CharacterBody2D

func _can_chase_target() -> bool:
	if enemy.current_target == null or not is_instance_valid(enemy.current_target):
		enemy.aggro_locked = false
		return false

	var distance_to_target := enemy.global_position.distance_to(enemy.current_target.global_position)
	if distance_to_target <= enemy.detection_radius:
		enemy.aggro_locked = true

	if enemy.aggro_locked and distance_to_target <= enemy.disengage_radius:
		return true

	enemy.aggro_locked = false
	return false

func _process_chase(delta: float) -> void:
	if enemy.current_target == null:
		navigation_component._stop_navigation()
		return

	var to_target := enemy.current_target.global_position - enemy.global_position
	var distance_to_target := to_target.length()
	if distance_to_target <= 0.001:
		navigation_component._stop_navigation()
		return

	var direction := to_target / distance_to_target
	enemy._update_facing(direction)

	if distance_to_target <= enemy.attack_range:
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		if enemy.attack_cooldown_remaining <= 0.0 and enemy.state != enemy.State.ATTACK:
			enemy.attack_component._start_attack(direction)
		return

	if enemy.state == enemy.State.ATTACK:
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		return

	navigation_component._set_navigation_target(enemy.current_target.global_position)

	# Navigation stays owned by EnemyNavigationComponent. AI only chooses when to
	# chase and how aggressively to approach the current target.
	var desired_speed_scale := 1.0
	if enemy.attack_slowdown_distance > 0.0:
		var slowdown_distance := enemy.attack_range + enemy.attack_slowdown_distance
		if distance_to_target < slowdown_distance:
			desired_speed_scale = clampf((distance_to_target - enemy.attack_range) / enemy.attack_slowdown_distance, 0.35, 1.0)

	navigation_component._follow_navigation(desired_speed_scale)

func _process_patrol(delta: float) -> void:
	if enemy.state == enemy.State.ATTACK:
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		return

	if enemy.global_position.distance_to(enemy.patrol_target) <= enemy.patrol_repath_distance:
		navigation_component._stop_navigation()
		enemy.patrol_wait_time -= delta
		if enemy.patrol_wait_time <= 0.0:
			_pick_next_patrol_target()
		return

	navigation_component._set_navigation_target(enemy.patrol_target)
	navigation_component._follow_navigation()

func _pick_next_patrol_target() -> void:
	var angle := enemy.rng.randf_range(0.0, TAU)
	var distance := enemy.rng.randf_range(12.0, enemy.patrol_radius)
	var requested_patrol_target := enemy.spawn_position + Vector2.RIGHT.rotated(angle) * distance
	enemy.patrol_target = navigation_component._get_closest_navigation_point(requested_patrol_target)
	if enemy.patrol_target.distance_to(enemy.global_position) <= enemy.patrol_snap_distance:
		enemy.patrol_target = enemy.spawn_position
	enemy.patrol_wait_time = enemy.rng.randf_range(enemy.patrol_idle_time.x, enemy.patrol_idle_time.y)
