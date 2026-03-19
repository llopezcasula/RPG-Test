extends Resource
class_name StatLoadout

@export var stats: Array[Stat] = []

func build_stats() -> Array[Stat]:
	var built_stats: Array[Stat] = []

	for stat in stats:
		if stat == null:
			continue
		built_stats.append(stat.duplicate(true) as Stat)

	return built_stats
