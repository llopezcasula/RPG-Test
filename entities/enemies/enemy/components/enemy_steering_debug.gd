extends Node2D
class_name EnemySteeringDebug

@export var steering_component_path: NodePath = ^"../EnemySteeringComponent"
@export var wander_component_path: NodePath = ^"../EnemyWanderComponent"

@onready var steering_component: EnemySteeringComponent = get_node_or_null(steering_component_path) as EnemySteeringComponent
@onready var wander_component: EnemyWanderComponent = get_node_or_null(wander_component_path) as EnemyWanderComponent
@onready var enemy: Enemy = get_parent() as Enemy

func _process(_delta: float) -> void:
	if enemy != null and enemy.debug_patrol_vectors:
		queue_redraw()

func _draw() -> void:
	if enemy == null or steering_component == null:
		return
	if not enemy.debug_patrol_vectors:
		return
	if steering_component.sample_directions.is_empty():
		return

	var draw_radius := enemy.steering_debug_radius
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.65), 1.5)

	var directions := steering_component.sample_directions
	var interest := steering_component.last_interest
	var danger := steering_component.last_danger
	var final_weights := steering_component.last_final
	for i in directions.size():
		var direction: Vector2 = directions[i]
		var end_point := direction * draw_radius
		draw_line(Vector2.ZERO, end_point, Color(1.0, 1.0, 1.0, 0.12), 1.0)

		if interest.size() == directions.size():
			draw_line(Vector2.ZERO, direction * (draw_radius * interest[i]), Color(0.2, 0.95, 0.35, 0.85), 1.5)

		if danger.size() == directions.size():
			draw_line(Vector2.ZERO, direction * (draw_radius * danger[i]), Color(0.95, 0.2, 0.25, 0.75), 1.5)

		if final_weights.size() == directions.size():
			var final_end := direction * (draw_radius * final_weights[i])
			draw_line(Vector2.ZERO, final_end, Color(0.15, 0.85, 1.0, 0.95), 2.0)
			draw_circle(final_end, 2.0, Color(0.15, 0.85, 1.0, 0.95))

	if steering_component.last_steering != Vector2.ZERO:
		draw_line(Vector2.ZERO, steering_component.last_steering * draw_radius, Color.GOLD, 3.0)

	if steering_component.last_interest_position != Vector2.ZERO:
		draw_circle(to_local(steering_component.last_interest_position), 4.0, Color.DEEP_SKY_BLUE)

	if wander_component != null and wander_component.has_wander_origin:
		var home_position := wander_component._get_home_position()
		draw_arc(to_local(home_position), enemy.patrol_radius, 0.0, TAU, 48, Color(0.4, 0.7, 1.0, 0.35), 1.5)
		if wander_component.has_wander_target:
			var local_target := to_local(wander_component.wander_target)
			var target_color := Color(0.3, 0.9, 1.0, 0.55)
			draw_circle(local_target, enemy.patrol_arrival_radius, Color(target_color.r, target_color.g, target_color.b, 0.18))
			draw_arc(local_target, enemy.patrol_slow_radius, 0.0, TAU, 32, Color(target_color.r, target_color.g, target_color.b, 0.28), 1.0)
