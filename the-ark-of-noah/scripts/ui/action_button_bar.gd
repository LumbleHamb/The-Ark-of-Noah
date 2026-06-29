class_name ResourceOrbBar
extends CanvasLayer

## Action bar with touch/mouse-friendly buttons that fire input actions.
## Calls Input.action_press/release for "interact" so scripts react as if keyboard was pressed.

@onready var mp_button: TextureButton = %MPButton
@onready var inventory_button: TextureButton = %InventoryButton

const ACTION_INTERACT: StringName = &"interact"
const ACTION_INVENTORY: StringName = &"inventory"

func _ready() -> void:
	mp_button.pressed.connect(_on_mp_pressed)
	mp_button.button_down.connect(_on_mp_button_down)
	mp_button.button_up.connect(_on_mp_button_up)
	inventory_button.pressed.connect(_on_inventory_button_pressed)

## Fires the interact action when the MP button is pressed.
func _on_mp_pressed() -> void:
	Input.action_press(ACTION_INTERACT)

func _on_mp_button_down() -> void:
	Input.action_press(ACTION_INTERACT)

func _on_mp_button_up() -> void:
	Input.action_release(ACTION_INTERACT)

func _on_inventory_button_pressed() -> void:
	if _is_any_blocking_overlay_open():
		return
	Input.action_press(ACTION_INVENTORY)
	Input.action_release(ACTION_INVENTORY)

func _is_any_blocking_overlay_open() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var pause_menu: CanvasLayer = tree.root.get_node_or_null("PauseMenu") as CanvasLayer
	if pause_menu != null:
		if pause_menu.has_method(&"is_open") and bool(pause_menu.call("is_open")):
			return true
		if pause_menu.visible:
			return true
	var chest_ui: CanvasLayer = tree.root.get_node_or_null("ChestUI") as CanvasLayer
	if chest_ui != null and chest_ui.visible:
		return true
	return false
