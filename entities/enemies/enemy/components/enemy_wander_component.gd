extends Node
class_name EnemyWanderComponent

const MODE_WANDER := &"wander"
const MODE_RETURN_HOME := &"return_home"

var enemy: Enemy
var navigation_component: EnemyNavigationComponent

var wander_origin: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var has_wander_target: bool = false
var has_wander_origin: bool = false
var wait_time_remaining: float = 0.0
var repick_time_remaining: float = 0.0
var current_mode: StringName = MODE_WANDER

func setup(owner_enemy: Enemy, owner_navigation_component: EnemyNavigationComponent) -> void:
	enemy = owner_enemy
	navigation_component = owner_navigation_component
	has_wander_origin = true
	wander_origin = enemy.global_position
	wander_target = enemy.global_position
	reset()

func set_wander_origin(origin: Vector2) -> void:
	wander_origin = origin
	has_wander_origin = true
	if not has_wander_target:
		wander_target = wander_origin

func reset() -> void:
	has_wander_target = false
	wander_target = enemy.global_position if enemy != null else Vector2.ZERO
	if has_wander_origin:
		wander_target = _get_home_position()
	wait_time_remaining = 0.0
	repick_time_remaining = 0.0
	current_mode = MODE_WANDER

func stop() -> void:
	reset()
	if navigation_component != null:
		navigation_component._stop_navigation()

func process_wander(delta: float) -> void:
	if enemy == null or navigation_component == null:
		return

	wait_time_remaining = maxf(wait_time_remaining - delta, 0.0)
	repick_time_remaining = maxf(repick_time_remaining - delta, 0.0)

	if _should_return_home():
		_process_return_home(delta)
		return

	current_mode = MODE_WANDER
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

	_follow_target(
		enemy.patrol_move_speed_scale,
		MODE_WANDER,
		wander_target,
		enemy.patrol_arrival_radius,
		enemy.patrol_slow_radius
	)

func _process_return_home(delta: float) -> void:
	var home_position := _get_home_position()
	current_mode = MODE_RETURN_HOME
	has_wander_target = false
	wait_time_remaining = 0.0
	repick_time_remaining = 0.0

	var distance_to_home := enemy.global_position.distance_to(home_position)
	if distance_to_home <= enemy.patrol_arrival_radius:
		navigation_component._stop_navigation()
		enemy.movement_component.decelerate_to_stop(delta)
		return

	_follow_target(
		enemy.patrol_return_speed_scale,
		MODE_RETURN_HOME,
		home_position,
		enemy.patrol_arrival_radius,
		maxf(enemy.patrol_return_slow_radius, enemy.patrol_arrival_radius)
	)

func _follow_target(speed_scale: float, mode: StringName, target_position: Vector2, arrival_radius: float, slow_radius: float) -> void:
	wander_target = target_position
	current_mode = mode
	navigation_component._set_navigation_target(target_position)

	var steering_context := {
		"mode": String(mode),
		"fallback_target": target_position,
		"interest_position": target_position,
		"arrival_radius": arrival_radius,
		"slow_radius": slow_radius,
		"commit_strength": enemy.steering_commitment_strength,
		"target_is_active": true
	}

	# Pass the patrol home position and radius so the steering layer can apply
	# a context-steering edge bias (reduced interest for outward directions near
	# the boundary). No leash force — only weight adjustments on the vectors.
	steering_context["patrol_home"] = _get_home_position()
	steering_context["patrol_radius"] = enemy.patrol_radius
	steering_context["patrol_edge_bias_start"] = enemy.patrol_edge_bias_start
	steering_context["patrol_edge_bias_strength"] = enemy.patrol_edge_bias_strength

	navigation_component._follow_navigation(speed_scale, steering_context)

func _should_return_home() -> bool:
	if not has_wander_origin:
		return false
	var return_distance := maxf(enemy.patrol_return_distance, enemy.patrol_radius)
	return enemy.global_position.distance_to(_get_home_position()) > return_distance

func _pick_next_wander_target() -> void:
	if enemy == null or navigation_component == null:
		return

	var home_position := _get_home_position()
	var sample_center := home_position if enemy.patrol_anchor_to_spawn else enemy.global_position
	var min_distance := minf(enemy.patrol_point_min_distance, enemy.patrol_radius)
	var max_attempts := maxi(enemy.patrol_target_retry_count, 1)
	var candidate := home_position
	var best_score := -INF
	var found_candidate := false

	for _attempt in max_attempts:
		var distance := enemy.rng.randf_range(min_distance, enemy.patrol_radius)
		var angle := enemy.rng.randf_range(0.0, TAU)
		var raw_candidate := sample_center + Vector2.RIGHT.rotated(angle) * distance

		if enemy.patrol_anchor_to_spawn and raw_candidate.distance_to(home_position) > enemy.patrol_radius:
			raw_candidate = home_position + (raw_candidate - home_position).limit_length(enemy.patrol_radius)

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
			center_bias = 1.0 - clampf(navigable_candidate.distance_to(home_position) / enemy.patrol_radius, 0.0, 1.0)

		var score := candidate_distance * 0.65 + previous_alignment * enemy.patrol_direction_continuity + center_bias * 8.0
		if score > best_score:
			best_score = score
			candidate = navigable_candidate
			found_candidate = true

	if not found_candidate:
		candidate = navigation_component._get_closest_navigation_point(
			home_position + Vector2.RIGHT.rotated(enemy.rng.randf_range(0.0, TAU)) * min_distance
		)
		if candidate.distance_to(enemy.global_position) < min_distance * 0.5:
			has_wander_target = false
			return

	wander_target = candidate
	has_wander_target = true
	current_mode = MODE_WANDER
	repick_time_remaining = enemy.rng.randf_range(enemy.patrol_wander_duration.x, enemy.patrol_wander_duration.y)

func _get_home_position() -> Vector2:
	if has_wander_origin:
		return wander_origin
	if enemy != null:
		return enemy.global_position
	return Vector2.ZERO
