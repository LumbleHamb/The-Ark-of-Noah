class_name ResumePage
extends BookPage

## Resume page — shows a Resume button that tells PauseMenu to close.

signal resume_requested()

@onready var resume_button: Button = %ResumeButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)

func _on_resume_pressed() -> void:
	resume_requested.emit()
