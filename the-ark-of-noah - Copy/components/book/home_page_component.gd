class_name HomePageComponent
extends Control

## ============================================================================
## HOME PAGE COMPONENT — The first page of the book menu.
##
## This is the "main menu" page of the pause book.  It presents three buttons:
##   - Resume   → asks the book to close and unpause the game.
##   - Save     → tells the SaveManager autoload to write the save file.
##   - Exit     → asks the book to show the exit-confirmation state.
##
## The page holds NO game logic itself.  It only emits signals; the
## BookUIController decides what those signals do (close, save, exit).
## This keeps the page reusable and free of dependencies — you could drop
## the same Home page into any book-style menu and wire its signals however
## you like.
##
## Implements the BookPage interface (on_page_opened / on_page_closed) via
## duck-typing, exactly like SettingsPageComponent and BookInventoryComponent.
## ============================================================================

signal resume_requested()
signal save_requested()
signal exit_requested()

signal page_opened()
signal page_closed()

@export var page_title: String = "Menu"

@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var exit_button: Button = %ExitButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func on_page_opened() -> void:
	page_opened.emit()

func on_page_closed() -> void:
	page_closed.emit()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_exit_pressed() -> void:
	exit_requested.emit()
