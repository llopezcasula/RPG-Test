extends Node
class_name EnemyAIComponent

var enemy: Enemy
var movement_component: MovementComponent
var navigation_component: EnemyNavigationComponent
var wander_component: EnemyWanderComponent
var was_chasing_target: bool = false

func setup(owner_enemy: Enemy, owner_movement_component: MovementComponent, owner_navigation_component: EnemyNavigationComponent, owner_wander_component: EnemyWanderComponent) -> void:
	enemy = owner_enemy
	movement_component = owner_movement_component
	navigation_component = owner_navigation_component
	wander_component = owner_wander_component

func _resolve_target() -> void:
	enemy.current_target = enemy.get_tree().get_first_node_in_group(enemy.player_group) as CharacterBody2D

func _can_chase_target() -> bool:
	if enemy.current_target == null or not is_instance_valid(enemy.current_target):
		enemy.aggro_locked = false
		return false

	var distance_to_target: float = enemy.global_position.distance_to(enemy.current_target.global_position)
	if distance_to_target <= enemy.detection_radius:
		enemy.aggro_locked = true

	if enemy.aggro_locked and distance_to_target <= enemy.disengage_radius:
		return true

	enemy.aggro_locked = false
	return false

func _process_chase(delta: float) -> void:
	if wander_component != null and not was_chasing_target:
		wander_component.stop()

	was_chasing_target = true

	if enemy.current_target == null:
		navigation_component._stop_navigation()
		return

	var to_target: Vector2 = enemy.current_target.global_position - enemy.global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= 0.001:
		navigation_component._stop_navigation()
		return

	var direction: Vector2 = to_target / distance_to_target
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

	var desired_speed_scale: float = enemy.chase_move_speed_scale
	if enemy.attack_slowdown_distance > 0.0:
		var slowdown_distance: float = enemy.attack_range + enemy.attack_slowdown_distance
		if distance_to_target < slowdown_distance:
			var attack_slowdown_ratio := clampf((distance_to_target - enemy.attack_range) / enemy.attack_slowdown_distance, 0.35, 1.0)
			desired_speed_scale *= attack_slowdown_ratio

	navigation_component._follow_navigation(desired_speed_scale, {
		"mode": "chase",
		"fallback_target": enemy.current_target.global_position,
		"interest_position": enemy.current_target.global_position,
		"commit_strength": enemy.steering_chase_commitment_strength
	})

func _process_patrol(delta: float) -> void:
	if was_chasing_target and wander_component != null:
		wander_component.begin_return_to_origin()
	was_chasing_target = false

	if enemy.state == enemy.State.ATTACK:
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		return

	if wander_component == null:
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		return

	wander_component.process_wander(delta)
