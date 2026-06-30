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
signal drag_finished(from_index: int, to_index: int, target_grid: InventoryGrid)

const SLOT_SIZE: float = 48.0
const SLOT_GAP: float = 4.0
const SLOT_COLUMNS: int = 5

@export var columns: int = SLOT_COLUMNS
@export var slot_size: float = SLOT_SIZE
@export var slot_gap: float = SLOT_GAP
@export var read_only: bool = false

var _empty_slot_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")
var _inventory: InventoryComponent = null
var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _slots: Array[TextureRect] = []
var _slot_icons: Array[TextureRect] = []
var _dragging_from: int = -1
var _drag_preview: TextureRect = null
var _tooltip_label: Label = null
var _selected_index: int = 0

func _ready() -> void:
	_build_ui()
	set_process_unhandled_input(true)
	set_process_input(true)

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
	# Cancel any in-progress drag (e.g. if the UI closed during a drag).
	if _dragging_from >= 0 or _drag_preview.visible:
		_drag_preview.visible = false
		if _dragging_from >= 0 and _dragging_from < _slot_icons.size():
			_slot_icons[_dragging_from].modulate = Color.WHITE
		_dragging_from = -1
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()
	_slots.clear()
	_slot_icons.clear()
	var capacity: int = _inventory.item_capacity if _inventory else 0
	if capacity <= 0:
		_selected_index = 0
		return
	_selected_index = clampi(_selected_index, 0, capacity - 1)
	for i in range(capacity):
		var slot: TextureRect = _make_slot(i)
		_grid.add_child(slot)
		_slots.append(slot)
	_update_selection_visuals()

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

	# Drag preview sprite (hidden until a drag starts).
	_drag_preview = TextureRect.new()
	_drag_preview.visible = false
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.z_index = 200
	_drag_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_preview.custom_minimum_size = Vector2(slot_size * 0.9, slot_size * 0.9)
	add_child(_drag_preview)

func _make_slot(index: int) -> TextureRect:
	var slot: TextureRect = TextureRect.new()
	slot.name = "Slot_%02d" % index
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.texture = _empty_slot_texture
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.anchor_left = 0.0
	icon_rect.anchor_top = 0.0
	icon_rect.anchor_right = 1.0
	icon_rect.anchor_bottom = 1.0
	icon_rect.offset_left = 6.0
	icon_rect.offset_top = 6.0
	icon_rect.offset_right = -6.0
	icon_rect.offset_bottom = -6.0
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_rect)
	_slot_icons.append(icon_rect)
	var stack: ItemStack = _stack_at(index)
	if stack != null and stack.icon != null:
		icon_rect.texture = stack.icon
		if stack.item_name.strip_edges() != "":
			slot.tooltip_text = "%s\nx%d" % [stack.item_name, stack.count]
		else:
			slot.tooltip_text = ""
	else:
		icon_rect.texture = null
		slot.tooltip_text = ""
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
	_selected_index = index
	_update_selection_visuals()
	if read_only:
		return
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
		if _drag_preview.visible:
			_position_drag_preview()

func _start_drag(index: int, _slot: TextureRect) -> void:
	var stack: ItemStack = _stack_at(index)
	print("InventoryGrid._start_drag(", index, "): stack=", stack, " icon=", stack.icon if stack else null, " name=", stack.item_name if stack else "null")
	if stack == null or stack.icon == null:
		# Clicking an empty slot with nothing in hand = nothing.
		print("  -> ABORT: stack or icon is null")
		_dragging_from = -1
		return
	print("  -> STARTED drag from index ", index)
	_dragging_from = index
	# Show the floating drag-preview sprite.
	_drag_preview.texture = stack.icon
	_drag_preview.visible = true
	_position_drag_preview()
	# Dim the source slot so it looks "picked up".
	if index < _slot_icons.size():
		_slot_icons[index].modulate = Color(1, 1, 1, 0.3)

func _end_drag(_slot: TextureRect, index: int) -> void:
	_drag_preview.visible = false
	# Restore source slot opacity.
	if _dragging_from >= 0 and _dragging_from < _slot_icons.size():
		_slot_icons[_dragging_from].modulate = Color.WHITE
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
		# NOTE: `index` comes from gui_input which always fires on the press
		# slot (Godot sends release to the same control).  Use the actual
		# mouse position to find the real target slot.
		var target_idx: int = _slot_index_at_mouse()
		if target_idx < 0:
			target_idx = index  # fallback
		_inventory.move_slot(_dragging_from, target_idx)
		refresh()
	drag_finished.emit(_dragging_from, index, target_grid)
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
		_tooltip_label.text = "%s  (x%d)" % [stack.item_name, stack.count]
		_tooltip_label.visible = true
		_position_tooltip()

func _hide_drag_tooltip() -> void:
	if _dragging_from < 0:
		_tooltip_label.visible = false

func _update_tooltip_to_mouse() -> void:
	if _tooltip_label.visible:
		_position_tooltip()

func _position_tooltip() -> void:
	_tooltip_label.position = get_local_mouse_position() + Vector2(12, 12)

## Positions the floating drag-preview sprite centered on the mouse cursor,
## using global coordinates so it stays in place when moving between grids.
func _position_drag_preview() -> void:
	var half: float = _drag_preview.custom_minimum_size.x * 0.5
	_drag_preview.global_position = get_global_mouse_position() - Vector2(half, half)

# ---------------------------------------------------------------------------
# GRID-UNDER-MOUSE HELPERS (for cross-grid drag/drop transfers)
# ---------------------------------------------------------------------------
func _find_grid_under_mouse() -> InventoryGrid:
	# Walk up the tree from this grid's parent looking for sibling subtrees
	# that contain an InventoryGrid (at any nesting depth) under the mouse.
	# This supports both flat layouts where grids are direct siblings
	# (e.g. InventoryWindow) and nested layouts where each grid sits inside
	# its own container (e.g. ChestUI: PlayerSide/PlayerGrid).
	var mouse_pos: Vector2 = get_global_mouse_position()
	var ancestor: Node = get_parent()
	while ancestor != null:
		for child: Node in ancestor.get_children():
			if child == self:
				continue
			var found: InventoryGrid = _find_grid_in_subtree(child, mouse_pos)
			if found != null:
				return found
		ancestor = ancestor.get_parent()
	return null

## Recursively searches `node` and its descendants for an InventoryGrid whose
## global rect contains `mouse_pos`.  Returns null if nothing is found.
func _find_grid_in_subtree(node: Node, mouse_pos: Vector2) -> InventoryGrid:
	if node is InventoryGrid:
		var grid: InventoryGrid = node as InventoryGrid
		if grid.get_global_rect().has_point(mouse_pos):
			return grid
	for child: Node in node.get_children():
		var found: InventoryGrid = _find_grid_in_subtree(child, mouse_pos)
		if found != null:
			return found
	return null

func _slot_index_at_mouse() -> int:
	# Returns the slot index under the mouse in THIS grid, or -1.
	var mouse_pos: Vector2 = get_global_mouse_position()
	for i in range(_slots.size()):
		if _slots[i].get_global_rect().has_point(mouse_pos):
			return i
	return -1

func _input(event: InputEvent) -> void:
	if _dragging_from < 0:
		return
	# If the preview isn't visible, this _dragging_from is stale — it was
	# inherited from a cross-grid transfer that already completed on another
	# grid (the preview was hidden before the transfer).  Clear and bail.
	if not _drag_preview.visible:
		_dragging_from = -1
		return
	if event is InputEventMouseMotion and _drag_preview.visible:
		_position_drag_preview()
	elif event is InputEventMouseButton and not event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		# Mouse released during a drag — check where.
		# First, is the mouse over a slot in THIS grid? If so let gui_input
		# handle it normally (reorder / merge / swap within the same grid).
		if _slot_index_at_mouse() >= 0:
			return
		# Is the mouse over a slot in a DIFFERENT grid? Cross-grid transfer.
		var target_grid: InventoryGrid = _find_grid_under_mouse()
		if target_grid != null:
			var target_slot: int = target_grid._slot_index_at_mouse()
			if target_slot >= 0:
				_drag_preview.visible = false
				if _dragging_from >= 0 and _dragging_from < _slot_icons.size():
					_slot_icons[_dragging_from].modulate = Color.WHITE
				stack_dragged_to.emit(target_grid, _dragging_from, target_slot)
				_inventory.transfer_to(target_grid._inventory, _dragging_from, target_slot)
				target_grid.refresh()
				refresh()
				var old_from: int = _dragging_from
				_dragging_from = -1
				drag_finished.emit(old_from, target_slot, target_grid)
				return
		# Over empty space (no slot in any grid) — cancel the drag cleanly.
		_drag_preview.visible = false
		if _dragging_from >= 0 and _dragging_from < _slot_icons.size():
			_slot_icons[_dragging_from].modulate = Color.WHITE
		_dragging_from = -1

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if read_only:
		return
	if _inventory == null or _slots.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		_selected_index = max(0, _selected_index - 1)
		_update_selection_visuals()
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_selected_index = min(_slots.size() - 1, _selected_index + 1)
		_update_selection_visuals()
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_selected_index = max(0, _selected_index - max(columns, 1))
		_update_selection_visuals()
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_selected_index = min(_slots.size() - 1, _selected_index + max(columns, 1))
		_update_selection_visuals()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		if _dragging_from < 0:
			_start_drag(_selected_index, _slots[_selected_index])
		else:
			_end_drag(_slots[_selected_index], _selected_index)
		accept_event()

func _update_selection_visuals() -> void:
	for i: int in range(_slots.size()):
		if i == _selected_index:
			_slots[i].self_modulate = Color(1.2, 1.15, 0.8, 1.0)
		else:
			_slots[i].self_modulate = Color.WHITE
