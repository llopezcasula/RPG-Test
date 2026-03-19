extends Node
class_name EnemySteeringComponent

var enemy: Enemy
var sample_directions: Array[Vector2] = []
var last_interest: PackedFloat32Array = PackedFloat32Array()
var last_danger: PackedFloat32Array = PackedFloat32Array()
var last_final: PackedFloat32Array = PackedFloat32Array()
var last_steering: Vector2 = Vector2.ZERO
var last_target_position: Vector2 = Vector2.ZERO
var last_interest_position: Vector2 = Vector2.ZERO
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
	last_interest_position = Vector2.ZERO
	last_mode = &""

func get_steering_direction(target_position: Vector2, context: Dictionary = {}) -> Vector2:
	if enemy == null:
		return Vector2.ZERO

	if sample_directions.size() != maxi(enemy.steering_sample_count, 4):
		_refresh_sample_directions()

	last_target_position = target_position
	last_interest_position = context.get("interest_position", target_position)
	last_mode = StringName(context.get("mode", ""))

	var target_offset: Vector2 = last_interest_position - enemy.global_position
	var target_distance: float = target_offset.length()
	var target_direction: Vector2 = target_offset / target_distance if target_distance > 0.001 else Vector2.ZERO
	var arrival_scale := _get_arrival_scale(target_distance, context)
	var target_is_active: bool = context.get("target_is_active", true)

	if arrival_scale <= 0.001 or not target_is_active:
		last_interest = _make_empty_weights()
		last_danger = _make_empty_weights()
		last_final = _make_empty_weights()
		last_steering = _smooth_steering(Vector2.ZERO)
		return last_steering

	last_interest = _compute_interest(target_direction, context)
	last_danger = _compute_danger(context)
	last_final = _combine_weights(last_interest, last_danger, context)

	var steering := _build_steering_vector(last_final)
	if steering == Vector2.ZERO and target_direction != Vector2.ZERO:
		steering = target_direction

	steering *= arrival_scale
	last_steering = _smooth_steering(steering)
	return last_steering

func _refresh_sample_directions() -> void:
	sample_directions.clear()
	var direction_count: int = maxi(enemy.steering_sample_count if enemy != null else 0, 4)
	for i in direction_count:
		var angle: float = TAU * float(i) / float(direction_count)
		sample_directions.append(Vector2.RIGHT.rotated(angle))

func _compute_interest(target_direction: Vector2, context: Dictionary) -> PackedFloat32Array:
	var interest := _make_empty_weights()
	var previous_direction: Vector2 = last_steering.normalized() if last_steering.length_squared() > 0.0001 else target_direction
	var commit_strength: float = clampf(float(context.get("commit_strength", enemy.steering_commitment_strength)), 0.0, 1.0)

	for i in sample_directions.size():
		var direction: Vector2 = sample_directions[i]
		var target_alignment := remap(clampf(direction.dot(target_direction), -1.0, 1.0), -1.0, 1.0, 0.0, 1.0)
		target_alignment = pow(target_alignment, enemy.steering_interest_curve)

		var continuity_alignment := remap(clampf(direction.dot(previous_direction), -1.0, 1.0), -1.0, 1.0, 0.0, 1.0)
		continuity_alignment = pow(continuity_alignment, enemy.steering_commitment_curve)

		var score := lerpf(target_alignment, continuity_alignment, commit_strength * enemy.steering_inertia_weight)

		interest[i] = clampf(score, 0.0, 1.0)

	return interest

func _compute_danger(context: Dictionary) -> PackedFloat32Array:
	var danger := _make_empty_weights()
	var space_state := enemy.get_world_2d().direct_space_state

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
			var distance_ratio := enemy.global_position.distance_to(hit_position) / maxf(enemy.steering_obstacle_check_distance, 0.001)
			score = maxf(score, 1.0 - clampf(distance_ratio, 0.0, 1.0))

		danger[i] = clampf(score, 0.0, 1.0)

	return danger

func _combine_weights(interest: PackedFloat32Array, danger: PackedFloat32Array, context: Dictionary) -> PackedFloat32Array:
	var final_weights := _make_empty_weights()
	var dead_zone: float = clampf(float(context.get("dead_zone", enemy.steering_dead_zone)), 0.0, 1.0)
	var interest_weight: float = maxf(float(context.get("interest_weight", enemy.steering_interest_strength)), 0.0)
	var danger_weight: float = maxf(float(context.get("danger_weight", enemy.steering_danger_strength)), 0.0)

	for i in sample_directions.size():
		var raw_weight := interest[i] * interest_weight - danger[i] * danger_weight
		final_weights[i] = 0.0 if raw_weight <= dead_zone else clampf(raw_weight, 0.0, 1.0)

	return final_weights

func _build_steering_vector(weights: PackedFloat32Array) -> Vector2:
	var weighted_sum := Vector2.ZERO
	var weight_total := 0.0
	var best_index := -1
	var best_weight := 0.0

	for i in sample_directions.size():
		var weight := weights[i]
		if weight <= 0.0:
			continue

		weighted_sum += sample_directions[i] * weight
		weight_total += weight

		if best_index == -1 or weight > best_weight:
			best_index = i
			best_weight = weight

	if best_index == -1 or best_weight <= 0.0:
		return Vector2.ZERO

	var dominant_vector := sample_directions[best_index] * best_weight
	var neighbor_influence := clampf(enemy.steering_neighbor_direction_influence, 0.0, 1.0)
	if neighbor_influence > 0.0 and sample_directions.size() > 2:
		for offset in [-1, 1]:
			var neighbor_index := wrapi(best_index + offset, 0, sample_directions.size())
			dominant_vector += sample_directions[neighbor_index] * weights[neighbor_index] * neighbor_influence

	var dominant_direction := dominant_vector.normalized() if dominant_vector.length_squared() > 0.0001 else sample_directions[best_index]
	if weighted_sum.length_squared() <= 0.0001 or weight_total <= 0.0001:
		return dominant_direction

	var averaged_direction := (weighted_sum / weight_total).normalized()
	var blend_to_average := 1.0 - clampf(enemy.steering_dominant_direction_blend, 0.0, 1.0)
	if averaged_direction == Vector2.ZERO:
		return dominant_direction

	return dominant_direction.lerp(averaged_direction, blend_to_average).normalized()

func _smooth_steering(new_steering: Vector2) -> Vector2:
	var smooth_weight := clampf(enemy.steering_smoothing, 0.0, 1.0)
	if smooth_weight <= 0.0:
		return new_steering.limit_length(1.0)
	if last_steering == Vector2.ZERO:
		return new_steering.limit_length(1.0)
	return last_steering.lerp(new_steering, smooth_weight).limit_length(1.0)

func _get_arrival_scale(target_distance: float, context: Dictionary) -> float:
	var arrival_radius: float = maxf(float(context.get("arrival_radius", 0.0)), 0.0)
	var slow_radius: float = maxf(float(context.get("slow_radius", arrival_radius)), arrival_radius)

	if arrival_radius > 0.0 and target_distance <= arrival_radius:
		return 0.0
	if slow_radius <= arrival_radius:
		return 1.0
	if target_distance >= slow_radius:
		return 1.0
	return clampf((target_distance - arrival_radius) / maxf(slow_radius - arrival_radius, 0.001), 0.0, 1.0)

func _make_empty_weights() -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	weights.resize(sample_directions.size())
	return weights
