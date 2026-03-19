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

	# Edge bias: when the enemy is near the outer part of the patrol circle,
	# reduce the interest score of directions that point further outward.
	# This is pure context steering — we tilt the weights, not apply a force.
	# edge_t is 0 when well inside the patrol area, 1 at and beyond the boundary.
	var patrol_home: Vector2 = context.get("patrol_home", enemy.global_position)
	var patrol_radius: float = float(context.get("patrol_radius", 0.0))
	var edge_bias_start: float = clampf(float(context.get("patrol_edge_bias_start", 0.65)), 0.0, 1.0)
	var edge_bias_strength: float = maxf(float(context.get("patrol_edge_bias_strength", 0.0)), 0.0)
	var has_patrol_area: bool = patrol_radius > 0.001 and edge_bias_strength > 0.001

	var edge_t: float = 0.0
	var outward_dir: Vector2 = Vector2.ZERO
	if has_patrol_area:
		var to_home: Vector2 = patrol_home - enemy.global_position
		var dist_from_home: float = to_home.length()
		outward_dir = -to_home / dist_from_home if dist_from_home > 0.001 else Vector2.ZERO
		var inner_edge: float = patrol_radius * edge_bias_start
		var outer_edge: float = patrol_radius
		if dist_from_home > inner_edge:
			edge_t = clampf((dist_from_home - inner_edge) / maxf(outer_edge - inner_edge, 0.001), 0.0, 1.0)

	for i in sample_directions.size():
		var direction: Vector2 = sample_directions[i]
		var target_alignment := remap(clampf(direction.dot(target_direction), -1.0, 1.0), -1.0, 1.0, 0.0, 1.0)
		target_alignment = pow(target_alignment, enemy.steering_interest_curve)

		var continuity_alignment := remap(clampf(direction.dot(previous_direction), -1.0, 1.0), -1.0, 1.0, 0.0, 1.0)
		continuity_alignment = pow(continuity_alignment, enemy.steering_commitment_curve)

		var score := lerpf(target_alignment, continuity_alignment, commit_strength * enemy.steering_inertia_weight)

		# Near the patrol boundary, scale down interest for directions that point
		# further outward. outward_dot is 0 for inward/perpendicular directions
		# and 1 for the direction directly away from home — only those get penalised.
		if edge_t > 0.0 and outward_dir != Vector2.ZERO:
			var outward_dot: float = maxf(direction.dot(outward_dir), 0.0)
			score *= 1.0 - outward_dot * edge_t * edge_bias_strength

		interest[i] = clampf(score, 0.0, 1.0)

	return interest

func _compute_danger(context: Dictionary) -> PackedFloat32Array:
	var danger := _make_empty_weights()
	var space_state := enemy.get_world_2d().direct_space_state

	# When the enemy has genuinely left the patrol area, mark directions pointing
	# further outward as dangerous so the wander target picker and return-home
	# logic can overcome them cleanly. No effect at all while inside the radius.
	var patrol_home: Vector2 = context.get("patrol_home", enemy.global_position)
	var patrol_radius: float = float(context.get("patrol_radius", 0.0))
	var edge_bias_strength: float = maxf(float(context.get("patrol_edge_bias_strength", 0.0)), 0.0)
	var has_patrol_area: bool = patrol_radius > 0.001 and edge_bias_strength > 0.001

	var outside_t: float = 0.0
	var outward_dir: Vector2 = Vector2.ZERO
	if has_patrol_area:
		var to_home: Vector2 = patrol_home - enemy.global_position
		var dist_from_home: float = to_home.length()
		outward_dir = -to_home / dist_from_home if dist_from_home > 0.001 else Vector2.ZERO
		if dist_from_home > patrol_radius:
			# Rises from 0 at the boundary to 1 at 2x the patrol radius.
			outside_t = clampf((dist_from_home - patrol_radius) / maxf(patrol_radius, 0.001), 0.0, 1.0)

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

		# Outside the patrol radius: outward directions become dangerous.
		# This is zero inside the radius — purely an out-of-bounds correction.
		if outside_t > 0.0 and outward_dir != Vector2.ZERO:
			var outward_dot: float = maxf(direction.dot(outward_dir), 0.0)
			score = maxf(score, outward_dot * outside_t * edge_bias_strength)

		danger[i] = clampf(score, 0.0, 1.0)

	return danger

func _combine_weights(interest: PackedFloat32Array, danger: PackedFloat32Array, context: Dictionary) -> PackedFloat32Array:
	var final_weights := _make_empty_weights()
	var dead_zone: float = clampf(float(context.get("dead_zone", enemy.steering_dead_zone)), 0.0, 1.0)

	for i in sample_directions.size():
		var raw_weight := interest[i] * enemy.steering_interest_strength - danger[i] * enemy.steering_danger_strength
		final_weights[i] = 0.0 if raw_weight <= dead_zone else clampf(raw_weight, 0.0, 1.0)

	return final_weights

func _build_steering_vector(weights: PackedFloat32Array) -> Vector2:
	var weighted_sum := Vector2.ZERO
	var weight_total := 0.0

	for i in sample_directions.size():
		var weight := weights[i]
		if weight <= 0.0:
			continue
		weighted_sum += sample_directions[i] * weight
		weight_total += weight

	if weighted_sum.length_squared() <= 0.0001 or weight_total <= 0.0001:
		return Vector2.ZERO

	return (weighted_sum / weight_total).limit_length(1.0)

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
