extends CharacterBody2D

@export_category("Related Scenes")
@export var death_packed: PackedScene

@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	if health_component != null:
		health_component.died.connect(_on_health_component_died)

func take_damage(damage_taken: int) -> void:
	if health_component == null:
		return

	health_component.take_damage(damage_taken)

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
