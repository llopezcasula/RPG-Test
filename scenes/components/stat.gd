extends Resource
class_name Stat

# A single reusable numeric stat definition.
# Add new stats by creating another Stat resource with a unique `id`.
@export var id: StringName = &""
@export var value: float = 0.0

func _init(stat_id: StringName = &"", stat_value: float = 0.0) -> void:
	id = stat_id
	value = stat_value

static func create(stat_id: StringName, stat_value: float) -> Stat:
	var stat := Stat.new()
	stat.id = stat_id
	stat.value = stat_value
	return stat
