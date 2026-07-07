class_name SaveManagerSingleton
extends Node

## Save/Load persistence manager.
##
## Uses per-slot save files so menu flow can support New Game + Continue.
## Keeps backward compatibility by defaulting to slot 1.

const SAVE_DIR: String = "user://saves"
const SLOT_FILE_TEMPLATE: String = "slot_%d.save"
const SAVE_VERSION: int = 2
const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"

signal save_completed(success: bool)
signal load_completed(success: bool)

var active_slot: int = 1

func set_active_slot(slot_index: int) -> void:
	active_slot = clampi(slot_index, 1, 3)

func get_active_slot() -> int:
	return active_slot

func save_game() -> void:
	_ensure_save_dir()
	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"slot": active_slot,
	}
	var farm: FarmManager = _find_farm_manager()
	if farm != null and farm.has_method("get_save_data"):
		data["farm"] = farm.get_save_data()
	var time_manager_node: TimeManager = _find_time_manager()
	if time_manager_node != null and time_manager_node.has_method("get_save_data"):
		data["time"] = time_manager_node.get_save_data()
	var player_inventory: InventoryComponent = _find_player_inventory()
	if player_inventory != null:
		data["player_inventory"] = player_inventory.get_save_data()
	# Weather save data removed
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
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		data["player_scene"] = current_scene.scene_file_path
	var save_path: String = _slot_path(active_slot)
	var json_string: String = JSON.stringify(data, "\t")
	if not _atomic_write_text(save_path, json_string):
		push_error("SaveManager: failed to write save file for slot %d" % active_slot)
		save_completed.emit(false)
		return
	print("SaveManager: game saved to slot %d (%d bytes)" % [active_slot, json_string.length()])
	save_completed.emit(true)

func load_game() -> void:
	_ensure_save_dir()
	var data: Dictionary = _read_slot_data(active_slot)
	if data.is_empty():
		load_completed.emit(false)
		return
	if not _validate_save_payload(data):
		push_error("SaveManager: save payload failed validation for slot %d" % active_slot)
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
	# Weather load data removed
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
	var data: Dictionary = _read_slot_data(slot_to_check)
	return not data.is_empty() and _validate_save_payload(data)

func list_existing_slots() -> Array[int]:
	_ensure_save_dir()
	var existing: Array[int] = []
	for slot_index: int in [1, 2, 3]:
		if has_save(slot_index):
			existing.append(slot_index)
	return existing

func get_latest_slot() -> int:
	var existing: Array[int] = list_existing_slots()
	if existing.is_empty():
		return -1
	var latest_slot: int = existing[0]
	var latest_time: int = _slot_modified_time(latest_slot)
	for slot_index: int in existing:
		var stamp: int = _slot_modified_time(slot_index)
		if stamp > latest_time:
			latest_time = stamp
			latest_slot = slot_index
	return latest_slot

func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _slot_path(slot_index: int) -> String:
	return "%s/%s" % [SAVE_DIR, SLOT_FILE_TEMPLATE % slot_index]

func _slot_backup_path(slot_index: int) -> String:
	return _slot_path(slot_index) + BACKUP_SUFFIX

func _slot_modified_time(slot_index: int) -> int:
	var path: String = _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return -1
	return int(FileAccess.get_modified_time(path))

func _atomic_write_text(path: String, text: String) -> bool:
	var temp_path: String = path + TEMP_SUFFIX
	var backup_path: String = path + BACKUP_SUFFIX
	var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(text)
	temp_file.flush()
	temp_file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(backup_path)
		var backup_error: Error = DirAccess.rename_absolute(path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	var move_error: Error = DirAccess.rename_absolute(temp_path, path)
	if move_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, path)
		DirAccess.remove_absolute(temp_path)
		return false
	return true

func _read_slot_data(slot_index: int) -> Dictionary:
	var primary_path: String = _slot_path(slot_index)
	var backup_path: String = _slot_backup_path(slot_index)
	var primary: Dictionary = _read_json_dictionary(primary_path)
	if not primary.is_empty():
		return primary
	var backup: Dictionary = _read_json_dictionary(backup_path)
	if not backup.is_empty():
		print("SaveManager: recovered slot %d from backup" % slot_index)
		return backup
	if FileAccess.file_exists(primary_path) or FileAccess.file_exists(backup_path):
		push_error("SaveManager: failed to read save and backup for slot %d" % slot_index)
	return {}

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		return {}
	var data: Dictionary = json.data as Dictionary
	if data == null:
		return {}
	return data

func _validate_save_payload(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if not data.has("player"):
		return false
	if not data.has("player_inventory"):
		return false
	if not data.has("time"):
		return false
	return true

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

# Weather save/load functions removed
