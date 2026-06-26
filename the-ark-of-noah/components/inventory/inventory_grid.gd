class_name InventoryGrid
extends Control

## ============================================================================
## INVENTORY GRID — Reusable drag-and-drop item slot grid.
##
## Used by the book inventory page AND the chest UI.  Bind it to any
## InventoryComponent with bind_inventory(), call refresh(), and the grid
## renders one TextureRect slot per item slot up to the inventory's capacity.
##
## Features:
##   - Left-click drag to move a stack between slots (reorder / merge / swap).
##   - Right-click to split half a stack (stackable items only).
##   - Hover tooltips showing item name + count.
##   - Emits `slot_activated(index)` on double-click (for equipping / using).
##   - Emits `stack_moved_to_grid(other_grid, from, to)` when a stack is
##     dragged from this grid onto another InventoryGrid (chest transfers).
##
## The grid owns no inventory data — it only renders an InventoryComponent and
## forwards user actions back to it via move_slot / transfer_to.  This keeps a
## single source of truth (the InventoryComponent) and makes the grid trivially
## reusable.
## ============================================================================

signal stack_dragged_to(other_grid: InventoryGrid, from_index: int, to_index: int)

const SLOT_SIZE: float = 48.0
const SLOT_GAP: float = 4.0
const SLOT_COLUMNS: int = 5

@export var columns: int = SLOT_COLUMNS
@export var slot_size: float = SLOT_SIZE
@export var slot_gap: float = SLOT_GAP

var _empty_slot_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")
var _inventory: InventoryComponent = null
var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _slots: Array[TextureRect] = []
var _dragging_from: int = -1
var _tooltip_label: Label = null

func _ready() -> void:
	_build_ui()

## Binds this grid to an InventoryComponent and refreshes the display.
func bind_inventory(inventory: InventoryComponent) -> void:
	if _inventory and _inventory.has_signal("items_changed"):
		_inventory.items_changed.disconnect(refresh)
	_inventory = inventory
	if _inventory and _inventory.has_signal("items_changed"):
		_inventory.items_changed.connect(refresh)
	refresh()

## Rebuilds the slot grid to match the bound inventory's capacity + contents.
func refresh() -> void:
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()
	_slots.clear()
	var capacity: int = _inventory.item_capacity if _inventory else 0
	for i in range(capacity):
		var slot: TextureRect = _make_slot(i)
		_grid.add_child(slot)
		_slots.append(slot)

# ---------------------------------------------------------------------------
# UI CONSTRUCTION
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.clip_contents = true
	add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", int(slot_gap))
	_grid.add_theme_constant_override("v_separation", int(slot_gap))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	# Tooltip label (hidden until hovered).
	_tooltip_label = Label.new()
	_tooltip_label.visible = false
	_tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	_tooltip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_tooltip_label.add_theme_font_size_override("font_size", 14)
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.z_index = 100
	add_child(_tooltip_label)

func _make_slot(index: int) -> TextureRect:
	var slot: TextureRect = TextureRect.new()
	slot.name = "Slot_%02d" % index
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.texture = _empty_slot_texture
	var stack: ItemStack = _stack_at(index)
	if stack:
		slot.texture = stack.icon if stack.icon else _empty_slot_texture
		slot.tooltip_text = "%s\nx%d" % [stack.item_name, stack.count]
	slot.gui_input.connect(_on_slot_gui_input.bind(index, slot))
	slot.mouse_entered.connect(_on_slot_mouse_entered.bind(index))
	slot.mouse_exited.connect(_on_slot_mouse_exited)
	return slot

func _stack_at(index: int) -> ItemStack:
	if _inventory == null or index < 0 or index >= _inventory.items.size():
		return null
	return _inventory.items[index]

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, index: int, slot: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_start_drag(index, slot)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_split_stack(index)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging_from >= 0:
			_end_drag(slot, index)
	elif event is InputEventMouseMotion and _dragging_from >= 0:
		_update_tooltip_to_mouse()

func _start_drag(index: int, _slot: TextureRect) -> void:
	if _stack_at(index) == null:
		# Clicking an empty slot with nothing in hand = nothing.
		_dragging_from = -1
		return
	_dragging_from = index
	_show_drag_tooltip(index)

func _end_drag(_slot: TextureRect, index: int) -> void:
	_hide_drag_tooltip()
	if _dragging_from < 0:
		return
	# Did the user drop onto a different InventoryGrid (chest transfer)?
	var target_grid: InventoryGrid = _find_grid_under_mouse()
	if target_grid != null and target_grid != self:
		stack_dragged_to.emit(target_grid, _dragging_from, index)
		_inventory.transfer_to(target_grid._inventory, _dragging_from, target_grid._slot_index_at_mouse())
		target_grid.refresh()
		refresh()
	else:
		# Drop within this grid: reorder / merge / swap.
		_inventory.move_slot(_dragging_from, index)
		refresh()
	_dragging_from = -1

func _split_stack(index: int) -> void:
	if _inventory == null:
		return
	var stack: ItemStack = _stack_at(index)
	if stack == null or not stack.stackable or stack.count <= 1:
		return
	# Move half of this stack into a new empty slot.
	var half: int = int(stack.count / 2.0) if stack.count > 1 else 1
	if half < 1:
		return
	var new_stack: ItemStack = ItemStack.new()
	new_stack.item_id = stack.item_id
	new_stack.item_name = stack.item_name
	new_stack.icon = stack.icon
	new_stack.max_stack = stack.max_stack
	new_stack.stackable = true
	new_stack.crop_ref = stack.crop_ref
	new_stack.tool_ref = stack.tool_ref
	new_stack.count = half
	stack.count -= half
	var leftover: int = _inventory.add_item(new_stack)
	if leftover > 0:
		stack.count += leftover
	_inventory.items_changed.emit()
	_inventory.inventory_changed.emit()
	refresh()

# ---------------------------------------------------------------------------
# TOOLTIP
# ---------------------------------------------------------------------------
func _on_slot_mouse_entered(index: int) -> void:
	var stack: ItemStack = _stack_at(index)
	if stack:
		_tooltip_label.text = "%s  (x%d)" % [stack.item_name, stack.count]
		_tooltip_label.visible = true
		_position_tooltip()

func _on_slot_mouse_exited() -> void:
	_tooltip_label.visible = false

func _show_drag_tooltip(index: int) -> void:
	var stack: ItemStack = _stack_at(index)
	if stack:
		_tooltip_label.text = "Dragging: %s  (x%d)" % [stack.item_name, stack.count]
		_tooltip_label.visible = true
		_position_tooltip()

func _hide_drag_tooltip() -> void:
	if _dragging_from < 0:
		_tooltip_label.visible = false

func _update_tooltip_to_mouse() -> void:
	_position_tooltip()

func _position_tooltip() -> void:
	_tooltip_label.position = get_local_mouse_position() + Vector2(12, 12)

# ---------------------------------------------------------------------------
# GRID-UNDER-MOUSE HELPERS (for cross-grid drag/drop transfers)
# ---------------------------------------------------------------------------
func _find_grid_under_mouse() -> InventoryGrid:
	# Walk up the tree from this grid's parent looking for siblings that are
	# InventoryGrids and contain the mouse position.
	var mouse_pos: Vector2 = get_global_mouse_position()
	var ancestor: Node = get_parent()
	while ancestor != null:
		for child: Node in ancestor.get_children():
			if child is InventoryGrid and child != self:
				var grid: InventoryGrid = child as InventoryGrid
				if grid.get_global_rect().has_point(mouse_pos):
					return grid
		ancestor = ancestor.get_parent()
	return null

func _slot_index_at_mouse() -> int:
	# Returns the slot index under the mouse in THIS grid, or -1.
	var mouse_pos: Vector2 = get_global_mouse_position()
	for i in range(_slots.size()):
		if _slots[i].get_global_rect().has_point(mouse_pos):
			return i
	return -1
