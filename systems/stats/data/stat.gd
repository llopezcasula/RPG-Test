extends Resource
class_name Stat

@export var id: StringName = &""
@export var base_value: float = 0.0
@export var min_value: float = -INF
@export var max_value: float = INF
@export var modifiers: Array[StatModifier] = []

func _init(
	stat_id: StringName = &"",
	stat_base_value: float = 0.0,
	stat_min_value: float = -INF,
	stat_max_value: float = INF
) -> void:
	id = stat_id
	base_value = stat_base_value
	min_value = stat_min_value
	max_value = stat_max_value

static func create(
	stat_id: StringName,
	stat_base_value: float,
	stat_min_value: float = -INF,
	stat_max_value: float = INF
) -> Stat:
	var stat := Stat.new()
	stat.id = stat_id
	stat.base_value = stat_base_value
	stat.min_value = stat_min_value
	stat.max_value = stat_max_value
	return stat

func get_value() -> float:
	var flat_bonus := 0.0
	var additive_percent := 0.0
	var multiplicative_percent := 1.0
	var override_value: Variant = null

	for modifier in modifiers:
		if modifier == null:
			continue

		match modifier.modifier_type:
			StatModifier.ModifierType.FLAT:
				flat_bonus += modifier.value
			StatModifier.ModifierType.PERCENT_ADD:
				additive_percent += modifier.value
			StatModifier.ModifierType.PERCENT_MULTIPLY:
				multiplicative_percent *= 1.0 + modifier.value
			StatModifier.ModifierType.OVERRIDE:
				override_value = modifier.value

	var final_value := base_value + flat_bonus
	final_value *= 1.0 + additive_percent
	final_value *= multiplicative_percent

	if override_value != null:
		final_value = override_value as float

	return clampf(final_value, min_value, max_value)

func set_base_value(value: float) -> void:
	base_value = clampf(value, min_value, max_value)

func set_limits(new_min_value: float = -INF, new_max_value: float = INF) -> void:
	min_value = new_min_value
	max_value = new_max_value
	base_value = clampf(base_value, min_value, max_value)

func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		return
	modifiers.append(modifier)

func remove_modifier(modifier: StatModifier) -> bool:
	var modifier_index := modifiers.find(modifier)
	if modifier_index == -1:
		return false

	modifiers.remove_at(modifier_index)
	return true

func remove_modifiers_from_source(source_id: StringName) -> int:
	var removed_count := 0

	for index in range(modifiers.size() - 1, -1, -1):
		var modifier := modifiers[index]
		if modifier == null:
			modifiers.remove_at(index)
			continue
		if modifier.source_id != source_id:
			continue
		modifiers.remove_at(index)
		removed_count += 1

	return removed_count

func clear_modifiers() -> void:
	modifiers.clear()
