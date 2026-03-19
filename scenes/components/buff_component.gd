extends Node
class_name BuffComponent

signal buff_applied(source_id: StringName, modifier: StatModifier)
signal buff_expired(source_id: StringName, modifier: StatModifier)

@export_node_path("Node") var stats_component_path: NodePath = ^"../StatsComponent"

var _active_buffs: Array[Dictionary] = []

@onready var stats_component: StatsComponent = _resolve_stats_component()

func _process(delta: float) -> void:
	for index in range(_active_buffs.size() - 1, -1, -1):
		var entry := _active_buffs[index]
		var remaining_time: float = entry.get("remaining_time", -1.0)
		if remaining_time <= 0.0:
			continue

		remaining_time -= delta
		entry["remaining_time"] = remaining_time
		_active_buffs[index] = entry

		if remaining_time > 0.0:
			continue

		_expire_buff_at(index)

func apply_buff(modifier: StatModifier) -> bool:
	if stats_component == null or modifier == null:
		return false

	var modifier_instance := modifier.duplicate_modifier()
	if not stats_component.apply_modifier(modifier_instance):
		return false

	_active_buffs.append({
		"modifier": modifier_instance,
		"remaining_time": modifier_instance.duration,
	})
	buff_applied.emit(modifier_instance.source_id, modifier_instance)
	return true

func apply_buffs(modifiers: Array[StatModifier]) -> void:
	for modifier in modifiers:
		apply_buff(modifier)

func has_buff_source(source_id: StringName) -> bool:
	for entry in _active_buffs:
		var modifier := entry.get("modifier") as StatModifier
		if modifier != null and modifier.source_id == source_id:
			return true
	return false

func remove_buff_source(source_id: StringName) -> int:
	var removed_count := 0

	for index in range(_active_buffs.size() - 1, -1, -1):
		var entry := _active_buffs[index]
		var modifier := entry.get("modifier") as StatModifier
		if modifier == null or modifier.source_id != source_id:
			continue
		if stats_component != null:
			stats_component.remove_modifier(modifier)
		_active_buffs.remove_at(index)
		buff_expired.emit(source_id, modifier)
		removed_count += 1

	return removed_count

func clear_buffs() -> void:
	for index in range(_active_buffs.size() - 1, -1, -1):
		_expire_buff_at(index)

func _expire_buff_at(index: int) -> void:
	if index < 0 or index >= _active_buffs.size():
		return

	var entry := _active_buffs[index]
	var modifier := entry.get("modifier") as StatModifier
	if modifier != null and stats_component != null:
		stats_component.remove_modifier(modifier)
		buff_expired.emit(modifier.source_id, modifier)
	_active_buffs.remove_at(index)

func _resolve_stats_component() -> StatsComponent:
	if stats_component_path != NodePath():
		return get_node_or_null(stats_component_path) as StatsComponent

	if get_parent() is StatsComponent:
		return get_parent() as StatsComponent

	return get_node_or_null("../StatsComponent") as StatsComponent
