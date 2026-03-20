extends Node2D

signal spawn_finished

func _ready() -> void:
	$AnimationPlayer.play("spawn")


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	spawn_finished.emit()
	queue_free()
