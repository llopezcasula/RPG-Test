extends CharacterBody2D


enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD
}

@export_category("Related Scenes")
@export var death_packed: PackedScene

@export_category("AI")
@export var player_group: StringName = &"player"
@export var detection_radius: float = 240.0
@export var disengage_radius: float = 320.0
@export var attack_range: float = 46.0
@export var attack_windup_ratio: float = 0.4
@export var patrol_radius: float = 72.0
@export var patrol_idle_time: Vector2 = Vector2(1.0, 2.0)
@export var patrol_repath_distance: float = 8.0

var state: State = State.IDLE
var spawn_position: Vector2
var facing_direction: Vector2 = Vector2.DOWN
var patrol_target: Vector2
var patrol_wait_time: float = 0.0
var attack_cooldown_remaining: float = 0.0
var aggro_locked: bool = false
var current_target: CharacterBody2D
var rng := RandomNumberGenerator.new()
var attack_hit_targets: Array[Node] = []
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
	rng.randomize()
	spawn_position = global_position
	patrol_target = spawn_position
	hitbox_base_position = hit_box.position
	hitbox_base_rotation = hit_box.rotation
	hitbox_base_scale = hit_box.scale
	set_attack_hitbox_enabled(false)
	update_animation()
	_resolve_target()

	var health_component := get_health_component()
	if health_component != null:
		health_component.died.connect(_on_health_component_died)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		movement_component.stop_immediately()
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	if current_target == null or not is_instance_valid(current_target):
		_resolve_target()

	if _can_chase_target():
		_process_chase(delta)
	else:
		current_target = null
		_process_patrol(delta)

	movement_component.physics_update(delta)
	_update_state_from_velocity()

func take_damage(damage_taken: float, source: Node = null) -> float:
	if source is CharacterBody2D:
		current_target = source
		aggro_locked = true

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
	var death_scene: Node2D = death_packed.instantiate()

	var effect_parent := %Effects as Node2D
	if effect_parent == null:
		effect_parent = get_parent() as Node2D

	if effect_parent != null:
		effect_parent.add_child(death_scene)
		death_scene.global_position = global_position

	queue_free()

func _process_chase(delta: float) -> void:
	if current_target == null:
		movement_component.set_move_direction(Vector2.ZERO)
		return

	var to_target := current_target.global_position - global_position
	var distance_to_target := to_target.length()
	if distance_to_target <= 0.001:
		movement_component.set_move_direction(Vector2.ZERO)
		return

	var direction := to_target / distance_to_target
	_update_facing(direction)

	if distance_to_target <= attack_range:
		movement_component.set_move_direction(Vector2.ZERO)
		if attack_cooldown_remaining <= 0.0 and state != State.ATTACK:
			_start_attack(direction)
		return

	if state == State.ATTACK:
		movement_component.decelerate_to_stop(delta)
		return

	movement_component.set_move_direction(direction)

func _process_patrol(delta: float) -> void:
	if state == State.ATTACK:
		movement_component.decelerate_to_stop(delta)
		return

	if global_position.distance_to(patrol_target) <= patrol_repath_distance:
		movement_component.set_move_direction(Vector2.ZERO)
		patrol_wait_time -= delta
		if patrol_wait_time <= 0.0:
			_pick_next_patrol_target()
		return

	var direction := (patrol_target - global_position).normalized()
	_update_facing(direction)
	movement_component.set_move_direction(direction)

func _pick_next_patrol_target() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(12.0, patrol_radius)
	patrol_target = spawn_position + Vector2.RIGHT.rotated(angle) * distance
	patrol_wait_time = rng.randf_range(patrol_idle_time.x, patrol_idle_time.y)

func _can_chase_target() -> bool:
	if current_target == null or not is_instance_valid(current_target):
		aggro_locked = false
		return false

	var distance_to_target := global_position.distance_to(current_target.global_position)
	if distance_to_target <= detection_radius:
		aggro_locked = true

	if aggro_locked and distance_to_target <= disengage_radius:
		return true

	aggro_locked = false
	return false

func _resolve_target() -> void:
	current_target = get_tree().get_first_node_in_group(player_group) as CharacterBody2D

func _start_attack(direction: Vector2) -> void:
	state = State.ATTACK
	attack_hit_targets.clear()
	_update_facing(direction)
	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale
	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", facing_direction)
	update_animation()
	attack_cooldown_remaining = combat_component.get_attack_speed() if combat_component != null else 0.6
	_perform_attack_after_windup()

func _perform_attack_after_windup() -> void:
	var attack_duration := attack_cooldown_remaining
	var windup := maxf(attack_duration * attack_windup_ratio, 0.01)
	await get_tree().create_timer(windup).timeout

	if state == State.DEAD or state != State.ATTACK:
		return

	set_attack_hitbox_enabled(true)
	_resolve_attack_hit_overlaps()

	var recovery := maxf(attack_duration - windup, 0.0)
	if recovery > 0.0:
		await get_tree().create_timer(recovery).timeout

	if state == State.DEAD:
		return

	set_attack_hitbox_enabled(false)
	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale
	attack_hit_targets.clear()
	state = State.IDLE
	update_animation()

func _resolve_attack_hit_overlaps() -> void:
	for body in hit_box.get_overlapping_bodies():
		_try_attack_target(body)

func _try_attack_target(target: Node) -> void:
	if combat_component == null or target == null:
		return
	if attack_hit_targets.has(target):
		return
	if not (target is CharacterBody2D):
		return

	attack_hit_targets.append(target)
	combat_component.attack_target(target)

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

func set_attack_hitbox_enabled(enabled: bool) -> void:
	hit_box.monitoring = enabled
	hit_box.monitorable = false
	hit_box_shape.disabled = not enabled

func _on_health_component_died() -> void:
	state = State.DEAD
	movement_component.stop_immediately()
	set_attack_hitbox_enabled(false)
	velocity = Vector2.ZERO
	death()

func _on_hit_box_body_entered(body: Node2D) -> void:
	_try_attack_target(body)
