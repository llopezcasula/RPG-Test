extends Node
class_name EnemySteeringComponent

var enemy: Enemy
var sample_directions: Array[Vector2] = []
var last_interest: PackedFloat32Array = PackedFloat32Array()
var last_danger: PackedFloat32Array = PackedFloat32Array()
var last_final: PackedFloat32Array = PackedFloat32Array()
var last_steering: Vector2 = Vector2.ZERO
var last_target_position: Vector2 = Vector2.ZERO
var last_mode: StringName = &""

func setup(owner_enemy: Enemy) -> void:
	enemy = owner_enemy
	_refresh_sample_directions()
	clear_debug_data()

func _ready() -> void:
	if enemy == null:
		enemy = get_parent() as Enemy
	if enemy != null:
		_refresh_sample_directions()

func clear_debug_data() -> void:
	last_interest = PackedFloat32Array()
	last_danger = PackedFloat32Array()
	last_final = PackedFloat32Array()
	last_steering = Vector2.ZERO
	last_target_position = Vector2.ZERO
	last_mode = &""

func get_steering_direction(target_position: Vector2, context: Dictionary = {}) -> Vector2:
	if enemy == null:
		return Vector2.ZERO

	if sample_directions.size() != maxi(enemy.steering_sample_count, 4):
		_refresh_sample_directions()

	last_target_position = target_position
	last_mode = StringName(context.get("mode", ""))

	var target_offset: Vector2 = target_position - enemy.global_position
	var target_direction: Vector2 = target_offset.normalized() if target_offset.length_squared() > 0.001 else Vector2.ZERO
	last_interest = _compute_interest(target_direction, context)
	last_danger = _compute_danger(context)
	last_final = _combine_weights(last_interest, last_danger)

	var steering := _build_steering_vector(last_final)
	if steering == Vector2.ZERO and target_direction != Vector2.ZERO:
		steering = target_direction

	if enemy.steering_smoothing > 0.0 and steering != Vector2.ZERO:
		var smooth_weight := clampf(enemy.steering_smoothing, 0.0, 1.0)
		if last_steering != Vector2.ZERO:
			steering = last_steering.lerp(steering, smooth_weight)
			if steering.length_squared() > 0.001:
				steering = steering.normalized()

	last_steering = steering
	return last_steering

func _refresh_sample_directions() -> void:
	sample_directions.clear()
	var direction_count: int = maxi(enemy.steering_sample_count if enemy != null else 0, 4)
	for i in direction_count:
		var angle: float = TAU * float(i) / float(direction_count)
		sample_directions.append(Vector2.RIGHT.rotated(angle))

func _compute_interest(target_direction: Vector2, context: Dictionary) -> PackedFloat32Array:
	var interest := PackedFloat32Array()
	interest.resize(sample_directions.size())

	var leash_center: Vector2 = context.get("leash_center", enemy.global_position)
	var leash_radius: float = float(context.get("leash_radius", 0.0))
	var leash_strength: float = float(context.get("leash_strength", 0.0))
	var to_leash_center: Vector2 = leash_center - enemy.global_position
	var leash_distance: float = to_leash_center.length()
	var leash_direction: Vector2 = to_leash_center.normalized() if leash_distance > 0.001 else Vector2.ZERO
	var leash_ratio: float = 0.0
	if leash_radius > 0.001:
		leash_ratio = clampf(leash_distance / leash_radius, 0.0, 1.5)

	for i in sample_directions.size():
		var direction: Vector2 = sample_directions[i]
		var score := maxf(direction.dot(target_direction), 0.0)
		if leash_direction != Vector2.ZERO and leash_strength > 0.0:
			score += maxf(direction.dot(leash_direction), 0.0) * maxf(leash_ratio - 0.65, 0.0) * leash_strength
		interest[i] = clampf(score, 0.0, 1.0)

	return interest

func _compute_danger(context: Dictionary) -> PackedFloat32Array:
	var danger := PackedFloat32Array()
	danger.resize(sample_directions.size())

	var space_state := enemy.get_world_2d().direct_space_state
	var leash_center: Vector2 = context.get("leash_center", enemy.global_position)
	var leash_radius: float = float(context.get("leash_radius", 0.0))
	var to_leash_center: Vector2 = leash_center - enemy.global_position
	var leash_distance: float = to_leash_center.length()
	var leash_direction: Vector2 = to_leash_center.normalized() if leash_distance > 0.001 else Vector2.ZERO

	for i in sample_directions.size():
		var direction: Vector2 = sample_directions[i]
		var query := PhysicsRayQueryParameters2D.create(
			enemy.global_position,
			enemy.global_position + direction * enemy.steering_obstacle_check_distance,
			enemy.steering_obstacle_mask
		)
		query.exclude = [enemy]
		var hit := space_state.intersect_ray(query)

		var score := 0.0
		if not hit.is_empty():
			var hit_position: Vector2 = hit["position"]
			var hit_ratio := 1.0 - clampf(enemy.global_position.distance_to(hit_position) / enemy.steering_obstacle_check_distance, 0.0, 1.0)
			score = maxf(score, hit_ratio)

		if leash_radius > 0.001 and leash_distance > leash_radius and leash_direction != Vector2.ZERO:
			var outward_alignment := maxf(direction.dot(-leash_direction), 0.0)
			var leash_danger := outward_alignment * clampf((leash_distance - leash_radius) / leash_radius, 0.0, 1.0)
			score = maxf(score, leash_danger)

		danger[i] = clampf(score, 0.0, 1.0)

	return danger

func _combine_weights(interest: PackedFloat32Array, danger: PackedFloat32Array) -> PackedFloat32Array:
	var final_weights := PackedFloat32Array()
	final_weights.resize(sample_directions.size())

	for i in sample_directions.size():
		final_weights[i] = clampf(
			interest[i] * enemy.steering_interest_strength - danger[i] * enemy.steering_danger_strength,
			0.0,
			1.0
		)

	return final_weights

func _build_steering_vector(weights: PackedFloat32Array) -> Vector2:
	var result := Vector2.ZERO

	for i in sample_directions.size():
		result += sample_directions[i] * weights[i]

	if result.length_squared() <= 0.001:
		return Vector2.ZERO

	return result.normalized()
