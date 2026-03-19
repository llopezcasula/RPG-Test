extends Node
class_name CombatComponent

signal attack_resolved(target: Node, raw_damage: float, final_damage: float, critical_hit: bool)
signal damage_received(source: Node, raw_damage: float, final_damage: float)

@export_category("Combat")
@export var attack_stat_id: StringName = StatsIds.ATTACK
@export var attack_speed_stat_id: StringName = StatsIds.ATTACK_SPEED
@export var defense_stat_id: StringName = StatsIds.DEFENSE
@export var crit_chance_stat_id: StringName = StatsIds.CRIT_CHANCE
@export var crit_damage_stat_id: StringName = StatsIds.CRIT_DAMAGE
@export var damage_multiplier_stat_id: StringName = StatsIds.DAMAGE_MULTIPLIER
@export var fallback_attack: float = 10.0
@export var fallback_attack_speed: float = 0.6
@export var fallback_defense: float = 0.0
@export var fallback_crit_chance: float = 0.0
@export var fallback_crit_damage: float = 1.5
@export var fallback_damage_multiplier: float = 1.0
@export_node_path("Node") var stats_component_path: NodePath = ^"../StatsComponent"
@export_node_path("Node") var health_component_path: NodePath = ^"../StatsComponent/HealthComponent"

@onready var stats_component: StatsComponent = _resolve_stats_component()
@onready var health_component: HealthComponent = _resolve_health_component()

func get_attack_speed() -> float:
	return maxf(_get_stat_value(attack_speed_stat_id, fallback_attack_speed), 0.01)

func get_attack_power() -> float:
	return _get_stat_value(attack_stat_id, fallback_attack)

func get_defense() -> float:
	return maxf(_get_stat_value(defense_stat_id, fallback_defense), 0.0)

func get_crit_chance() -> float:
	return clampf(_get_stat_value(crit_chance_stat_id, fallback_crit_chance), 0.0, 1.0)

func get_crit_damage_multiplier() -> float:
	return maxf(_get_stat_value(crit_damage_stat_id, fallback_crit_damage), 1.0)

func get_damage_multiplier() -> float:
	return maxf(_get_stat_value(damage_multiplier_stat_id, fallback_damage_multiplier), 0.0)

func roll_attack_damage(base_damage: float = -1.0) -> Dictionary:
	var raw_damage := base_damage if base_damage >= 0.0 else get_attack_power()
	var critical_hit := randf() <= get_crit_chance()
	var final_damage := raw_damage * get_damage_multiplier()

	if critical_hit:
		final_damage *= get_crit_damage_multiplier()

	return {
		"raw_damage": raw_damage,
		"final_damage": maxf(final_damage, 0.0),
		"critical_hit": critical_hit,
	}

func attack_target(target: Node, base_damage: float = -1.0) -> float:
	if target == null:
		return 0.0

	var attack_result := roll_attack_damage(base_damage)
	var applied_damage := 0.0

	if target.has_method("take_damage"):
		applied_damage = target.take_damage(attack_result["final_damage"], get_parent())

	attack_resolved.emit(target, attack_result["raw_damage"], applied_damage, attack_result["critical_hit"])
	return applied_damage

func take_damage(raw_damage: float, source: Node = null) -> float:
	if health_component == null or raw_damage <= 0.0:
		return 0.0

	var mitigated_damage := maxf(raw_damage - get_defense(), 0.0)
	var applied_damage := health_component.take_damage(mitigated_damage)
	damage_received.emit(source, raw_damage, applied_damage)
	return applied_damage

func _resolve_stats_component() -> StatsComponent:
	if stats_component_path != NodePath():
		return get_node_or_null(stats_component_path) as StatsComponent
	return get_node_or_null("../StatsComponent") as StatsComponent

func _resolve_health_component() -> HealthComponent:
	if health_component_path != NodePath():
		return get_node_or_null(health_component_path) as HealthComponent
	return get_node_or_null("../StatsComponent/HealthComponent") as HealthComponent

func _get_stat_value(stat_id: StringName, fallback_value: float) -> float:
	if stats_component == null:
		return fallback_value
	return stats_component.get_stat_value(stat_id, fallback_value)
