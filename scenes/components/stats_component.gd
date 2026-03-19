extends Node
class_name StatsComponent

signal stat_added(stat_id: StringName, value: float)
signal stat_changed(stat_id: StringName, value: float)
signal stat_removed(stat_id: StringName)

# Centralized stat storage for an entity.
# Store only the simple numeric values an entity actually needs.
@export var stats: Array[Stat] = []

var _stats_by_id: Dictionary[StringName, Stat] = {}

func _enter_tree() -> void:
	_rebuild_cache()

func add_stat(stat: Stat, replace_existing: bool = true) -> void:
	if stat == null:
		return

	if stat.id == &"":
		push_warning("Ignoring Stat with an empty id on %s." % get_path())
		return

	if has_stat(stat.id):
		if not replace_existing:
			return
		_stats_by_id[stat.id].value = stat.value
		stat_changed.emit(stat.id, stat.value)
		return

	stats.append(stat)
	_stats_by_id[stat.id] = stat
	stat_added.emit(stat.id, stat.value)

func add_stat_value(stat_id: StringName, value: float, replace_existing: bool = true) -> void:
	add_stat(Stat.create(stat_id, value), replace_existing)

func has_stat(stat_id: StringName) -> bool:
	return _stats_by_id.has(stat_id)

func get_stat(stat_id: StringName) -> Stat:
	return _stats_by_id.get(stat_id)

func get_stat_value(stat_id: StringName, default_value: float = 0.0) -> float:
	var stat := get_stat(stat_id)
	if stat == null:
		return default_value
	return stat.value

func set_stat_value(stat_id: StringName, value: float) -> void:
	var stat := get_stat(stat_id)
	if stat == null:
		add_stat_value(stat_id, value)
		return

	if is_equal_approx(stat.value, value):
		return

	stat.value = value
	stat_changed.emit(stat_id, value)

func remove_stat(stat_id: StringName) -> void:
	if not has_stat(stat_id):
		return

	var stat := _stats_by_id[stat_id]
	stats.erase(stat)
	_stats_by_id.erase(stat_id)
	stat_removed.emit(stat_id)

func get_stat_ids() -> Array:
	return _stats_by_id.keys()

func _rebuild_cache() -> void:
	_stats_by_id.clear()

	for stat in stats:
		if stat == null:
			continue

		if stat.id == &"":
			push_warning("Found Stat with an empty id on %s." % get_path())
			continue

		if _stats_by_id.has(stat.id):
			push_warning("Duplicate stat id '%s' found on %s. Keeping the last value." % [String(stat.id), get_path()])

		_stats_by_id[stat.id] = stat
