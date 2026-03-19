extends Node
class_name StatsComponent

@export_node_path("HealthComponent") var health_component_path: NodePath = ^"HealthComponent"

var stat_components: Dictionary[StringName, Node] = {}

@onready var health_component: HealthComponent = _resolve_health_component()

func _ready() -> void:
	if health_component != null:
		register_stat_component(&"health", health_component)
	else:
		push_warning("StatsComponent requires a HealthComponent child or assigned health_component_path.")

func register_stat_component(stat_name: StringName, component: Node) -> void:
	if component == null:
		return

	stat_components[stat_name] = component

func has_stat_component(stat_name: StringName) -> bool:
	return stat_components.has(stat_name)

func get_stat_component(stat_name: StringName) -> Node:
	return stat_components.get(stat_name)

func get_health_component() -> HealthComponent:
	return health_component

func _resolve_health_component() -> HealthComponent:
	if health_component_path != NodePath():
		return get_node_or_null(health_component_path) as HealthComponent
	return get_node_or_null("HealthComponent") as HealthComponent
