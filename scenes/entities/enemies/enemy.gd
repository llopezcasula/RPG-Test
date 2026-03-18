extends CharacterBody2D

@export_category("Stats")
@export var hitpoints:int = 100

@export_category("Related Scenes")
@export var death_packed: PackedScene

func take_damage(damage_taken: int) -> void:
	hitpoints -= damage_taken
	if hitpoints <= 0:
		death()
		
func death() -> void:
	var death_scene: Node2D = death_packed.instantiate()
	var effects_layer: Node2D = %Effects
	effects_layer.add_child(death_scene)
	death_scene.global_position = global_position + Vector2(0.0, -32.0)
	queue_free()
