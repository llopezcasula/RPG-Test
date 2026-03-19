extends Node2D
class_name EnemySteeringDebug

@export var steering_component_path: NodePath = ^"../EnemySteeringComponent"

@onready var steering_component: EnemySteeringComponent = get_node_or_null(steering_component_path) as EnemySteeringComponent
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
	var fallback_font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	var text_offset := Vector2(0.0, -8.0)

	for i in directions.size():
		var direction: Vector2 = directions[i]
		var end_point := direction * draw_radius
		var final_end := Vector2.ZERO
		draw_line(Vector2.ZERO, end_point, Color(1.0, 1.0, 1.0, 0.12), 1.0)

		if interest.size() == directions.size():
			draw_line(Vector2.ZERO, direction * (draw_radius * interest[i]), Color(0.2, 0.95, 0.35, 0.85), 1.5)

		if danger.size() == directions.size():
			draw_line(Vector2.ZERO, direction * (draw_radius * danger[i]), Color(0.95, 0.2, 0.25, 0.75), 1.5)

		if final_weights.size() == directions.size():
			final_end = direction * (draw_radius * final_weights[i])
			draw_line(Vector2.ZERO, final_end, Color(0.15, 0.85, 1.0, 0.95), 2.0)
			draw_circle(final_end, 2.0, Color(0.15, 0.85, 1.0, 0.95))

		if fallback_font != null and final_weights.size() == directions.size() and final_weights[i] > 0.0:
			var desire_length := draw_radius * final_weights[i]
			var label := enemy._snapped_weight_text(desire_length)
			draw_string(fallback_font, final_end + text_offset, label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(0.95, 0.95, 0.95, 0.8))

	if steering_component.last_steering != Vector2.ZERO:
		draw_line(Vector2.ZERO, steering_component.last_steering * draw_radius, Color.GOLD, 3.0)

	if steering_component.last_target_position != Vector2.ZERO:
		draw_circle(to_local(steering_component.last_target_position), 4.0, Color.DEEP_SKY_BLUE)

	if steering_component.last_mode == &"patrol":
		draw_arc(to_local(enemy.spawn_position), enemy.patrol_radius, 0.0, TAU, 48, Color(0.4, 0.7, 1.0, 0.35), 1.5)
