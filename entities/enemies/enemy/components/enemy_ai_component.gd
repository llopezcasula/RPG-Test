extends Node
class_name EnemyAIComponent

var enemy: Enemy
var navigation_component: EnemyNavigationComponent
var current_target: CharacterBody2D

func setup(owner_enemy: Enemy, owner_navigation_component: EnemyNavigationComponent) -> void:
	enemy = owner_enemy
	navigation_component = owner_navigation_component

func process_ai(delta: float) -> void:
	if enemy == null or navigation_component == null:
		return

	current_target = resolve_target()

	match enemy.state:
		enemy.State.IDLE:
			process_idle(delta)
		enemy.State.CHASE:
			process_chase(delta)
		enemy.State.ATTACK:
			process_idle(delta)
		enemy.State.DEAD:
			navigation_component.stop()

func resolve_target() -> CharacterBody2D:
	var player := enemy.get_tree().get_first_node_in_group(enemy.player_group) as CharacterBody2D
	if player == null or not is_instance_valid(player):
		return null
	return player

func can_chase_target() -> bool:
	if current_target == null or not is_instance_valid(current_target):
		return false

	var distance_to_target := enemy.global_position.distance_to(current_target.global_position)
	if enemy.state == enemy.State.CHASE or enemy.state == enemy.State.ATTACK:
		return distance_to_target <= enemy.disengage_radius
	return distance_to_target <= enemy.detection_radius

func process_idle(_delta: float) -> void:
	navigation_component.stop()
	enemy.set_state(enemy.State.IDLE)

	if can_chase_target():
		enemy.set_state(enemy.State.CHASE)
		process_chase(0.0)

func process_chase(delta: float) -> void:
	if not can_chase_target():
		process_idle(delta)
		return

	enemy.set_state(enemy.State.CHASE)
	navigation_component.set_target_position(current_target.global_position)
	navigation_component.move_to_target(delta)
