class_name InventoryPage
extends BookPage

## Inventory page — shows the player's collected items in a grid of slots.

const SLOT_COLS: int = 7
const SLOT_ROWS: int = 5
const SLOT_SIZE: float = 48.0
const SLOT_GAP: float = 4.0

@onready var grid_container: GridContainer = %SlotGrid
@onready var empty_slot_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")
@onready var selection_highlight: ColorRect = %SelectionHighlight

var _slot_nodes: Array[TextureRect] = []
var _selected_slot: int = -1

func _ready() -> void:
	_build_slot_grid()

func _build_slot_grid() -> void:
	## Create the visual slot grid of empty slots.
	grid_container.columns = SLOT_COLS
	grid_container.add_theme_constant_override("h_separation", int(SLOT_GAP))
	grid_container.add_theme_constant_override("v_separation", int(SLOT_GAP))
	
	for i in range(SLOT_COLS * SLOT_ROWS):
		var slot: TextureRect = TextureRect.new()
		slot.name = "Slot_%02d" % i
		slot.texture = empty_slot_texture
		slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		grid_container.add_child(slot)
		_slot_nodes.append(slot)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_slot(slot_index)

func _select_slot(index: int) -> void:
	_selected_slot = index
	if selection_highlight and index >= 0 and index < _slot_nodes.size():
		var slot: TextureRect = _slot_nodes[index]
		selection_highlight.global_position = slot.global_position
		selection_highlight.size = slot.size
		selection_highlight.show()

func refresh_items() -> void:
	## Called when inventory data changes. For now just a placeholder.
	pass
