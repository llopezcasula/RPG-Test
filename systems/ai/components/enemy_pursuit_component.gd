extends Node
class_name EnemyPursuitComponent

## Path-following + local separation for action-RPG melee enemies.
##
## The component keeps path requests infrequent and stable, follows the next waypoint
## instead of aiming through walls, and blends in a short-range separation force so
## groups slide around one another instead of turning into a single collision blob.

@export_category("Navigation")
@export var repath_interval: float = 0.35
@export var repath_distance: float = 28.0
@export var path_point_reach_distance: float = 18.0
@export var fallback_direct_distance: float = 32.0
@export var stuck_velocity_threshold: float = 12.0
@export var stuck_timeout: float = 0.45
@export var enemy_group: StringName = &"enemy"

@export_category("Avoidance")
@export var separation_radius: float = 42.0
@export var separation_strength: float = 1.25
@export var avoidance_weight: float = 0.28
@export var crowd_slowdown_radius: float = 54.0
@export var crowd_slowdown_strength: float = 0.22

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _time_since_repath: float = 0.0
var _last_requested_target: Vector2 = Vector2.INF
var _stuck_time: float = 0.0

@onready var body: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _navigation_service: GridNavigationService = _resolve_navigation_service()

func get_steering(delta: float, target_position: Vector2, use_separation: bool = true) -> Dictionary:
	if body == null:
		return {
			"direction": Vector2.ZERO,
			"path_direction": Vector2.ZERO,
			"separation": Vector2.ZERO,
			"speed_multiplier": 1.0,
		}

	_time_since_repath += delta
	_update_path(target_position)

	var path_direction := _get_path_direction(target_position)
	var separation := _compute_separation() if use_separation else Vector2.ZERO
	var direction := _blend_directions(path_direction, separation)
	var speed_multiplier := _compute_speed_multiplier() if use_separation else 1.0
	_update_stuck_state(delta, direction, target_position)

	return {
		"direction": direction,
		"path_direction": path_direction,
		"separation": separation,
		"speed_multiplier": speed_multiplier,
	}

func clear_path() -> void:
	_path = PackedVector2Array()
	_path_index = 0
	_time_since_repath = 0.0
	_last_requested_target = Vector2.INF
	_stuck_time = 0.0

func _update_path(target_position: Vector2) -> void:
	var needs_repath := _path.is_empty()
	needs_repath = needs_repath or _time_since_repath >= repath_interval
	needs_repath = needs_repath or _last_requested_target == Vector2.INF
	needs_repath = needs_repath or _last_requested_target.distance_to(target_position) >= repath_distance

	if not needs_repath:
		return

	if _navigation_service == null:
		_path = PackedVector2Array()
		_path.append(target_position)
	else:
		_path = _navigation_service.get_world_path(body.global_position, target_position)
	_path_index = 0
	_time_since_repath = 0.0
	_last_requested_target = target_position

func _get_path_direction(target_position: Vector2) -> Vector2:
	if body.global_position.distance_to(target_position) <= fallback_direct_distance:
		return (target_position - body.global_position).normalized()

	while _path_index < _path.size():
		var waypoint := _path[_path_index]
		if body.global_position.distance_to(waypoint) > path_point_reach_distance:
			break
		_path_index += 1

	if _path_index >= _path.size():
		return (target_position - body.global_position).normalized()

	return (_path[_path_index] - body.global_position).normalized()

func _compute_separation() -> Vector2:
	var separation := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(enemy_group):
		if node == body or not (node is CharacterBody2D):
			continue

		var other := node as CharacterBody2D
		var offset := body.global_position - other.global_position
		var distance := offset.length()
		if distance <= 0.001 or distance >= separation_radius:
			continue

		var strength := (1.0 - (distance / separation_radius)) * separation_strength
		separation += offset / distance * strength

	return separation.limit_length(1.0)

func _blend_directions(path_direction: Vector2, separation: Vector2) -> Vector2:
	if path_direction == Vector2.ZERO:
		return separation
	if separation == Vector2.ZERO:
		return path_direction

	# Keep the path-following direction dominant so enemies stay aggressive, while
	# allowing nearby bodies to deflect them enough to avoid locking into each other.
	return (path_direction * (1.0 - avoidance_weight) + separation * avoidance_weight).normalized()

func _compute_speed_multiplier() -> float:
	var nearest_neighbor := crowd_slowdown_radius
	for node in get_tree().get_nodes_in_group(enemy_group):
		if node == body or not (node is CharacterBody2D):
			continue
		var other := node as CharacterBody2D
		nearest_neighbor = minf(nearest_neighbor, body.global_position.distance_to(other.global_position))

	if nearest_neighbor >= crowd_slowdown_radius:
		return 1.0

	var crowd_amount := 1.0 - (nearest_neighbor / crowd_slowdown_radius)
	return clampf(1.0 - crowd_amount * crowd_slowdown_strength, 1.0 - crowd_slowdown_strength, 1.0)

func _update_stuck_state(delta: float, desired_direction: Vector2, target_position: Vector2) -> void:
	if desired_direction == Vector2.ZERO or body.global_position.distance_to(target_position) <= fallback_direct_distance:
		_stuck_time = 0.0
		return

	if body.velocity.length() > stuck_velocity_threshold:
		_stuck_time = 0.0
		return

	_stuck_time += delta
	if _stuck_time < stuck_timeout:
		return

	# A forced repath lets the enemy recover if a crowd or wall briefly blocks its lane.
	_time_since_repath = repath_interval
	_stuck_time = 0.0

func _resolve_navigation_service() -> GridNavigationService:
	return get_tree().get_first_node_in_group("grid_navigation_service") as GridNavigationService
