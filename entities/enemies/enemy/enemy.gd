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
@export var patrol_radius: float = 112.0
@export var patrol_idle_time: Vector2 = Vector2(1.0, 2.0)
@export var patrol_repath_distance: float = 8.0
@export var patrol_snap_distance: float = 16.0
## How far into the patrol radius (0-1) the soft boundary weighting begins.
## 0.0 = active everywhere, 1.0 = only exactly at the edge.
@export_range(0.0, 1.0, 0.05) var patrol_edge_bias_start: float = 0.65
## How strongly outward-pointing directions are down-weighted near the edge.
## Higher = harder boundary. 0 disables the effect entirely.
@export_range(0.0, 3.0, 0.05) var patrol_edge_bias_strength: float = 1.5
@export var patrol_point_min_distance: float = 12.0
@export var patrol_arrival_radius: float = 12.0
@export var patrol_slow_radius: float = 36.0
@export var patrol_wander_duration: Vector2 = Vector2(1.5, 3.0)
@export_range(0.1, 1.0, 0.05) var patrol_move_speed_scale: float = 0.45
@export_range(0.1, 1.0, 0.05) var patrol_return_speed_scale: float = 0.55
@export var patrol_return_distance: float = 132.0
@export var patrol_return_slow_radius: float = 52.0
@export var patrol_target_retry_count: int = 8
@export var patrol_direction_continuity: float = 6.0
@export var patrol_anchor_to_spawn: bool = true

# Steering
@export_category("Steering")
@export var steering_sample_count: int = 16
@export var steering_obstacle_check_distance: float = 56.0
@export_flags_2d_physics var steering_obstacle_mask: int = 1
@export var steering_interest_strength: float = 1.0
@export var steering_danger_strength: float = 1.2
@export_range(0.0, 1.0, 0.01) var steering_smoothing: float = 0.18
@export_range(0.0, 1.0, 0.01) var steering_dead_zone: float = 0.04
@export_range(0.0, 1.0, 0.01) var steering_commitment_strength: float = 0.55
@export_range(0.0, 1.0, 0.01) var steering_chase_commitment_strength: float = 0.25
@export_range(0.0, 1.0, 0.01) var steering_inertia_weight: float = 0.65
@export var steering_interest_curve: float = 1.6
@export var steering_commitment_curve: float = 1.4
@export_range(1.0, 2.0, 0.05) var chase_move_speed_scale: float = 1.15

# Debug
@export_category("Debug")
@export var debug_patrol_vectors: bool = true
@export var steering_debug_radius: float = 56.0

# Attack
@export_category("Attack")
@export var attack_range: float = 46.0
@export var attack_windup_ratio: float = 0.4

# Runtime state
var state: State = State.IDLE
var spawn_position: Vector2
var facing_direction: Vector2 = Vector2.DOWN
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

@onready var stats_component: StatsComponent = $StatsComponent
@onready var health_component: HealthComponent = $StatsComponent/HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var ai_component: EnemyAIComponent = $EnemyAIComponent
@onready var navigation_component: EnemyNavigationComponent = $EnemyNavigationComponent
@onready var steering_component: EnemySteeringComponent = $EnemySteeringComponent
@onready var wander_component: EnemyWanderComponent = $EnemyWanderComponent
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

	spawn_position = global_position
	navigation_target_position = spawn_position

	steering_component.setup(self)
	navigation_component.setup(self, movement_component, navigation_agent, steering_component)
	wander_component.setup(self, navigation_component)
	wander_component.set_wander_origin(spawn_position)
	ai_component.setup(self, movement_component, navigation_component, wander_component)
	attack_component.setup(self, combat_component, hit_box, hit_box_shape)

	hitbox_base_position = hit_box.position
	hitbox_base_rotation = hit_box.rotation
	hitbox_base_scale = hit_box.scale
	attack_component.set_attack_hitbox_enabled(false)
	navigation_component._configure_navigation_agent()
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


func _on_health_component_died() -> void:
	state = State.DEAD
	movement_component.stop_immediately()
	attack_component.set_attack_hitbox_enabled(false)
	velocity = Vector2.ZERO
	steering_component.clear_debug_data()
	death()

func _on_hit_box_body_entered(body: Node2D) -> void:
	attack_component._try_attack_target(body)
