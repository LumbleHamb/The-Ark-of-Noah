class_name MainMenu
extends Control

## Main menu flow:
## New Game -> slot select -> intro cutscene placeholder -> world.
## Continue -> slot select -> world -> load chosen slot.

const INTRO_CUTSCENE_PATH: String = "res://scenes/cutscenes/intro_cutscene_placeholder.tscn"
const WORLD_SCENE_PATH: String = "res://scenes/world/world.tscn"

@onready var new_game_button: TextureButton = %NewGameButton
@onready var continue_button: TextureButton = %ContinueButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var save_selection_menu: SaveSelectionMenu = %SaveSelectionMenu
@onready var settings_popup: SettingsPopup = %SettingsPopup
@onready var fade_overlay: TextureRect = %FadeOverlay
@onready var background: TextureRect = %Background

var _slot_mode: String = ""
var _background_tween: Tween = null

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_selection_menu.slot_selected.connect(_on_slot_selected)
	save_selection_menu.cancelled.connect(_on_slot_cancelled)
	fade_overlay.modulate = Color(0.0, 0.0, 0.0, 0.0)
	_animate_background()

func _animate_background() -> void:
	if _background_tween != null and _background_tween.is_running():
		_background_tween.kill()
	_background_tween = create_tween()
	_background_tween.set_loops()
	_background_tween.tween_property(background, "modulate", Color(1.08, 1.08, 1.08, 1.0), 2.2)
	_background_tween.tween_property(background, "modulate", Color(0.92, 0.92, 0.92, 1.0), 2.2)

func _on_new_game_pressed() -> void:
	_slot_mode = "new"
	save_selection_menu.visible = true

func _on_continue_pressed() -> void:
	_slot_mode = "continue"
	save_selection_menu.visible = true

func _on_settings_pressed() -> void:
	settings_popup.popup_centered()

func _on_slot_cancelled() -> void:
	save_selection_menu.visible = false
	_slot_mode = ""

func _on_slot_selected(slot_index: int) -> void:
	save_selection_menu.visible = false
	var save_manager_node: Node = get_node_or_null("/root/save_manager")
	if save_manager_node == null:
		return
	save_manager_node.call("set_active_slot", slot_index)
	if _slot_mode == "new":
		save_manager_node.call("delete_save", slot_index)
		await _transition_to(INTRO_CUTSCENE_PATH)
	elif _slot_mode == "continue":
		if not bool(save_manager_node.call("has_save", slot_index)):
			return
		await _transition_to(WORLD_SCENE_PATH)
		await get_tree().process_frame
		save_manager_node.call("load_game")
	_slot_mode = ""

func _transition_to(scene_path: String) -> void:
	var transition_node: Node = get_node_or_null("/root/scene_transition")
	if transition_node != null and transition_node.has_method("transition"):
		await transition_node.call("transition", scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
