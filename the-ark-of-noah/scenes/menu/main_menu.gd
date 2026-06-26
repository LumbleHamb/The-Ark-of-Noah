class_name MainMenu
extends Control

## Main menu screen with a background image and "New Game" button.
## Fades to black, then transitions to the world scene.

@onready var new_game_button: TextureButton = %NewGameButton
@onready var fade_overlay: ColorRect = %FadeOverlay

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	fade_overlay.color = Color(0, 0, 0, 0)

## Starts the game: fades to black, then loads the world scene.
func _on_new_game_pressed() -> void:
	new_game_button.disabled = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(&"res://scenes/world/world.tscn")
