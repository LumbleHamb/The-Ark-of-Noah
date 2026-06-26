class_name ResourceOrbBar
extends CanvasLayer

## Action bar with touch/mouse-friendly buttons that fire input actions.
## Calls Input.action_press/release for "interact" so scripts react as if keyboard was pressed.

@onready var mp_button: TextureButton = %MPButton

const ACTION_INTERACT: StringName = &"interact"

func _ready() -> void:
	mp_button.pressed.connect(_on_mp_pressed)
	mp_button.button_down.connect(_on_mp_button_down)
	mp_button.button_up.connect(_on_mp_button_up)

## Fires the interact action when the MP button is pressed.
func _on_mp_pressed() -> void:
	Input.action_press(ACTION_INTERACT)

func _on_mp_button_down() -> void:
	Input.action_press(ACTION_INTERACT)

func _on_mp_button_up() -> void:
	Input.action_release(ACTION_INTERACT)
