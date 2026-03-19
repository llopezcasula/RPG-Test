extends Node
class_name EnemyAttackComponent

var enemy: Enemy
var combat_component: CombatComponent
var hit_box: Area2D
var hit_box_shape: CollisionShape2D

func setup(owner_enemy: Enemy, owner_combat_component: CombatComponent, owner_hit_box: Area2D, owner_hit_box_shape: CollisionShape2D) -> void:
	enemy = owner_enemy
	combat_component = owner_combat_component
	hit_box = owner_hit_box
	hit_box_shape = owner_hit_box_shape

func _start_attack(direction: Vector2) -> void:
	enemy.state = enemy.State.ATTACK
	enemy.attack_hit_targets.clear()
	enemy._update_facing(direction)
	hit_box.position = enemy.hitbox_base_position
	hit_box.rotation = enemy.hitbox_base_rotation
	hit_box.scale = enemy.hitbox_base_scale
	enemy.animation_tree.set("parameters/attack/BlendSpace2D/blend_position", enemy.facing_direction)
	enemy.update_animation()
	enemy.attack_cooldown_remaining = combat_component.get_attack_speed() if combat_component != null else 0.6
	_perform_attack_after_windup()

func _perform_attack_after_windup() -> void:
	var attack_duration: float = enemy.attack_cooldown_remaining
	var windup: float = maxf(attack_duration * enemy.attack_windup_ratio, 0.01)
	await enemy.get_tree().create_timer(windup).timeout

	if enemy.state == enemy.State.DEAD or enemy.state != enemy.State.ATTACK:
		return

	set_attack_hitbox_enabled(true)
	_resolve_attack_hit_overlaps()

	var recovery: float = maxf(attack_duration - windup, 0.0)
	if recovery > 0.0:
		await enemy.get_tree().create_timer(recovery).timeout

	if enemy.state == enemy.State.DEAD:
		return

	set_attack_hitbox_enabled(false)
	hit_box.position = enemy.hitbox_base_position
	hit_box.rotation = enemy.hitbox_base_rotation
	hit_box.scale = enemy.hitbox_base_scale
	enemy.attack_hit_targets.clear()
	enemy.state = enemy.State.IDLE
	enemy.update_animation()

func _resolve_attack_hit_overlaps() -> void:
	for body in hit_box.get_overlapping_bodies():
		_try_attack_target(body)

func _try_attack_target(target: Node) -> void:
	if combat_component == null or target == null:
		return
	if enemy.attack_hit_targets.has(target):
		return
	if not (target is CharacterBody2D):
		return

	enemy.attack_hit_targets.append(target)
	combat_component.attack_target(target)

func set_attack_hitbox_enabled(enabled: bool) -> void:
	hit_box.monitoring = enabled
	hit_box.monitorable = false
	hit_box_shape.disabled = not enabled
