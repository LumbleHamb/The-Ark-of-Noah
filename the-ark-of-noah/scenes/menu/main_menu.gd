class_name MainMenu
extends Control
## Main menu screen with a background image and "New Game" button.
##
## Clicking/tapping the button fades the screen to black, then
## transitions to the world scene.

@onready var new_game_button: TextureButton = %NewGameButton
@onready var fade_overlay: ColorRect = %FadeOverlay


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	fade_overlay.color = Color(0, 0, 0, 0)


func _on_new_game_pressed() -> void:
	new_game_button.disabled = true  # Prevent double-clicks

	# Fade to black then switch scenes
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
	await tween.finished

	get_tree().change_scene_to_file(&"res://scenes/world/world.tscn")
