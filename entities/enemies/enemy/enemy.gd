extends CharacterBody2D
class_name Enemy


enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

@export_category("Related Scenes")
@export var death_packed: PackedScene

# AI
@export_category("AI")
@export var player_group: StringName = &"player"
@export var detection_radius: float = 240.0
@export var disengage_radius: float = 320.0

# Navigation
@export_category("Navigation")
@export var repath_interval: float = 0.2
@export var target_refresh_distance: float = 16.0
@export var path_desired_distance: float = 12.0
@export var target_desired_distance: float = 18.0
@export var attack_slowdown_distance: float = 28.0

# Navigation Avoidance
@export_category("Avoidance")
@export var avoidance_enabled: bool = true
@export var agent_radius: float = 18.0
@export var neighbor_distance: float = 96.0
@export var max_neighbors: int = 8
@export var time_horizon: float = 0.8

# Patrol
@export_category("Patrol")
@export var patrol_radius: float = 72.0
@export var patrol_idle_time: Vector2 = Vector2(1.0, 2.0)
@export var patrol_repath_distance: float = 8.0
@export var patrol_snap_distance: float = 16.0
@export var patrol_leash_strength: float = 1.35
@export var patrol_point_min_distance: float = 12.0
@export var patrol_vector_count: int = 16
@export var patrol_probe_length: float = 56.0
@export var patrol_danger_weight: float = 1.2
@export var patrol_arrival_distance: float = 10.0
@export_flags_2d_physics var patrol_obstacle_mask: int = 1

# Debug
@export_category("Debug")
@export var debug_patrol_vectors: bool = true
@export var debug_weight_decimals: int = 2

# Attack
@export_category("Attack")
@export var attack_range: float = 46.0
@export var attack_windup_ratio: float = 0.4

# Runtime state
var state: State = State.IDLE
var spawn_position: Vector2
var facing_direction: Vector2 = Vector2.DOWN
var patrol_target: Vector2
var patrol_wait_time: float = 0.0
var attack_cooldown_remaining: float = 0.0
var aggro_locked: bool = false
var current_target: CharacterBody2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var attack_hit_targets: Array[Node] = []
var hitbox_base_position: Vector2
var hitbox_base_rotation: float
var hitbox_base_scale: Vector2
var navigation_target_position: Vector2
var navigation_repath_remaining: float = 0.0
var has_navigation_target: bool = false
var safe_navigation_velocity: Vector2 = Vector2.ZERO
var patrol_debug_directions: Array[Vector2] = []
var patrol_debug_interest: Array[float] = []
var patrol_debug_danger: Array[float] = []
var patrol_debug_scores: Array[float] = []
var patrol_debug_result: Vector2 = Vector2.ZERO

@onready var stats_component: StatsComponent = $StatsComponent
@onready var health_component: HealthComponent = $StatsComponent/HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var ai_component: EnemyAIComponent = $EnemyAIComponent
@onready var navigation_component: EnemyNavigationComponent = $EnemyNavigationComponent
@onready var attack_component: EnemyAttackComponent = $EnemyAttackComponent
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"] as AnimationNodeStateMachinePlayback
@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_box: Area2D = $HitBox
@onready var hit_box_shape: CollisionShape2D = $HitBox/CollisionShape2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = deg_to_rad(5.0)
	animation_tree.active = true
	rng.randomize()

	ai_component.setup(self, movement_component, navigation_component)
	navigation_component.setup(self, movement_component, navigation_agent)
	attack_component.setup(self, combat_component, hit_box, hit_box_shape)

	hitbox_base_position = hit_box.position
	hitbox_base_rotation = hit_box.rotation
	hitbox_base_scale = hit_box.scale
	attack_component.set_attack_hitbox_enabled(false)
	navigation_component._configure_navigation_agent()
	spawn_position = navigation_component._get_closest_navigation_point(global_position)
	patrol_target = spawn_position
	navigation_target_position = spawn_position
	_clear_patrol_debug()
	update_animation()
	ai_component._resolve_target()

	if health_component != null:
		health_component.died.connect(_on_health_component_died)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		movement_component.stop_immediately()
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	if navigation_repath_remaining > 0.0:
		navigation_repath_remaining = maxf(navigation_repath_remaining - delta, 0.0)

	if current_target == null or not is_instance_valid(current_target):
		ai_component._resolve_target()

	if ai_component._can_chase_target():
		ai_component._process_chase(delta)
	else:
		current_target = null
		aggro_locked = false
		ai_component._process_patrol(delta)

	movement_component.physics_update(delta)
	_update_state_from_velocity()
	if debug_patrol_vectors:
		queue_redraw()

func _draw() -> void:
	if not debug_patrol_vectors:
		return
	if patrol_debug_directions.is_empty():
		return

	var fallback_font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	var text_offset := Vector2(0.0, -8.0)

	for i in patrol_debug_directions.size():
		var direction: Vector2 = patrol_debug_directions[i]
		var interest: float = patrol_debug_interest[i]
		var danger: float = patrol_debug_danger[i]
		var score: float = patrol_debug_scores[i]
		var line_length: float = lerpf(18.0, patrol_probe_length, clampf(score, 0.0, 1.0))
		var end_point: Vector2 = direction * line_length
		var line_color := Color(0.2 + 0.8 * danger, 0.2 + 0.8 * score, 0.2 + 0.8 * interest, 0.95)
		draw_line(Vector2.ZERO, end_point, line_color, 2.0)
		draw_circle(end_point, 2.5, line_color)
		if fallback_font != null:
			var label := "%s|%s|%s" % [
				_snapped_weight_text(interest),
				_snapped_weight_text(danger),
				_snapped_weight_text(score)
			]
			draw_string(fallback_font, end_point + text_offset, label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, line_color)

	if patrol_debug_result != Vector2.ZERO:
		draw_line(Vector2.ZERO, patrol_debug_result * patrol_probe_length, Color.GOLD, 3.0)
		draw_circle(patrol_target - global_position, 4.0, Color.DEEP_SKY_BLUE)
		draw_arc(spawn_position - global_position, patrol_radius, 0.0, TAU, 48, Color(0.4, 0.7, 1.0, 0.35), 1.5)

func take_damage(damage_taken: float, source: Node = null) -> float:
	if source is CharacterBody2D:
		current_target = source
		aggro_locked = true

	if combat_component != null:
		return combat_component.take_damage(damage_taken, source)

	if health_component == null:
		return 0.0

	return health_component.take_damage(damage_taken)

func get_health_component() -> HealthComponent:
	return health_component

func death() -> void:
	var death_scene: Node2D = death_packed.instantiate() as Node2D
	if death_scene == null:
		queue_free()
		return

	var effect_parent: Node2D = %Effects as Node2D
	if effect_parent == null:
		effect_parent = get_parent() as Node2D

	if effect_parent != null:
		effect_parent.add_child(death_scene)
		death_scene.global_position = global_position

	queue_free()

func _clear_navigation_motion() -> void:
	movement_component.set_move_direction(Vector2.ZERO)
	navigation_agent.velocity = Vector2.ZERO
	safe_navigation_velocity = Vector2.ZERO

func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	facing_direction = direction.normalized()
	if absf(facing_direction.x) >= absf(facing_direction.y):
		sprite.flip_h = facing_direction.x < 0.0
	else:
		sprite.flip_h = false

func _update_state_from_velocity() -> void:
	if state == State.ATTACK:
		return

	if velocity.length_squared() > 1.0:
		if state != State.RUN:
			state = State.RUN
			update_animation()
	else:
		velocity = Vector2.ZERO
		if state != State.IDLE:
			state = State.IDLE
			update_animation()

func update_animation() -> void:
	match state:
		State.IDLE:
			animation_playback.travel("idle")
		State.RUN:
			animation_playback.travel("run")
		State.ATTACK:
			animation_playback.travel("attack")

func _compute_patrol_direction() -> Vector2:
	_clear_patrol_debug()

	var to_target: Vector2 = patrol_target - global_position
	var desired_direction: Vector2 = to_target.normalized() if to_target.length_squared() > 0.001 else Vector2.ZERO
	var to_spawn: Vector2 = spawn_position - global_position
	var leash_distance: float = to_spawn.length()
	var leash_ratio: float = clampf(leash_distance / maxf(patrol_radius, 0.001), 0.0, 1.5)
	var leash_direction: Vector2 = to_spawn.normalized() if leash_distance > 0.001 else Vector2.ZERO
	var space_state := get_world_2d().direct_space_state
	var combined_vector := Vector2.ZERO
	var sample_count: int = maxi(patrol_vector_count, 4)

	for i in sample_count:
		var angle: float = TAU * float(i) / float(sample_count)
		var direction := Vector2.RIGHT.rotated(angle)
		var interest := maxf(direction.dot(desired_direction), 0.0)
		if leash_direction != Vector2.ZERO:
			interest += maxf(direction.dot(leash_direction), 0.0) * maxf(leash_ratio - 0.65, 0.0) * patrol_leash_strength
		interest = clampf(interest, 0.0, 1.0)

		var danger := 0.0
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * patrol_probe_length, patrol_obstacle_mask)
		query.exclude = [self]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector2 = hit["position"]
			var hit_ratio := 1.0 - clampf(global_position.distance_to(hit_position) / patrol_probe_length, 0.0, 1.0)
			danger = maxf(danger, hit_ratio)

		if leash_distance > patrol_radius and leash_direction != Vector2.ZERO:
			var outward_alignment := maxf(direction.dot(-leash_direction), 0.0)
			danger = maxf(danger, outward_alignment * clampf((leash_distance - patrol_radius) / maxf(patrol_radius, 0.001), 0.0, 1.0))

		var score := clampf(interest - danger * patrol_danger_weight, 0.0, 1.0)
		combined_vector += direction * score
		patrol_debug_directions.append(direction)
		patrol_debug_interest.append(interest)
		patrol_debug_danger.append(danger)
		patrol_debug_scores.append(score)

	patrol_debug_result = combined_vector.normalized() if combined_vector.length_squared() > 0.001 else Vector2.ZERO
	return patrol_debug_result

func _clear_patrol_debug() -> void:
	patrol_debug_directions.clear()
	patrol_debug_interest.clear()
	patrol_debug_danger.clear()
	patrol_debug_scores.clear()
	patrol_debug_result = Vector2.ZERO

func _snapped_weight_text(value: float) -> String:
	return String.num(value, clampi(debug_weight_decimals, 0, 4))

func _on_health_component_died() -> void:
	state = State.DEAD
	movement_component.stop_immediately()
	attack_component.set_attack_hitbox_enabled(false)
	velocity = Vector2.ZERO
	_clear_patrol_debug()
	death()

func _on_hit_box_body_entered(body: Node2D) -> void:
	attack_component._try_attack_target(body)
