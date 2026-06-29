class_name SaveSelectionMenu
extends Control

signal slot_selected(slot_index: int)
signal cancelled()

@onready var slot_1_button: TextureButton = %Slot1Button
@onready var slot_2_button: TextureButton = %Slot2Button
@onready var slot_3_button: TextureButton = %Slot3Button
@onready var cancel_button: TextureButton = %CancelButton

func _ready() -> void:
	slot_1_button.pressed.connect(func() -> void: slot_selected.emit(1))
	slot_2_button.pressed.connect(func() -> void: slot_selected.emit(2))
	slot_3_button.pressed.connect(func() -> void: slot_selected.emit(3))
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
