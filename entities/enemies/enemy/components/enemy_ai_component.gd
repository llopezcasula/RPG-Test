extends Node
class_name EnemyAIComponent

var enemy: Enemy
var navigation_component: EnemyNavigationComponent
var attack_component: EnemyAttackComponent
var current_target: CharacterBody2D
var repath_timer: float = 0.0

func setup(owner_enemy: Enemy, owner_navigation_component: EnemyNavigationComponent, owner_attack_component: EnemyAttackComponent) -> void:
	enemy = owner_enemy
	navigation_component = owner_navigation_component
	attack_component = owner_attack_component

func physics_update(delta: float) -> void:
	if enemy == null:
		return

	current_target = resolve_target()
	enemy.current_target = current_target

	match enemy.state:
		enemy.State.IDLE:
			_process_idle(delta)
		enemy.State.CHASE:
			_process_chase(delta)
		enemy.State.ATTACK:
			_process_attack(delta)
		enemy.State.DEAD:
			navigation_component.stop()

func resolve_target() -> CharacterBody2D:
	var player := enemy.get_tree().get_first_node_in_group(enemy.player_group) as CharacterBody2D
	if player == null or not is_instance_valid(player):
		return null
	return player

func _process_idle(delta: float) -> void:
	navigation_component.stop()
	if _should_chase_target():
		enemy.set_state(enemy.State.CHASE)
		_process_chase(delta)

# Future extension point for patrol / wander behavior.
func _process_patrol(_delta: float) -> void:
	navigation_component.stop()

func _process_chase(delta: float) -> void:
	if not _should_chase_target():
		enemy.set_state(enemy.State.IDLE)
		navigation_component.stop()
		return

	var distance_to_target := enemy.global_position.distance_to(current_target.global_position)
	var target_direction := (current_target.global_position - enemy.global_position).normalized()
	if target_direction != Vector2.ZERO:
		enemy.update_facing(target_direction)

	if distance_to_target <= enemy.attack_range:
		navigation_component.stop()
		_start_attack_if_possible()
		return

	enemy.set_state(enemy.State.CHASE)
	repath_timer = maxf(repath_timer - delta, 0.0)
	if repath_timer <= 0.0:
		navigation_component.set_target_position(current_target.global_position)
		repath_timer = enemy.repath_interval

	navigation_component.move_to_target(delta)

func _process_attack(delta: float) -> void:
	navigation_component.stop()
	if attack_component.is_attacking():
		return

	if not _has_target():
		enemy.set_state(enemy.State.IDLE)
		return

	var distance_to_target := enemy.global_position.distance_to(current_target.global_position)
	if distance_to_target > enemy.disengage_radius:
		enemy.set_state(enemy.State.IDLE)
		return

	if distance_to_target <= enemy.attack_range and enemy.can_attack():
		_start_attack_if_possible()
		return

	if distance_to_target <= enemy.detection_radius:
		enemy.set_state(enemy.State.CHASE)
		_process_chase(delta)
		return

	enemy.set_state(enemy.State.IDLE)

func _start_attack_if_possible() -> void:
	if not _has_target():
		enemy.set_state(enemy.State.IDLE)
		return

	if not enemy.can_attack():
		enemy.set_state(enemy.State.IDLE)
		return

	enemy.set_state(enemy.State.ATTACK)
	attack_component.start_attack(current_target.global_position - enemy.global_position)

func _should_chase_target() -> bool:
	if not _has_target():
		return false

	var distance_to_target := enemy.global_position.distance_to(current_target.global_position)
	if enemy.state == enemy.State.CHASE or enemy.state == enemy.State.ATTACK:
		return distance_to_target <= enemy.disengage_radius
	return distance_to_target <= enemy.detection_radius

func _has_target() -> bool:
	return current_target != null and is_instance_valid(current_target)
