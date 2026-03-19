extends Node
class_name EnemyWanderComponent

var enemy: Enemy
var navigation_component: EnemyNavigationComponent

var wander_origin: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var has_wander_target: bool = false
var wait_time_remaining: float = 0.0
var repick_time_remaining: float = 0.0

func setup(owner_enemy: Enemy, owner_navigation_component: EnemyNavigationComponent) -> void:
	enemy = owner_enemy
	navigation_component = owner_navigation_component
	wander_origin = enemy.global_position
	wander_target = wander_origin
	has_wander_target = false
	wait_time_remaining = 0.0
	repick_time_remaining = 0.0

func set_wander_origin(origin: Vector2) -> void:
	wander_origin = origin

func reset() -> void:
	has_wander_target = false
	wander_target = wander_origin
	wait_time_remaining = 0.0
	repick_time_remaining = 0.0

func stop() -> void:
	reset()
	if navigation_component != null:
		navigation_component._stop_navigation()

func process_wander(delta: float) -> void:
	if enemy == null or navigation_component == null:
		return

	wait_time_remaining = maxf(wait_time_remaining - delta, 0.0)
	repick_time_remaining = maxf(repick_time_remaining - delta, 0.0)

	if wait_time_remaining > 0.0:
		navigation_component._stop_navigation()
		enemy.movement_component.decelerate_to_stop(delta)
		return

	if not has_wander_target or repick_time_remaining <= 0.0:
		_pick_next_wander_target()

	if not has_wander_target:
		navigation_component._stop_navigation()
		enemy.movement_component.decelerate_to_stop(delta)
		return

	var distance_to_target := enemy.global_position.distance_to(wander_target)
	if distance_to_target <= enemy.patrol_arrival_radius:
		has_wander_target = false
		repick_time_remaining = 0.0
		wait_time_remaining = enemy.rng.randf_range(enemy.patrol_idle_time.x, enemy.patrol_idle_time.y)
		navigation_component._stop_navigation()
		enemy.movement_component.decelerate_to_stop(delta)
		return

	navigation_component._set_navigation_target(wander_target)
	navigation_component._follow_navigation(enemy.patrol_move_speed_scale, {
		"mode": "wander",
		"fallback_target": wander_target,
		"interest_position": wander_target,
		"arrival_radius": enemy.patrol_arrival_radius,
		"slow_radius": enemy.patrol_slow_radius,
		"leash_center": wander_origin,
		"leash_radius": enemy.patrol_radius,
		"leash_strength": enemy.patrol_leash_strength,
		"commit_strength": enemy.steering_commitment_strength,
		"target_is_active": has_wander_target
	})

func _pick_next_wander_target() -> void:
	if enemy == null or navigation_component == null:
		return

	var sample_center := wander_origin if enemy.patrol_anchor_to_spawn else enemy.global_position
	var min_distance := minf(enemy.patrol_point_min_distance, enemy.patrol_radius)
	var max_attempts := maxi(enemy.patrol_target_retry_count, 1)
	var candidate := wander_origin
	var best_score := -INF
	var found_candidate := false

	for _attempt in max_attempts:
		var distance := enemy.rng.randf_range(min_distance, enemy.patrol_radius)
		var angle := enemy.rng.randf_range(0.0, TAU)
		var raw_candidate := sample_center + Vector2.RIGHT.rotated(angle) * distance

		if enemy.patrol_anchor_to_spawn and raw_candidate.distance_to(wander_origin) > enemy.patrol_radius:
			raw_candidate = wander_origin + (raw_candidate - wander_origin).limit_length(enemy.patrol_radius)

		var navigable_candidate := navigation_component._get_closest_navigation_point(raw_candidate)
		var candidate_offset := navigable_candidate - enemy.global_position
		var candidate_distance := candidate_offset.length()
		if candidate_distance < min_distance:
			continue

		var previous_alignment := 0.5
		if has_wander_target:
			var previous_direction := (wander_target - enemy.global_position).normalized()
			var candidate_direction := candidate_offset.normalized()
			if previous_direction != Vector2.ZERO and candidate_direction != Vector2.ZERO:
				previous_alignment = (candidate_direction.dot(previous_direction) + 1.0) * 0.5

		var center_bias := 1.0
		if enemy.patrol_anchor_to_spawn and enemy.patrol_radius > 0.0:
			center_bias = 1.0 - clampf(navigable_candidate.distance_to(wander_origin) / enemy.patrol_radius, 0.0, 1.0)

		var score := candidate_distance * 0.65 + previous_alignment * enemy.patrol_direction_continuity + center_bias * 8.0
		if score > best_score:
			best_score = score
			candidate = navigable_candidate
			found_candidate = true

	if not found_candidate:
		candidate = navigation_component._get_closest_navigation_point(
			wander_origin + Vector2.RIGHT.rotated(enemy.rng.randf_range(0.0, TAU)) * min_distance
		)
		if candidate.distance_to(enemy.global_position) < min_distance * 0.5:
			has_wander_target = false
			return

	wander_target = candidate
	has_wander_target = true
	repick_time_remaining = enemy.rng.randf_range(enemy.patrol_wander_duration.x, enemy.patrol_wander_duration.y)
