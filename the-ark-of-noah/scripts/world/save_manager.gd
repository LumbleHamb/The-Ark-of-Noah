class_name SaveManager
extends Node

## Save/Load persistence manager.
## Autoload that serializes FarmManager and TimeManager state to user://savegame.save.
##
## Architecture:
##   - Uses JSON + var_to_str for Vector2i key serialization (matching FarmManager's format)
##   - Saves on explicit call (auto-save on scene exit optional)
##   - Loads on explicit call (call from world._ready or first scene)
##   - No autosave timer — game controls when to save

const SAVE_PATH: String = "user://savegame.save"

## Emitted after save completes
signal save_completed(success: bool)
## Emitted after load completes
signal load_completed(success: bool)

func save_game() -> void:
	"""Serialize all savable systems to disk."""
	var data: Dictionary = {}
	
	# Collect from FarmManager
	var farm: FarmManager = _find_farm_manager()
	if farm and farm.has_method("get_save_data"):
		data["farm"] = farm.get_save_data()
	
	# Collect from TimeManager
	var time: TimeManager = _find_time_manager()
	if time and time.has_method("get_save_data"):
		data["time"] = time.get_save_data()
	
	# Write to disk
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open file for writing: ", FileAccess.get_open_error())
		save_completed.emit(false)
		return
	
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("SaveManager: game saved (%d bytes)" % json_string.length())
	save_completed.emit(true)

func load_game() -> void:
	"""Load and restore all savable systems from disk."""
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: no save file found at ", SAVE_PATH)
		load_completed.emit(false)
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file: ", FileAccess.get_open_error())
		load_completed.emit(false)
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error: ", parse_result)
		load_completed.emit(false)
		return
	
	var data: Dictionary = json.data as Dictionary
	if data == null:
		push_error("SaveManager: save file is not a valid JSON object")
		load_completed.emit(false)
		return
	
	# Restore FarmManager
	if data.has("farm"):
		var farm: FarmManager = _find_farm_manager()
		if farm and farm.has_method("load_from_save"):
			farm.load_from_save(data["farm"])
			print("SaveManager: farm data restored")
	
	# Restore TimeManager
	if data.has("time"):
		var time: TimeManager = _find_time_manager()
		if time and time.has_method("load_from_save"):
			time.load_from_save(data["time"])
			print("SaveManager: time data restored")
	
	print("SaveManager: game loaded")
	load_completed.emit(true)

func delete_save() -> void:
	"""Remove the save file from disk."""
	if FileAccess.file_exists(SAVE_PATH):
		var result: Error = DirAccess.remove_absolute(SAVE_PATH)
		if result == OK:
			print("SaveManager: save file deleted")
		else:
			push_error("SaveManager: failed to delete save file: ", result)

func has_save() -> bool:
	"""Check if a save file exists."""
	return FileAccess.file_exists(SAVE_PATH)

# ============================================================================
# HELPERS
# ============================================================================
func _find_farm_manager() -> FarmManager:
	var fm: FarmManager = get_tree().get_first_node_in_group(&"farm_manager")
	if fm == null:
		fm = get_tree().root.find_child("FarmManager", true, false) as FarmManager
	return fm

func _find_time_manager() -> TimeManager:
	var tm: TimeManager = get_tree().get_first_node_in_group(&"time_manager")
	if tm == null:
		tm = get_tree().root.find_child("TimeManager", true, false) as TimeManager
	return tm
