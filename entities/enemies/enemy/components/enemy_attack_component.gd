extends Node
class_name EnemyAttackComponent

signal attack_finished

# Runtime state
var enemy: Enemy
var combat_component: CombatComponent
var hit_box: Area2D
var hit_box_shape: CollisionShape2D
var is_active_attack: bool = false
var attack_sequence_id: int = 0
var hitbox_base_position: Vector2 = Vector2.ZERO
var hitbox_base_rotation: float = 0.0
var hitbox_base_scale: Vector2 = Vector2.ONE
var attack_hit_targets: Array[Node] = []

func setup(owner_enemy: Enemy, owner_combat_component: CombatComponent, owner_hit_box: Area2D, owner_hit_box_shape: CollisionShape2D) -> void:
	enemy = owner_enemy
	combat_component = owner_combat_component
	hit_box = owner_hit_box
	hit_box_shape = owner_hit_box_shape
	hitbox_base_position = hit_box.position
	hitbox_base_rotation = hit_box.rotation
	hitbox_base_scale = hit_box.scale

func start_attack(direction: Vector2) -> void:
	if enemy == null or is_active_attack:
		return

	enemy.stop_movement()
	is_active_attack = true
	attack_sequence_id += 1
	attack_hit_targets.clear()
	enemy.attack_cooldown_remaining = combat_component.get_attack_speed() if combat_component != null else 0.6
	enemy.update_facing(direction)
	_reset_hitbox_transform()
	enemy.animation_tree.set("parameters/attack/BlendSpace2D/blend_position", enemy.facing_direction)
	enemy.update_animation()
	_run_attack_sequence(attack_sequence_id)

func cancel_attack() -> void:
	attack_sequence_id += 1
	_clear_attack_state()
	if enemy != null:
		enemy.stop_movement()

func is_attacking() -> bool:
	return is_active_attack

func try_attack_target(target: Node) -> void:
	if combat_component == null or target == null:
		return
	if attack_hit_targets.has(target):
		return
	if not (target is CharacterBody2D):
		return

	attack_hit_targets.append(target)
	combat_component.attack_target(target)

func set_attack_hitbox_enabled(enabled: bool) -> void:
	hit_box.monitoring = enabled
	hit_box.monitorable = false
	hit_box_shape.disabled = not enabled

func _run_attack_sequence(sequence_id: int) -> void:
	await _perform_attack(sequence_id)

func _perform_attack(sequence_id: int) -> void:
	var attack_duration: float = enemy.attack_cooldown_remaining
	var windup: float = maxf(attack_duration * enemy.attack_windup_ratio, 0.01)
	await enemy.get_tree().create_timer(windup).timeout

	if not _is_current_attack(sequence_id):
		return

	set_attack_hitbox_enabled(true)
	for body in hit_box.get_overlapping_bodies():
		try_attack_target(body)

	var recovery: float = maxf(attack_duration - windup, 0.0)
	if recovery > 0.0:
		await enemy.get_tree().create_timer(recovery).timeout

	if not _is_current_attack(sequence_id):
		return

	finish_attack(sequence_id)

func finish_attack(sequence_id: int) -> void:
	if not _is_current_attack(sequence_id):
		return

	_clear_attack_state()
	attack_finished.emit()

func _is_current_attack(sequence_id: int) -> bool:
	return is_active_attack and attack_sequence_id == sequence_id and enemy.state != enemy.State.DEAD

func _clear_attack_state() -> void:
	is_active_attack = false
	attack_hit_targets.clear()
	set_attack_hitbox_enabled(false)
	_reset_hitbox_transform()

func _reset_hitbox_transform() -> void:
	hit_box.position = hitbox_base_position
	hit_box.rotation = hitbox_base_rotation
	hit_box.scale = hitbox_base_scale
