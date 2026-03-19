extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

@export_category("Stats")
@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var attack_speed: float = 0.6
@export var attack_damage: int = 60
@export var debug_hitbox: bool = true

var state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var hitbox_base_position: Vector2
var hitbox_base_rotation: float
var hitbox_base_scale: Vector2
var attack_facing_left: bool = false

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

	if debug_hitbox:
		print("base hitbox position: ", hitbox_base_position)
		print("base hitbox rotation: ", rad_to_deg(hitbox_base_rotation))
		print("shape local position: ", hit_box_shape.position)
		print("shape local rotation: ", rad_to_deg(hit_box_shape.rotation))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack()

func _physics_process(delta: float) -> void:
	if state == State.ATTACK:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		move_and_slide()
		sync_attack_hitbox_transform()
		return

	movement_loop(delta)

func _process(_delta: float) -> void:
	if state == State.ATTACK:
		sync_attack_hitbox_transform()

func movement_loop(delta: float) -> void:
	move_direction = Input.get_vector("left", "right", "up", "down")

	var target_velocity: Vector2 = move_direction * speed
	var rate: float = acceleration if move_direction != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

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
	if state == State.ATTACK:
		return

	state = State.ATTACK
	set_attack_hitbox_enabled(true)

	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()

	attack_facing_left = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	sprite.flip_h = attack_facing_left

	# Reset to base first before the animation applies its current frame.
	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale

	if debug_hitbox:
		print("facing_left: ", attack_facing_left)
		print("attack_dir: ", attack_dir)
		print("hitbox local position: ", hit_box.position)
		print("hitbox global position: ", hit_box.global_position)
		print("hitbox rotation deg: ", rad_to_deg(hit_box.rotation))

	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	update_animation()
	sync_attack_hitbox_transform()

	await get_tree().create_timer(attack_speed).timeout

	set_attack_hitbox_enabled(false)
	attack_facing_left = false
	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale

	state = State.IDLE
	update_animation()


func sync_attack_hitbox_transform() -> void:
	if not attack_facing_left:
		return

	hit_box.position = Vector2(-abs(hit_box.position.x), hit_box.position.y)
	hit_box.rotation = -abs(hit_box.rotation)
	hit_box.scale = Vector2(-abs(hitbox_base_scale.x), hitbox_base_scale.y)

func set_attack_hitbox_enabled(enabled: bool) -> void:
	hit_box.monitoring = enabled
	hit_box_shape.disabled = not enabled

func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.owner != null and area.owner.has_method("take_damage"):
		area.owner.take_damage(attack_damage)
