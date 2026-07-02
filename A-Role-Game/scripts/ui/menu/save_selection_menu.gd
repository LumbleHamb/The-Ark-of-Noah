class_name SaveSelectionMenu
extends Control

signal slot_selected(slot_index: int)
signal cancelled()

@onready var slot_1_button: TextureButton = %Slot1Button
@onready var slot_2_button: TextureButton = %Slot2Button
@onready var slot_3_button: TextureButton = %Slot3Button
@onready var slot_1_label: Label = %Slot1Label
@onready var slot_2_label: Label = %Slot2Label
@onready var slot_3_label: Label = %Slot3Label
@onready var cancel_button: TextureButton = %CancelButton

func _ready() -> void:
	slot_1_button.pressed.connect(func() -> void: slot_selected.emit(1))
	slot_2_button.pressed.connect(func() -> void: slot_selected.emit(2))
	slot_3_button.pressed.connect(func() -> void: slot_selected.emit(3))
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	visibility_changed.connect(_refresh_slot_labels)
	_refresh_slot_labels()

func _refresh_slot_labels() -> void:
	var save_manager_node: Node = get_node_or_null("/root/save_manager")
	if save_manager_node == null:
		return
	_update_slot_label(1, slot_1_label, save_manager_node)
	_update_slot_label(2, slot_2_label, save_manager_node)
	_update_slot_label(3, slot_3_label, save_manager_node)

func _update_slot_label(slot_index: int, label: Label, save_manager_node: Node) -> void:
	if label == null:
		return
	var exists: bool = bool(save_manager_node.call("has_save", slot_index))
	label.text = "Save %d - %s" % [slot_index, "Used" if exists else "Empty"]
