class_name ActionBar
extends CanvasLayer

## Simple hotbar overlay for tool/seed selection.
## 1-4 = tools, 5+ = seeds.
## Shows the current selection visually.

signal tool_selected(slot_index: int)

@onready var slot_container: HBoxContainer = %SlotContainer

var _slots: Array[TextureRect] = []
var _selected_index: int = -1

const SLOT_SIZE: Vector2 = Vector2(48, 48)

func _ready() -> void:
	# Create slots
	for i in range(10):
		var slot := TextureRect.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		slot_container.add_child(slot)
		_slots.append(slot)

func set_slot_texture(index: int, texture: Texture2D) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].texture = texture

func select_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		# Clear previous selection highlight
		if _selected_index >= 0 and _selected_index < _slots.size():
			_slots[_selected_index].modulate = Color.WHITE
		# Highlight new selection
		_selected_index = index
		_slots[index].modulate = Color(1.0, 1.0, 0.6, 1.0)
		tool_selected.emit(index)

func get_selected_index() -> int:
	return _selected_index
