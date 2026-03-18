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
	var effect_parent: Node2D
	var current_scene := get_tree().current_scene
	if current_scene != null:
		effect_parent = current_scene.get_node_or_null("%GroundEffects") as Node2D
	if effect_parent == null:
		effect_parent = get_parent() as Node2D
	if effect_parent == null:
		effect_parent = %Effects
	effect_parent.add_child(death_scene)
	death_scene.global_position = global_position
	queue_free()
