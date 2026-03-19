extends Node
class_name EnemyAIComponent

const WANDER_ARRIVAL_RADIUS := 10.0
const WANDER_MIN_DISTANCE := 50.0
const WANDER_MAX_DISTANCE := 120.0
const WANDER_MIN_REPICK_TIME := 1.0
const WANDER_MAX_REPICK_TIME := 3.0
const WANDER_MIN_PAUSE_TIME := 0.5
const WANDER_MAX_PAUSE_TIME := 1.5
const WANDER_DIRECTION_JITTER := 0.35
const WANDER_SPEED_SCALE := 0.45

var enemy: Enemy
var movement_component: MovementComponent
var navigation_component: EnemyNavigationComponent
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0

func setup(owner_enemy: Enemy, owner_movement_component: MovementComponent, owner_navigation_component: EnemyNavigationComponent) -> void:
	enemy = owner_enemy
	movement_component = owner_movement_component
	navigation_component = owner_navigation_component
	_reset_wander()

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
	_reset_wander()

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
		"interest_position": enemy.current_target.global_position,
		"commit_strength": enemy.steering_chase_commitment_strength
	})

func _process_patrol(delta: float) -> void:
	if enemy.state == enemy.State.ATTACK:
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		return

	wander_timer = maxf(wander_timer - delta, 0.0)

	var distance_to_target := enemy.global_position.distance_to(wander_target)
	if distance_to_target <= WANDER_ARRIVAL_RADIUS:
		var was_moving := enemy.has_navigation_target
		navigation_component._stop_navigation()
		movement_component.decelerate_to_stop(delta)
		if wander_timer <= 0.0:
			_pick_next_wander_target(was_moving)
		return

	if wander_timer <= 0.0:
		_pick_next_wander_target(false)

	navigation_component._set_navigation_target(wander_target)
	navigation_component._follow_navigation(WANDER_SPEED_SCALE, {
		"mode": "wander",
		"interest_position": wander_target
	})

func _pick_next_wander_target(wait_before_move: bool) -> void:
	if enemy == null or navigation_component == null:
		return

	if wait_before_move:
		wander_target = enemy.global_position
		wander_timer = enemy.rng.randf_range(WANDER_MIN_PAUSE_TIME, WANDER_MAX_PAUSE_TIME)
		return

	var base_direction := enemy.facing_direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT.rotated(enemy.rng.randf_range(0.0, TAU))

	var jittered_direction := base_direction.rotated(enemy.rng.randf_range(-WANDER_DIRECTION_JITTER, WANDER_DIRECTION_JITTER))
	var random_direction := jittered_direction.normalized()
	if random_direction == Vector2.ZERO:
		random_direction = Vector2.RIGHT.rotated(enemy.rng.randf_range(0.0, TAU))

	var random_distance := enemy.rng.randf_range(WANDER_MIN_DISTANCE, WANDER_MAX_DISTANCE)
	var requested_target := enemy.global_position + random_direction * random_distance
	var navigation_target := navigation_component._get_closest_navigation_point(requested_target)
	if navigation_target.distance_to(enemy.global_position) < WANDER_ARRIVAL_RADIUS:
		navigation_target = requested_target

	wander_target = navigation_target
	wander_timer = enemy.rng.randf_range(WANDER_MIN_REPICK_TIME, WANDER_MAX_REPICK_TIME)

func _reset_wander() -> void:
	wander_target = enemy.global_position if enemy != null else Vector2.ZERO
	wander_timer = 0.0
