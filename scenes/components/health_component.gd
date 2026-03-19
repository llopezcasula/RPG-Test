extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int, current_health: int, max_health: int)
signal healed(amount: int, current_health: int, max_health: int)
signal died

@export_category("Health")
@export var max_health: int = 100
@export var start_at_max_health: bool = true
@export var current_health: int = 100

func _ready() -> void:
	if start_at_max_health:
		current_health = max_health
	else:
		current_health = clampi(current_health, 0, max_health)

	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> int:
	if amount <= 0 or is_dead():
		return current_health

	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount, current_health, max_health)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		died.emit()

	return current_health

func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return current_health

	current_health = mini(current_health + amount, max_health)
	healed.emit(amount, current_health, max_health)
	health_changed.emit(current_health, max_health)
	return current_health

func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func set_current_health(value: int) -> void:
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0
