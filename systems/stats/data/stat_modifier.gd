extends Resource
class_name StatModifier

enum ModifierType {
	FLAT,
	PERCENT_ADD,
	PERCENT_MULTIPLY,
	OVERRIDE
}

@export var stat_id: StringName = &""
@export var modifier_type: ModifierType = ModifierType.FLAT
@export var value: float = 0.0
@export var duration: float = -1.0
@export var source_id: StringName = &""

func _init(
	modifier_stat_id: StringName = &"",
	modifier_modifier_type: ModifierType = ModifierType.FLAT,
	modifier_value: float = 0.0,
	modifier_duration: float = -1.0,
	modifier_source_id: StringName = &""
) -> void:
	stat_id = modifier_stat_id
	modifier_type = modifier_modifier_type
	value = modifier_value
	duration = modifier_duration
	source_id = modifier_source_id

func duplicate_modifier() -> StatModifier:
	var modifier_copy := StatModifier.new()
	modifier_copy.stat_id = stat_id
	modifier_copy.modifier_type = modifier_type
	modifier_copy.value = value
	modifier_copy.duration = duration
	modifier_copy.source_id = source_id
	return modifier_copy

func is_timed() -> bool:
	return duration > 0.0
