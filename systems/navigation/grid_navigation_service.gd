extends Node
class_name GridNavigationService

## Shared grid-based pathfinding built from the map's collidable TileMapLayers.
##
## Enemies query this service at sensible intervals instead of tracing directly at the
## player every frame. That gives them stable paths around walls and corners while still
## letting local steering handle nearby dynamic congestion.

@export_category("Grid")
@export var collision_layer_index: int = 0
@export var grid_margin: int = 6
@export var allow_diagonal: bool = true
@export var tile_map_layer_paths: Array[NodePath] = []

const INVALID_CELL := Vector2i(2147483647, 2147483647)

var _astar := AStarGrid2D.new()
var _reference_layer: TileMapLayer
var _is_ready: bool = false

func _ready() -> void:
	add_to_group("grid_navigation_service")
	rebuild()

func rebuild() -> void:
	var tile_layers := _resolve_tile_layers()
	if tile_layers.is_empty():
		push_warning("GridNavigationService could not find any TileMapLayer nodes to build from.")
		_is_ready = false
		return

	_reference_layer = tile_layers[0]
	var used_rect := _build_used_rect(tile_layers)
	if used_rect.size == Vector2i.ZERO:
		push_warning("GridNavigationService found no used tiles to build navigation from.")
		_is_ready = false
		return

	used_rect.position -= Vector2i.ONE * grid_margin
	used_rect.size += Vector2i.ONE * grid_margin * 2

	_astar.region = used_rect
	_astar.cell_size = _reference_layer.tile_set.tile_size
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE if allow_diagonal else AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()

	for tile_layer in tile_layers:
		_mark_solid_cells(tile_layer)

	_is_ready = true

func get_world_path(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	if not _is_ready or _reference_layer == null:
		return _single_point_path(to_position)

	var start_cell := _find_open_cell(_world_to_cell(from_position))
	var end_cell := _find_open_cell(_world_to_cell(to_position))
	if start_cell == INVALID_CELL or end_cell == INVALID_CELL:
		return _single_point_path(to_position)

	var cell_path := _astar.get_id_path(start_cell, end_cell)
	if cell_path.is_empty():
		return _single_point_path(to_position)

	var world_path := PackedVector2Array()
	world_path.resize(cell_path.size())
	for i in range(cell_path.size()):
		world_path[i] = _cell_to_world(cell_path[i])
	return world_path

func _resolve_tile_layers() -> Array[TileMapLayer]:
	var tile_layers: Array[TileMapLayer] = []
	if not tile_map_layer_paths.is_empty():
		for path in tile_map_layer_paths:
			var tile_layer := get_node_or_null(path) as TileMapLayer
			if tile_layer != null:
				tile_layers.append(tile_layer)
	else:
		_collect_tile_layers(get_parent(), tile_layers)
	return tile_layers

func _collect_tile_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		result.append(node)
	for child in node.get_children():
		_collect_tile_layers(child, result)

func _build_used_rect(tile_layers: Array[TileMapLayer]) -> Rect2i:
	var has_rect := false
	var combined := Rect2i()
	for tile_layer in tile_layers:
		var layer_rect := tile_layer.get_used_rect()
		if layer_rect.size == Vector2i.ZERO:
			continue
		combined = layer_rect if not has_rect else combined.merge(layer_rect)
		has_rect = true
	return combined

func _mark_solid_cells(tile_layer: TileMapLayer) -> void:
	for cell in tile_layer.get_used_cells():
		var tile_data := tile_layer.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		if tile_data.get_collision_polygons_count(collision_layer_index) > 0:
			_astar.set_point_solid(cell, true)

func _world_to_cell(world_position: Vector2) -> Vector2i:
	return _reference_layer.local_to_map(_reference_layer.to_local(world_position))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return _reference_layer.to_global(_reference_layer.map_to_local(cell))

func _find_open_cell(origin: Vector2i) -> Vector2i:
	if not _is_ready:
		return INVALID_CELL
	if _astar.is_in_boundsv(origin) and not _astar.is_point_solid(origin):
		return origin

	for radius in range(1, grid_margin + 8):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				var candidate := Vector2i(x, y)
				if not _astar.is_in_boundsv(candidate):
					continue
				if _astar.is_point_solid(candidate):
					continue
				return candidate
	return INVALID_CELL

func _single_point_path(position: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	path.append(position)
	return path
