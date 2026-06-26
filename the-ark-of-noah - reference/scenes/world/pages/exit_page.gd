class_name ExitPage
extends BookPage

## Exit page — confirms before quitting the game.

signal exit_confirmed()
signal cancel_requested()

@onready var confirm_button: Button = %ConfirmExit
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_exit_confirmed)
	cancel_button.pressed.connect(_on_cancel)

func _on_exit_confirmed() -> void:
	exit_confirmed.emit()

func _on_cancel() -> void:
	cancel_requested.emit()
