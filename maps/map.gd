extends Node2D

# Static terrain/background layers stay outside of the y-sorted gameplay bucket.
# `Sortables` is reserved for characters and tall occluders that should depth-sort
# against them.
#
# Manual editor follow-up:
# - Move tall tree / canopy tiles from `Props` into `Sortables/Trees`.
# - Keep bushes, rocks, and other low-profile decorations in `Props`.
# - Place scene-based tall props (for example instanced trees) under `Sortables/TallProps`.
#
# The scene keeps the existing `Player` instance under `Sortables`, and marks it as
# `unique_name_in_owner` in the scene so `%Player` references remain stable if they are
# added elsewhere in this map scene later.

@onready var water: TileMapLayer = $Water
@onready var foam_rocks: TileMapLayer = $FoamRocks
@onready var ground: TileMapLayer = $Ground
@onready var shadows: TileMapLayer = $Shadows
@onready var plateau: TileMapLayer = $Plateau
@onready var props: TileMapLayer = $Props

@onready var sortables: Node2D = $Sortables
@onready var trees: TileMapLayer = $Sortables/Trees
@onready var tall_props: Node2D = $Sortables/TallProps
@onready var enemies: Node2D = $Sortables/Enemies
@onready var npcs: Node2D = $Sortables/NPCs
@onready var player: CharacterBody2D = $Sortables/Player
