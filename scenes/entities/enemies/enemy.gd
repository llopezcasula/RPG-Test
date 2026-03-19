extends CharacterBody2D

@export_category("Related Scenes")
@export var death_packed: PackedScene

@onready var stats_component: StatsComponent = $StatsComponent
@onready var combat_component: CombatComponent = $CombatComponent

func _ready() -> void:
	var health_component := get_health_component()
	if health_component != null:
		health_component.died.connect(_on_health_component_died)

func take_damage(damage_taken: float, source: Node = null) -> float:
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

func _on_health_component_died() -> void:
	death()
