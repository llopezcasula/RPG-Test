@tool
extends Node2D
class_name MapDepthLayers

## Keeps background TileMapLayer nodes separate from Y-sorted gameplay actors.
##
## Editor/manual follow-up for existing painted maps:
## - Leave Water/FoamRocks/Ground/Shadows/Plateau as static terrain layers.
## - Keep low-height clutter tiles in Props.
## - Move tall canopy/trunk tiles that should overlap the player into Trees.
## - Put character scenes under Sortables (Player, Enemies, NPCs) so only actors sort by Y.
## - If your current scene still has Player directly under Map, this script reparents it into
##   Sortables/Player without changing its global transform.

@export_node_path("TileMapLayer") var water_layer_path: NodePath = ^"Water"
@export_node_path("TileMapLayer") var foam_rocks_layer_path: NodePath = ^"FoamRocks"
@export_node_path("TileMapLayer") var ground_layer_path: NodePath = ^"Ground"
@export_node_path("TileMapLayer") var shadows_layer_path: NodePath = ^"Shadows"
@export_node_path("TileMapLayer") var plateau_layer_path: NodePath = ^"Plateau"
@export_node_path("TileMapLayer") var props_layer_path: NodePath = ^"Props"
@export_node_path("TileMapLayer") var trees_layer_path: NodePath = ^"Trees"

@export_node_path("Node2D") var sortables_path: NodePath = ^"Sortables"
@export_node_path("Node2D") var player_path: NodePath = ^"Sortables/Player"
@export_node_path("Node2D") var enemies_path: NodePath = ^"Sortables/Enemies"
@export_node_path("Node2D") var npcs_path: NodePath = ^"Sortables/NPCs"

func _ready() -> void:
	_ensure_sortable_structure()

func get_sortables() -> Node2D:
	return get_node_or_null(sortables_path) as Node2D

func get_player_container() -> Node2D:
	return get_node_or_null(player_path) as Node2D

func get_enemies_container() -> Node2D:
	return get_node_or_null(enemies_path) as Node2D

func get_npcs_container() -> Node2D:
	return get_node_or_null(npcs_path) as Node2D

func get_static_terrain_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for path in [
		water_layer_path,
		foam_rocks_layer_path,
		ground_layer_path,
		shadows_layer_path,
		plateau_layer_path,
		props_layer_path,
		trees_layer_path,
	]:
		var layer := get_node_or_null(path) as TileMapLayer
		if layer != null:
			layers.append(layer)
	return layers

func find_player_node() -> Node2D:
	var player_container := get_player_container()
	if player_container == null:
		return null

	for child in player_container.get_children():
		if child is Node2D:
			return child as Node2D

	return player_container

func _ensure_sortable_structure() -> void:
	var sortables := get_sortables()
	if sortables == null:
		return

	sortables.y_sort_enabled = true
	_ensure_child_container(sortables, player_path)
	_ensure_child_container(sortables, enemies_path)
	_ensure_child_container(sortables, npcs_path)
	_migrate_legacy_player(sortables)

func _ensure_child_container(sortables: Node2D, path: NodePath) -> void:
	var name := String(path.get_concatenated_names()).get_file()
	if sortables.get_node_or_null(name) == null:
		var container := Node2D.new()
		container.name = name
		container.owner = owner
		sortables.add_child(container)

func _migrate_legacy_player(sortables: Node2D) -> void:
	var legacy_player := get_node_or_null(^"Player") as Node2D
	if legacy_player == null or legacy_player.get_parent() != self:
		return

	var player_container := get_player_container()
	if player_container == null:
		return

	var previous_owner := legacy_player.owner
	var previous_global_position := legacy_player.global_position
	var previous_global_rotation := legacy_player.global_rotation
	var previous_global_scale := legacy_player.global_scale

	remove_child(legacy_player)
	player_container.add_child(legacy_player)
	legacy_player.owner = previous_owner
	legacy_player.global_position = previous_global_position
	legacy_player.global_rotation = previous_global_rotation
	legacy_player.global_scale = previous_global_scale
