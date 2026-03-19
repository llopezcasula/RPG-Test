extends Node
class_name HealthComponent

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, current_health: float, max_health: float)
signal healed(amount: float, current_health: float, max_health: float)
signal died

@export_category("Health")
# The stat id can stay the same across all entities. Only the value changes per entity.
@export var max_health_stat_id: StringName = &"max_health"
# Used only if the entity does not define the stat.
@export var fallback_max_health: float = 100.0
@export var start_at_max_health: bool = true
@export var current_health: float = 100.0
@export_node_path("StatsComponent") var stats_component_path: NodePath

var max_health: float = 100.0

@onready var stats_component: StatsComponent = _resolve_stats_component()

func _ready() -> void:
	refresh_max_health_from_stats()

	if stats_component != null:
		stats_component.stat_added.connect(_on_stats_component_stat_updated)
		stats_component.stat_changed.connect(_on_stats_component_stat_updated)
		stats_component.stat_removed.connect(_on_stats_component_stat_removed)

	if start_at_max_health:
		current_health = max_health
	else:
		current_health = clampf(current_health, 0.0, max_health)

	health_changed.emit(current_health, max_health)

func refresh_max_health_from_stats() -> void:
	max_health = fallback_max_health

	if stats_component != null:
		max_health = stats_component.get_stat_value(max_health_stat_id, fallback_max_health)

	max_health = maxf(max_health, 0.0)
	current_health = clampf(current_health, 0.0, max_health)

func take_damage(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return current_health

	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount, current_health, max_health)
	health_changed.emit(current_health, max_health)

	if is_dead():
		died.emit()

	return current_health

func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead():
		return current_health

	current_health = minf(current_health + amount, max_health)
	healed.emit(amount, current_health, max_health)
	health_changed.emit(current_health, max_health)
	return current_health

func reset_health() -> void:
	refresh_max_health_from_stats()
	current_health = max_health
	health_changed.emit(current_health, max_health)

func set_current_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)

func is_dead() -> bool:
	return current_health <= 0.0

func _resolve_stats_component() -> StatsComponent:
	if stats_component_path != NodePath():
		return get_node_or_null(stats_component_path) as StatsComponent

	if get_parent() is StatsComponent:
		return get_parent() as StatsComponent

	return get_node_or_null("../StatsComponent") as StatsComponent

func _on_stats_component_stat_updated(stat_id: StringName, _value: float) -> void:
	if stat_id != max_health_stat_id:
		return

	var previous_max_health := max_health
	refresh_max_health_from_stats()

	if not is_equal_approx(previous_max_health, max_health):
		health_changed.emit(current_health, max_health)

func _on_stats_component_stat_removed(stat_id: StringName) -> void:
	if stat_id != max_health_stat_id:
		return

	var previous_max_health := max_health
	refresh_max_health_from_stats()

	if not is_equal_approx(previous_max_health, max_health):
		health_changed.emit(current_health, max_health)
