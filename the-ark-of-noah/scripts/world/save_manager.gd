class_name SaveManagerSingleton
extends Node

## Save/Load persistence manager.
##
## Uses per-slot save files so menu flow can support New Game + Continue.
## Keeps backward compatibility by defaulting to slot 1.

const SAVE_DIR: String = "user://saves"
const SLOT_FILE_TEMPLATE: String = "slot_%d.save"

signal save_completed(success: bool)
signal load_completed(success: bool)

var active_slot: int = 1

func set_active_slot(slot_index: int) -> void:
	active_slot = clampi(slot_index, 1, 3)

func get_active_slot() -> int:
	return active_slot

func save_game() -> void:
	_ensure_save_dir()
	var data: Dictionary = {}
	var farm: FarmManager = _find_farm_manager()
	if farm != null and farm.has_method("get_save_data"):
		data["farm"] = farm.get_save_data()
	var time_manager_node: TimeManager = _find_time_manager()
	if time_manager_node != null and time_manager_node.has_method("get_save_data"):
		data["time"] = time_manager_node.get_save_data()
	var player_inventory: InventoryComponent = _find_player_inventory()
	if player_inventory != null:
		data["player_inventory"] = player_inventory.get_save_data()
	data["weather"] = _get_weather_save_data()
	var player_node: Player = _find_player()
	if player_node != null:
		data["player"] = {
			"position": var_to_str(player_node.global_position)
		}
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null and stats_node.has_method("get_save_data"):
		data["stats"] = stats_node.call("get_save_data")
	data["chests"] = _get_chest_save_data()
	data["breakable_rocks"] = _get_breakable_rock_save_data()
	data["slot"] = active_slot
	var save_path: String = _slot_path(active_slot)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open file for writing: %s" % FileAccess.get_open_error())
		save_completed.emit(false)
		return
	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	print("SaveManager: game saved to slot %d (%d bytes)" % [active_slot, json_string.length()])
	save_completed.emit(true)

func load_game() -> void:
	_ensure_save_dir()
	var save_path: String = _slot_path(active_slot)
	if not FileAccess.file_exists(save_path):
		print("SaveManager: no save file found at %s" % save_path)
		load_completed.emit(false)
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file: %s" % FileAccess.get_open_error())
		load_completed.emit(false)
		return
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error: %s" % parse_result)
		load_completed.emit(false)
		return
	var data: Dictionary = json.data as Dictionary
	if data == null:
		push_error("SaveManager: save file is not a valid JSON object")
		load_completed.emit(false)
		return
	if data.has("farm"):
		var farm: FarmManager = _find_farm_manager()
		if farm != null and farm.has_method("load_from_save"):
			farm.load_from_save(data["farm"] as Dictionary)
	if data.has("time"):
		var time_manager_node: TimeManager = _find_time_manager()
		if time_manager_node != null and time_manager_node.has_method("load_from_save"):
			time_manager_node.load_from_save(data["time"] as Dictionary)
	if data.has("weather"):
		_load_weather_save_data(data["weather"] as Dictionary)
	if data.has("player"):
		var player_data: Dictionary = data["player"] as Dictionary
		var player_node: Player = _find_player()
		if player_node != null:
			player_node.global_position = str_to_var(String(player_data.get("position", "Vector2(0, 0)"))) as Vector2
	if data.has("player_inventory"):
		var player_inventory: InventoryComponent = _find_player_inventory()
		if player_inventory != null:
			player_inventory.load_from_save(data["player_inventory"] as Dictionary)
	if data.has("stats"):
		var stats_node: Node = get_node_or_null("/root/game_stats")
		if stats_node != null and stats_node.has_method("load_from_save"):
			stats_node.call("load_from_save", data["stats"] as Dictionary)
	if data.has("chests"):
		_load_chest_save_data(data["chests"] as Dictionary)
	if data.has("breakable_rocks"):
		_load_breakable_rock_save_data(data["breakable_rocks"] as Dictionary)
	print("SaveManager: game loaded from slot %d" % active_slot)
	load_completed.emit(true)

func delete_save(slot_index: int = -1) -> void:
	_ensure_save_dir()
	var slot_to_delete: int = active_slot if slot_index < 1 else clampi(slot_index, 1, 3)
	var save_path: String = _slot_path(slot_to_delete)
	if FileAccess.file_exists(save_path):
		var result: Error = DirAccess.remove_absolute(save_path)
		if result == OK:
			print("SaveManager: save file deleted for slot %d" % slot_to_delete)
		else:
			push_error("SaveManager: failed to delete save file: %s" % result)

func has_save(slot_index: int = -1) -> bool:
	_ensure_save_dir()
	var slot_to_check: int = active_slot if slot_index < 1 else clampi(slot_index, 1, 3)
	return FileAccess.file_exists(_slot_path(slot_to_check))

func list_existing_slots() -> Array[int]:
	_ensure_save_dir()
	var existing: Array[int] = []
	for slot_index: int in [1, 2, 3]:
		if has_save(slot_index):
			existing.append(slot_index)
	return existing

func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _slot_path(slot_index: int) -> String:
	return "%s/%s" % [SAVE_DIR, SLOT_FILE_TEMPLATE % slot_index]

func _find_farm_manager() -> FarmManager:
	var farm_manager_node: FarmManager = get_tree().get_first_node_in_group(&"farm_manager") as FarmManager
	if farm_manager_node == null:
		farm_manager_node = get_tree().root.find_child("FarmManager", true, false) as FarmManager
	return farm_manager_node

func _find_time_manager() -> TimeManager:
	var time_manager_node: TimeManager = get_tree().get_first_node_in_group(&"time_manager") as TimeManager
	if time_manager_node == null:
		time_manager_node = get_tree().root.find_child("TimeManager", true, false) as TimeManager
	return time_manager_node

func _find_player_inventory() -> InventoryComponent:
	var player_node: Player = _find_player()
	if player_node == null:
		return null
	for child: Node in player_node.get_children():
		if child is InventoryComponent:
			return child as InventoryComponent
	return null

func _find_player() -> Player:
	var player_node: Player = get_tree().get_first_node_in_group(&"Player") as Player
	if player_node == null:
		player_node = get_tree().get_first_node_in_group(&"player") as Player
	return player_node

func _get_chest_save_data() -> Dictionary:
	var chest_data: Dictionary = {}
	var chest_nodes: Array[Node] = get_tree().get_nodes_in_group(&"chest")
	for chest_node: Node in chest_nodes:
		if chest_node != null and chest_node.has_method("get_save_data"):
			var key: String = chest_node.get_path()
			chest_data[key] = chest_node.call("get_save_data")
	return chest_data

func _load_chest_save_data(chest_data: Dictionary) -> void:
	for key: Variant in chest_data.keys():
		var chest_path: NodePath = NodePath(String(key))
		var chest_node: Node = get_node_or_null(chest_path)
		if chest_node != null and chest_node.has_method("load_from_save"):
			chest_node.call("load_from_save", chest_data[key] as Dictionary)

func _get_breakable_rock_save_data() -> Dictionary:
	var rock_data: Dictionary = {}
	var rock_nodes: Array[Node] = get_tree().get_nodes_in_group(&"breakable_rock")
	for rock_node: Node in rock_nodes:
		if rock_node != null and rock_node.has_method("get_save_data"):
			var key: String = rock_node.get_path()
			rock_data[key] = rock_node.call("get_save_data")
	return rock_data

func _load_breakable_rock_save_data(rock_data: Dictionary) -> void:
	for key: Variant in rock_data.keys():
		var rock_path: NodePath = NodePath(String(key))
		var rock_node: Node = get_node_or_null(rock_path)
		if rock_node != null and rock_node.has_method("load_from_save"):
			rock_node.call("load_from_save", rock_data[key] as Dictionary)

func _get_weather_save_data() -> Dictionary:
	if get_tree() == null:
		return {}
	var weather_node: Node = get_tree().get_first_node_in_group(&"weather_manager")
	if weather_node == null:
		return {}
	var intensity: float = 1.0
	if weather_node.has_method("get_weather_intensity"):
		intensity = float(weather_node.call("get_weather_intensity"))
	return {
		"weather_intensity": intensity
	}

func _load_weather_save_data(weather_data: Dictionary) -> void:
	if get_tree() == null:
		return
	var weather_node: Node = get_tree().get_first_node_in_group(&"weather_manager")
	if weather_node == null:
		return
	if weather_node.has_method("set_weather_intensity"):
		weather_node.call("set_weather_intensity", float(weather_data.get("weather_intensity", 1.0)))
