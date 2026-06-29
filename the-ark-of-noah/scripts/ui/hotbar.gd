extends CanvasLayer
class_name ActionBar

## Simple hotbar overlay for tool/seed selection.

## Slots 1-8 are mirrored in InventoryUI's Action Bar row.

signal tool_selected(slot_index: int)

@export_range(2, 16, 1) var slot_count: int = 8

@onready var slot_container: HBoxContainer = %SlotContainer

var _slots: Array[TextureButton] = []
var _slot_icons: Array[TextureRect] = []
var _selected_index: int = -1
const SLOT_SIZE: Vector2 = Vector2(56, 56)
const SLOT_ICON_PADDING: float = 8.0
const SLOT_EMPTY_TEXTURE: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_03_Empty.png")

func _ready() -> void:
	for i in range(slot_count):
		var slot: TextureButton = TextureButton.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.texture_normal = SLOT_EMPTY_TEXTURE
		slot.texture_pressed = SLOT_EMPTY_TEXTURE
		slot.texture_hover = SLOT_EMPTY_TEXTURE
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.pressed.connect(_on_slot_pressed.bind(i))
		var icon: TextureRect = TextureRect.new()
		icon.anchor_left = 0.0
		icon.anchor_top = 0.0
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = SLOT_ICON_PADDING
		icon.offset_top = SLOT_ICON_PADDING
		icon.offset_right = -SLOT_ICON_PADDING
		icon.offset_bottom = -SLOT_ICON_PADDING
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		slot_container.add_child(slot)
		_slots.append(slot)
		_slot_icons.append(icon)

func set_slot_texture(index: int, texture: Texture2D) -> void:
	if index >= 0 and index < _slot_icons.size():
		_slot_icons[index].texture = texture

func clear_slot_texture(index: int) -> void:
	if index >= 0 and index < _slot_icons.size():
		_slot_icons[index].texture = null

func select_slot(index: int) -> void:
	if index >= 0 and index < _slots.size():
		if _selected_index >= 0 and _selected_index < _slots.size():
			_slots[_selected_index].modulate = Color.WHITE
		_selected_index = index
		_slots[index].modulate = Color(1.28, 1.18, 0.8, 1.0)
		tool_selected.emit(index)

## Called when a slot button is pressed via click or touch.
func _on_slot_pressed(index: int) -> void:
	select_slot(index)

func get_selected_index() -> int:
	return _selected_index
