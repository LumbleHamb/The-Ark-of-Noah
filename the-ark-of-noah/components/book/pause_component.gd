class_name PauseComponent
extends Node

## ============================================================================
## PAUSE COMPONENT — Handles pausing/unpausing the game world.
##
## Encapsulates the pause logic so the BookUIController doesn't have to know
## about the player or the scene tree.  When paused:
##   - get_tree().paused = true  (freezes world nodes; PROCESS_MODE_ALWAYS
##     nodes like the book UI keep running).
##   - The player's input is disabled via set_player_paused().
##
## Reusable: drop onto any menu scene that needs to pause the world.
## ============================================================================

signal world_paused()
signal world_resumed()

@export var pause_input_action: String = "pause"
@export var inventory_input_action: String = "inventory"

var _is_world_paused: bool = false
var _player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_find_player()

func _process(_delta: float) -> void:
	# Re-find the player if it was null (e.g. scene loaded after this).
	if _player == null or not is_instance_valid(_player):
		_find_player()

## Pauses the world. Returns true if the pause succeeded.
func pause_world() -> void:
	if _is_world_paused:
		return
	_is_world_paused = true
	if get_tree():
		get_tree().paused = true
	if _player and _player.has_method(&"set_player_paused"):
		_player.set_player_paused(true)
	world_paused.emit()

## Unpauses the world and restores player input.
func resume_world() -> void:
	if not _is_world_paused:
		return
	_is_world_paused = false
	if get_tree():
		get_tree().paused = false
	if _player and _player.has_method(&"set_player_paused"):
		_player.set_player_paused(false)
	world_resumed.emit()

func is_world_paused() -> bool:
	return _is_world_paused

func _find_player() -> void:
	if get_tree() == null:
		return
	_player = get_tree().get_first_node_in_group(&"player")
	if _player == null:
		_player = get_tree().root.find_child("player", true, false)
	if _player == null:
		_player = get_tree().root.find_child("Player", true, false)
