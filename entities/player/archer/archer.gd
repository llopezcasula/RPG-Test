extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	DEAD
}

@export_category("Related Scenes")
@export var death_packed: PackedScene

@export_category("Movement")
@export var arrival_distance: float = 10.0

var state: State = State.IDLE
var has_move_target: bool = false
var move_target: Vector2 = Vector2.ZERO

@onready var stats_component: StatsComponent = $StatsComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"] as AnimationNodeStateMachinePlayback
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	wall_min_slide_angle = deg_to_rad(5.0)
	animation_tree.active = true
	movement_component.use_input_actions = false
	update_animation()

	var health_component := get_health_component()
	if health_component != null:
		health_component.died.connect(_on_health_component_died)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		movement_component.stop_immediately()
		return

	_update_move_target()
	movement_component.physics_update(delta)
	update_movement_state()

func set_move_target(world_position: Vector2) -> void:
	if state == State.DEAD:
		return

	move_target = world_position
	has_move_target = true

func clear_move_target() -> void:
	has_move_target = false
	movement_component.stop_immediately()

func _update_move_target() -> void:
	if not has_move_target:
		movement_component.set_move_direction(Vector2.ZERO)
		return

	var to_target: Vector2 = move_target - global_position
	if to_target.length() <= arrival_distance:
		has_move_target = false
		movement_component.stop_immediately()
		return

	movement_component.set_move_direction(to_target.normalized())

func update_movement_state() -> void:
	var move_direction: Vector2 = movement_component.get_move_direction()

	if state == State.IDLE or state == State.RUN:
		if move_direction.x < -0.01:
			sprite.flip_h = true
		elif move_direction.x > 0.01:
			sprite.flip_h = false

	if move_direction != Vector2.ZERO:
		if state != State.RUN:
			state = State.RUN
			update_animation()
	elif velocity.length_squared() < 1.0:
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

func take_damage(damage_taken: float, source: Node = null) -> float:
	if combat_component != null:
		return combat_component.take_damage(damage_taken, source)

	var health_component := get_health_component()
	if health_component == null:
		return 0.0

	return health_component.take_damage(damage_taken)

func get_health_component() -> HealthComponent:
	if stats_component == null:
		return null
	return stats_component.get_node_or_null("HealthComponent") as HealthComponent

func death() -> void:
	if death_packed == null:
		return

	var death_scene: Node2D = death_packed.instantiate()
	var effect_parent := %Effects as Node2D
	if effect_parent == null:
		effect_parent = get_parent() as Node2D

	if effect_parent != null:
		effect_parent.add_child(death_scene)
		death_scene.global_position = global_position

func _on_health_component_died() -> void:
	state = State.DEAD
	has_move_target = false
	movement_component.stop_immediately()
	velocity = Vector2.ZERO
	collision_shape.disabled = true
	sprite.visible = false
	death()
