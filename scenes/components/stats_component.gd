extends Node
class_name StatsComponent

signal stat_added(stat_id: StringName, value: float)
signal stat_changed(stat_id: StringName, value: float)
signal stat_removed(stat_id: StringName)
signal modifier_applied(stat_id: StringName, modifier: StatModifier)
signal modifier_removed(stat_id: StringName, modifier: StatModifier)

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
		var existing_stat := _stats_by_id[stat.id]
		existing_stat.base_value = stat.base_value
		existing_stat.min_value = stat.min_value
		existing_stat.max_value = stat.max_value
		existing_stat.modifiers = stat.modifiers.duplicate()
		_emit_stat_changed(stat.id)
		return

	stats.append(stat)
	_stats_by_id[stat.id] = stat
	stat_added.emit(stat.id, stat.get_value())

func add_stat_value(
	stat_id: StringName,
	base_value: float,
	replace_existing: bool = true,
	min_value: float = -INF,
	max_value: float = INF
) -> void:
	add_stat(Stat.create(stat_id, base_value, min_value, max_value), replace_existing)

func has_stat(stat_id: StringName) -> bool:
	return _stats_by_id.has(stat_id)

func get_stat(stat_id: StringName) -> Stat:
	return _stats_by_id.get(stat_id)

func get_stat_value(stat_id: StringName, default_value: float = 0.0) -> float:
	var stat := get_stat(stat_id)
	if stat == null:
		return default_value
	return stat.get_value()

func get_stat_base_value(stat_id: StringName, default_value: float = 0.0) -> float:
	var stat := get_stat(stat_id)
	if stat == null:
		return default_value
	return stat.base_value

func set_stat_value(stat_id: StringName, value: float) -> void:
	set_stat_base_value(stat_id, value)

func set_stat_base_value(stat_id: StringName, value: float) -> void:
	var stat := get_stat(stat_id)
	if stat == null:
		add_stat_value(stat_id, value)
		return

	if is_equal_approx(stat.base_value, value):
		return

	stat.set_base_value(value)
	_emit_stat_changed(stat_id)

func set_stat_limits(stat_id: StringName, min_value: float = -INF, max_value: float = INF) -> void:
	var stat := get_stat(stat_id)
	if stat == null:
		add_stat_value(stat_id, 0.0, true, min_value, max_value)
		return

	stat.set_limits(min_value, max_value)
	_emit_stat_changed(stat_id)

func apply_modifier(modifier: StatModifier) -> bool:
	if modifier == null or modifier.stat_id == &"":
		return false

	var stat := get_stat(modifier.stat_id)
	if stat == null:
		push_warning("Cannot apply modifier for missing stat '%s' on %s." % [String(modifier.stat_id), get_path()])
		return false

	stat.add_modifier(modifier)
	modifier_applied.emit(modifier.stat_id, modifier)
	_emit_stat_changed(modifier.stat_id)
	return true

func remove_modifier(modifier: StatModifier) -> bool:
	if modifier == null:
		return false

	var stat := get_stat(modifier.stat_id)
	if stat == null:
		return false

	if not stat.remove_modifier(modifier):
		return false

	modifier_removed.emit(modifier.stat_id, modifier)
	_emit_stat_changed(modifier.stat_id)
	return true

func remove_modifiers_by_source(source_id: StringName, stat_id: StringName = &"") -> int:
	var removed_count := 0
	var stat_ids: Array[StringName] = []

	if stat_id == &"":
		stat_ids.assign(_stats_by_id.keys())
	else:
		stat_ids.append(stat_id)

	for current_stat_id in stat_ids:
		var stat := get_stat(current_stat_id)
		if stat == null:
			continue

		var removed_for_stat := 0

		for index in range(stat.modifiers.size() - 1, -1, -1):
			var modifier := stat.modifiers[index]
			if modifier == null or modifier.source_id != source_id:
				continue
			stat.modifiers.remove_at(index)
			modifier_removed.emit(current_stat_id, modifier)
			removed_count += 1
			removed_for_stat += 1

		if removed_for_stat > 0:
			_emit_stat_changed(current_stat_id)

	return removed_count

func clear_modifiers(stat_id: StringName = &"") -> void:
	if stat_id == &"":
		for current_stat_id in _stats_by_id.keys():
			clear_modifiers(current_stat_id)
		return

	var stat := get_stat(stat_id)
	if stat == null or stat.modifiers.is_empty():
		return

	for modifier in stat.modifiers:
		modifier_removed.emit(stat_id, modifier)
	stat.clear_modifiers()
	_emit_stat_changed(stat_id)

func remove_stat(stat_id: StringName) -> void:
	if not has_stat(stat_id):
		return

	var stat := _stats_by_id[stat_id]
	stats.erase(stat)
	_stats_by_id.erase(stat_id)
	stat_removed.emit(stat_id)

func get_stat_ids() -> Array[StringName]:
	var stat_ids: Array[StringName] = []
	stat_ids.assign(_stats_by_id.keys())
	return stat_ids

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

func _emit_stat_changed(stat_id: StringName) -> void:
	stat_changed.emit(stat_id, get_stat_value(stat_id))
