extends Node
class_name EnemyWanderComponent

const MODE_IDLE := &"idle"
const MODE_WANDER := &"wander"

var enemy: Enemy
var navigation_component: EnemyNavigationComponent

var wander_origin: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var has_wander_target: bool = false
var has_wander_origin: bool = false
var state_time_remaining: float = 0.0
var current_mode: StringName = MODE_IDLE

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
	current_mode = MODE_IDLE
	_start_idle_phase()

func stop() -> void:
	reset()
	if navigation_component != null:
		navigation_component._stop_navigation()

func process_wander(delta: float) -> void:
	if enemy == null or navigation_component == null:
		return

	state_time_remaining = maxf(state_time_remaining - delta, 0.0)

	if current_mode == MODE_IDLE:
		navigation_component._stop_navigation()
		enemy.movement_component.decelerate_to_stop(delta)
		if state_time_remaining <= 0.0:
			_start_wander_phase()
		return

	if not has_wander_target:
		_start_idle_phase()
		return

	var distance_to_target := enemy.global_position.distance_to(wander_target)
	if distance_to_target <= enemy.patrol_arrival_radius or state_time_remaining <= 0.0:
		_start_idle_phase()
		return

	_follow_target(
		enemy.patrol_move_speed_scale,
		wander_target,
		enemy.patrol_arrival_radius,
		enemy.patrol_slow_radius
	)

func _follow_target(speed_scale: float, target_position: Vector2, arrival_radius: float, slow_radius: float) -> void:
	wander_target = target_position
	current_mode = MODE_WANDER
	navigation_component._set_navigation_target(target_position)
	navigation_component._follow_navigation(speed_scale, {
		"mode": String(MODE_WANDER),
		"fallback_target": target_position,
		"interest_position": target_position,
		"arrival_radius": arrival_radius,
		"slow_radius": slow_radius,
		"commit_strength": enemy.steering_commitment_strength,
		"target_is_active": true
	})

func _start_idle_phase() -> void:
	has_wander_target = false
	current_mode = MODE_IDLE
	state_time_remaining = enemy.rng.randf_range(enemy.patrol_idle_time.x, enemy.patrol_idle_time.y)
	if navigation_component != null:
		navigation_component._stop_navigation()

func _start_wander_phase() -> void:
	if not _pick_next_wander_target():
		_start_idle_phase()
		return

	has_wander_target = true
	current_mode = MODE_WANDER
	state_time_remaining = enemy.rng.randf_range(enemy.patrol_wander_duration.x, enemy.patrol_wander_duration.y)

func _pick_next_wander_target() -> bool:
	if enemy == null or navigation_component == null:
		return false

	var home_position := _get_home_position()
	var min_distance := minf(enemy.patrol_point_min_distance, enemy.patrol_radius)
	var max_attempts := maxi(enemy.patrol_target_retry_count, 1)

	for _attempt in max_attempts:
		var distance := enemy.rng.randf_range(min_distance, enemy.patrol_radius)
		var angle := enemy.rng.randf_range(0.0, TAU)
		var raw_candidate := home_position + Vector2.RIGHT.rotated(angle) * distance
		var navigable_candidate := navigation_component._get_closest_navigation_point(raw_candidate)
		if navigable_candidate.distance_to(home_position) > enemy.patrol_radius:
			continue
		if navigable_candidate.distance_to(enemy.global_position) < min_distance:
			continue
		wander_target = navigable_candidate
		return true

	return false

func _get_home_position() -> Vector2:
	if has_wander_origin:
		return wander_origin
	if enemy != null:
		return enemy.global_position
	return Vector2.ZERO
