class_name GameStats
extends Node

## ============================================================================
## GAME STATS AUTOLOAD
##
## Centralized expandable gameplay statistics registry.
## - Other systems call increment_stat()/set_stat() to update values.
## - UI pages (StatisticsPageComponent) call get_all_stats() for rendering.
## - SaveManager persists these stats under the "stats" key.
## ============================================================================

signal stat_changed(stat_key: String, value: int)
signal stats_reset()

const DEFAULT_STATS: Dictionary = {
	"boat_construction_stage": 0,
	"trees_cut": 0,
	"rocks_mined": 0,
	"plants_grown": 0,
	"crops_harvested": 0,
	"days_elapsed": 0,
	"total_money": 0,
	"steps_walked": 0,
	"animals_collected": 0,
	"fish_caught": 0,
	"tools_unlocked": 0,
	"buildings_placed": 0,
	"crafting_recipes_unlocked": 0,
}

var _stats: Dictionary = {}

func _ready() -> void:
	reset_stats()

func reset_stats() -> void:
	_stats = DEFAULT_STATS.duplicate(true)
	stats_reset.emit()

func has_stat(stat_key: String) -> bool:
	return _stats.has(stat_key)

func ensure_stat(stat_key: String, default_value: int = 0) -> void:
	if not _stats.has(stat_key):
		_stats[stat_key] = default_value

func increment_stat(stat_key: String, delta: int = 1) -> int:
	ensure_stat(stat_key, 0)
	var new_value: int = int(_stats[stat_key]) + delta
	_stats[stat_key] = new_value
	stat_changed.emit(stat_key, new_value)
	return new_value

func set_stat(stat_key: String, value: int) -> void:
	_stats[stat_key] = value
	stat_changed.emit(stat_key, value)

func get_stat(stat_key: String, default_value: int = 0) -> int:
	return int(_stats.get(stat_key, default_value))

func get_all_stats() -> Dictionary:
	return _stats.duplicate(true)

func load_from_save(data: Dictionary) -> void:
	reset_stats()
	for key: Variant in data.keys():
		var stat_key: String = str(key)
		_stats[stat_key] = int(data[key])
		stat_changed.emit(stat_key, int(data[key]))

func get_save_data() -> Dictionary:
	return _stats.duplicate(true)

func format_stat_name(stat_key: String) -> String:
	var words: PackedStringArray = stat_key.split("_")
	for i: int in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)
