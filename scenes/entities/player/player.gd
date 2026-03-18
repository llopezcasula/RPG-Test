extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

@export_category("Stats")
@export var speed: int = 400
@export var attack_speed: float = 0.6

var state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback = animation_tree["parameters/playback"] as AnimationNodeStateMachinePlayback


func _ready() -> void:
	animation_tree.active = true
	update_animation()
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack()


func _physics_process(delta: float) -> void:
	if state != State.ATTACK:
		movement_loop()


func movement_loop() -> void:
	move_direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	move_direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	velocity = move_direction.normalized() * speed
	move_and_slide()

	if state == State.IDLE or state == State.RUN:
		if move_direction.x < -0.01:
			$Sprite2D.flip_h = true
		elif move_direction.x > 0.01:
			$Sprite2D.flip_h = false

	if move_direction != Vector2.ZERO:
		if state != State.RUN:
			state = State.RUN
			update_animation()
	else:
		if state != State.IDLE:
			state = State.IDLE
			update_animation()


func update_animation() -> void:
	print("changing animation to state:", state)

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
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()
	$Sprite2D.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	update_animation()
	
	await get_tree().create_timer(attack_speed).timeout
	state = State.IDLE
	update_animation()
	
