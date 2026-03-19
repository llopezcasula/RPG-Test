extends CharacterBody2D
class_name Enemy

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

# Scene references
@export_category("Scene References")
@export var death_packed: PackedScene

# AI tuning
@export_category("AI")
@export var player_group: StringName = &"player"
@export var detection_radius: float = 240.0
@export var disengage_radius: float = 320.0
@export var attack_range: float = 46.0

# Navigation tuning
@export_category("Navigation")
@export var repath_interval: float = 0.2
@export var path_desired_distance: float = 12.0
@export var target_desired_distance: float = 18.0

# Attack tuning
@export_category("Attack")
@export_range(0.0, 1.0, 0.01) var attack_windup_ratio: float = 0.4

# Runtime state
var state: State = State.IDLE
var current_target: CharacterBody2D
var facing_direction: Vector2 = Vector2.DOWN
var attack_cooldown_remaining: float = 0.0

# Component references
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

	navigation_component.setup(self, movement_component, navigation_agent)
	navigation_component.configure_agent()
	attack_component.setup(self, combat_component, hit_box, hit_box_shape)
	ai_component.setup(self, navigation_component, attack_component)

	attack_component.set_attack_hitbox_enabled(false)
	update_animation()

	if attack_component.attack_finished.is_connected(_on_attack_finished) == false:
		attack_component.attack_finished.connect(_on_attack_finished)

	if health_component != null:
		health_component.died.connect(_on_health_component_died)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		stop_movement()
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	ai_component.physics_update(delta)
	movement_component.physics_update(delta)
	_update_state_from_velocity()

func take_damage(damage_taken: float, source: Node = null) -> float:
	if source is CharacterBody2D:
		current_target = source

	if combat_component != null:
		return combat_component.take_damage(damage_taken, source)

	if health_component == null:
		return 0.0

	return health_component.take_damage(damage_taken)

func get_health_component() -> HealthComponent:
	return health_component

func set_state(next_state: State) -> void:
	if state == next_state:
		return

	state = next_state
	update_animation()

func stop_movement() -> void:
	movement_component.stop_immediately()
	navigation_component.stop()

func update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	facing_direction = direction.normalized()
	if absf(facing_direction.x) >= absf(facing_direction.y):
		sprite.flip_h = facing_direction.x < 0.0
	else:
		sprite.flip_h = false

func can_attack() -> bool:
	return attack_cooldown_remaining <= 0.0 and not attack_component.is_attacking()

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

func _update_state_from_velocity() -> void:
	if state == State.ATTACK or state == State.DEAD:
		return

	if velocity.length_squared() > 1.0:
		set_state(State.CHASE)
	else:
		velocity = Vector2.ZERO
		set_state(State.IDLE)

func update_animation() -> void:
	match state:
		State.IDLE:
			animation_playback.travel("idle")
		State.CHASE:
			animation_playback.travel("run")
		State.ATTACK:
			animation_playback.travel("attack")
		State.DEAD:
			animation_playback.travel("idle")

func _on_attack_finished() -> void:
	if state != State.DEAD:
		set_state(State.IDLE)

func _on_health_component_died() -> void:
	set_state(State.DEAD)
	stop_movement()
	attack_component.cancel_attack()
	velocity = Vector2.ZERO
	death()

func _on_hit_box_body_entered(body: Node2D) -> void:
	attack_component.try_attack_target(body)
