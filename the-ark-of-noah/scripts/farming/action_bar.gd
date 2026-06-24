class_name ActionBar
extends CanvasLayer

## Simple hotbar overlay for tool/seed selection.
## 1-4 = tools, 5+ = seeds.
## Shows the current selection visually.
## Slots are clickable via mouse or touch.

signal tool_selected(slot_index: int)

@onready var slot_container: HBoxContainer = %SlotContainer

var _slots: Array[TextureButton] = []
var _selected_index: int = -1

const SLOT_SIZE: Vector2 = Vector2(52, 52)

func _ready() -> void:
	# Create clickable slots
	for i in range(10):
		var slot := TextureButton.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot_container.add_child(slot)
		_slots.append(slot)

func set_slot_texture(index: int, texture: Texture2D) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].texture_normal = texture

func select_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		# Clear previous selection highlight
		if _selected_index >= 0 and _selected_index < _slots.size():
			_slots[_selected_index].modulate = Color.WHITE
		# Highlight new selection
		_selected_index = index
		_slots[index].modulate = Color(1.0, 1.0, 0.6, 1.0)
		tool_selected.emit(index)

## Called when a slot button is pressed via click/touch.
func _on_slot_pressed(index: int) -> void:
	select_slot(index)

func get_selected_index() -> int:
	return _selected_index
