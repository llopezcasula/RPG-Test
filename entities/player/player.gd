extends Node2D

@onready var archer: CharacterBody2D = $Archer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if archer != null and archer.has_method("set_move_target"):
			archer.set_move_target(get_global_mouse_position())
