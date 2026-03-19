extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

@export_category("Combat")
@export var debug_hitbox: bool = true

var state: State = State.IDLE
var hitbox_base_position: Vector2
var hitbox_base_rotation: float
var hitbox_base_scale: Vector2

@onready var stats_component: StatsComponent = $StatsComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var combat_component: CombatComponent = $CombatComponent
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"] as AnimationNodeStateMachinePlayback
@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_box: Area2D = $HitBox
@onready var hit_box_shape: CollisionShape2D = $HitBox/CollisionShape2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = deg_to_rad(5.0)
	animation_tree.active = true

	hitbox_base_position = hit_box.position
	hitbox_base_rotation = hit_box.rotation
	hitbox_base_scale = hit_box.scale

	set_attack_hitbox_enabled(false)
	update_animation()

	var health_component := get_health_component()
	if health_component != null:
		health_component.died.connect(_on_health_component_died)

	if debug_hitbox:
		print("base hitbox position: ", hitbox_base_position)
		print("base hitbox rotation: ", rad_to_deg(hitbox_base_rotation))
		print("shape local position: ", hit_box_shape.position)
		print("shape local rotation: ", rad_to_deg(hit_box_shape.rotation))

func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		movement_component.stop_immediately()
		return

	if state == State.ATTACK:
		movement_component.decelerate_to_stop(delta)
		return

	movement_component.physics_update(delta)
	update_movement_state()

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
		State.ATTACK:
			animation_playback.travel("attack")

func attack() -> void:
	if state == State.ATTACK or state == State.DEAD:
		return

	state = State.ATTACK
	set_attack_hitbox_enabled(true)

	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()

	sprite.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)

	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale

	if debug_hitbox:
		print("attack_dir: ", attack_dir)
		print("hitbox local position: ", hit_box.position)
		print("hitbox global position: ", hit_box.global_position)
		print("hitbox rotation deg: ", rad_to_deg(hit_box.rotation))

	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	update_animation()

	await get_tree().create_timer(get_attack_speed()).timeout

	if state == State.DEAD:
		return

	set_attack_hitbox_enabled(false)
	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale

	state = State.IDLE
	update_animation()

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

func get_attack_speed() -> float:
	if combat_component == null:
		return 0.6
	return combat_component.get_attack_speed()

func set_attack_hitbox_enabled(enabled: bool) -> void:
	hit_box.monitoring = enabled
	hit_box_shape.disabled = not enabled

func _on_health_component_died() -> void:
	state = State.DEAD
	movement_component.stop_immediately()
	set_attack_hitbox_enabled(false)
	velocity = Vector2.ZERO

func _on_hit_box_area_entered(area: Area2D) -> void:
	if combat_component == null:
		return
	if area.owner != null:
		combat_component.attack_target(area.owner)
