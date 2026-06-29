class_name InventoryWindow
extends CanvasLayer

## ============================================================================
## INVENTORY WINDOW
##
## Standalone inventory UI (separate from pause book).
## Uses InventoryGrid as reusable slot UI and can bind to any InventoryComponent.
##
## Two grids:
##   - inventory_grid : shows the player's full ItemStack array (items[0..N]).
##   - hotbar_grid    : shows the 8 "hotbar" slots that mirror the in-game
##                      action bar overlay.  Items can be dragged between the
##                      two grids to equip/unequip items.
##
## Drag/drop between grids:
##   Dragging FROM inventory TO hotbar  -> moves the ItemStack from the player's
##     items array into the hotbar inventory.  If the stack has a tool_ref it
##     becomes a tool; if crop_ref it becomes a seed; otherwise it appears as
##     a plain item on the action bar.
##   Dragging FROM hotbar TO inventory  -> moves the stack back into the
##     player's general item storage.  The hotbar slot is cleared.
## ============================================================================

signal inventory_opened()
signal inventory_closed()

@onready var dimmer: TextureRect = %Dimmer
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var inventory_grid: InventoryGrid = %InventoryGrid
@onready var hotbar_grid: InventoryGrid = %HotbarGrid

var _bound_inventory: InventoryComponent = null
## Persistent hotbar inventory - the source of truth for what's on the action bar.
var _hotbar_inventory: InventoryComponent = null
var _action_bar_node: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	_hotbar_inventory = InventoryComponent.new()
	_hotbar_inventory.item_capacity = 8

func _process(_delta: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed("pause"):
		close_ui()

func toggle_ui() -> void:
	if visible:
		close_ui()
		return
	if _is_blocked_by_other_overlay():
		return
	open_ui()

func open_ui() -> void:
	if _is_blocked_by_other_overlay():
		return
	_bind_player_inventory()
	if _bound_inventory == null:
		return
	_hotbar_inventory.item_capacity = _bound_inventory.hotbar_slot_count
	_sync_hotbar_from_tools_and_seeds()
	inventory_grid.bind_inventory(_bound_inventory)
	hotbar_grid.bind_inventory(_hotbar_inventory)
	_connect_signals()
	visible = true
	dimmer.modulate.a = 0.35
	_set_player_paused(true)
	inventory_opened.emit()

func close_ui() -> void:
	_disconnect_signals()
	# Before closing, move any plain hotbar items (no tool/crop ref) back to
	# the player's inventory so they aren't orphaned.
	_return_orphan_hotbar_items()
	visible = false
	dimmer.modulate.a = 0.0
	_set_player_paused(false)
	inventory_closed.emit()

func is_open() -> bool:
	return visible

## Opens this UI for an arbitrary inventory (e.g. chest) with a custom title.
## The hotbar still shows the player's equipped items.
func open_for_inventory(inventory: InventoryComponent, title: String = "Inventory") -> void:
	_bound_inventory = inventory
	if _bound_inventory == null:
		return
	title_label.text = title
	_hotbar_inventory.item_capacity = _bound_inventory.hotbar_slot_count
	_sync_hotbar_from_tools_and_seeds()
	inventory_grid.bind_inventory(_bound_inventory)
	hotbar_grid.bind_inventory(_hotbar_inventory)
	_connect_signals()
	visible = true
	dimmer.modulate.a = 0.35
	inventory_opened.emit()

# ---------------------------------------------------------------------------
# PLAYER BINDING
# ---------------------------------------------------------------------------

func _bind_player_inventory() -> void:
	_bound_inventory = null
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		player = tree.get_first_node_in_group(&"Player")
	if player == null:
		return
	for child: Node in player.get_children():
		if child is InventoryComponent:
			_bound_inventory = child as InventoryComponent
			break
	if _bound_inventory != null:
		_action_bar_node = _find_action_bar()

func _find_action_bar() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		player = tree.get_first_node_in_group(&"Player")
	if player == null:
		return null
	for child: Node in player.get_children():
		if child is ActionBar:
			return child
	return null

func _set_player_paused(paused: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		player = tree.get_first_node_in_group(&"Player")
	if player != null and player.has_method(&"set_player_paused"):
		player.call("set_player_paused", paused)

# ---------------------------------------------------------------------------
# SIGNAL MANAGEMENT
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	if not inventory_grid.drag_finished.is_connected(_on_grid_drag_finished):
		inventory_grid.drag_finished.connect(_on_grid_drag_finished)
	if not hotbar_grid.drag_finished.is_connected(_on_grid_drag_finished):
		hotbar_grid.drag_finished.connect(_on_grid_drag_finished)
	if not _hotbar_inventory.items_changed.is_connected(_on_hotbar_changed):
		_hotbar_inventory.items_changed.connect(_on_hotbar_changed)

func _disconnect_signals() -> void:
	if inventory_grid.drag_finished.is_connected(_on_grid_drag_finished):
		inventory_grid.drag_finished.disconnect(_on_grid_drag_finished)
	if hotbar_grid.drag_finished.is_connected(_on_grid_drag_finished):
		hotbar_grid.drag_finished.disconnect(_on_grid_drag_finished)
	if _hotbar_inventory.items_changed.is_connected(_on_hotbar_changed):
		_hotbar_inventory.items_changed.disconnect(_on_hotbar_changed)

# ---------------------------------------------------------------------------
# HOTBAR SYNC - convert between tool/seed arrays and hotbar ItemStacks
# ---------------------------------------------------------------------------

## Populates _hotbar_inventory from the player's tool_inventory + seed_inventory.
func _sync_hotbar_from_tools_and_seeds() -> void:
	if _bound_inventory == null or _hotbar_inventory == null:
		return
	_hotbar_inventory.items.clear()
	_hotbar_inventory.item_capacity = _bound_inventory.hotbar_slot_count
	for i: int in range(_bound_inventory.hotbar_slot_count):
		var tex: Texture2D = _bound_inventory.get_hotbar_texture(i)
		var label: String = _bound_inventory.get_hotbar_slot_label(i)
		if tex == null:
			_hotbar_inventory.items.append(null)
			continue
		var stack: ItemStack = ItemStack.new()
		stack.item_id = "hotbar_%d" % i
		stack.item_name = label if label != "" else "Action %d" % (i + 1)
		stack.icon = tex
		stack.count = 1
		stack.max_stack = 1
		stack.stackable = false
		if i < _bound_inventory.tool_inventory.size():
			stack.tool_ref = _bound_inventory.tool_inventory[i]
		else:
			var seed_idx: int = i - _bound_inventory.tool_inventory.size()
			if seed_idx >= 0 and seed_idx < _bound_inventory.seed_inventory.size():
				stack.crop_ref = _bound_inventory.seed_inventory[seed_idx]
		_hotbar_inventory.items.append(stack)

## Rebuilds the player's tool_inventory and seed_inventory from the hotbar items,
## then pushes textures to the in-game action bar overlay.
func _sync_tools_and_seeds_from_hotbar() -> void:
	if _bound_inventory == null:
		return
	_bound_inventory.tool_inventory.clear()
	_bound_inventory.seed_inventory.clear()
	for stack: ItemStack in _hotbar_inventory.items:
		if stack == null:
			continue
		if stack.tool_ref != null:
			_bound_inventory.tool_inventory.append(stack.tool_ref)
		elif stack.crop_ref != null:
			_bound_inventory.seed_inventory.append(stack.crop_ref)
	_update_action_bar_textures()

## Directly updates the in-game ActionBar overlay textures from the hotbar items.
## This handles plain items (no tool_ref/crop_ref) that get dragged onto hotbar slots.
func _update_action_bar_textures() -> void:
	if _bound_inventory == null:
		return
	var bar: Node = _action_bar_node
	if bar == null or not bar.has_method("set_slot_texture"):
		_bound_inventory.update_action_bar()
		return
	for idx: int in range(_hotbar_inventory.items.size()):
		var stack: ItemStack = _hotbar_inventory.items[idx] if idx < _hotbar_inventory.items.size() else null
		if stack != null and stack.icon != null:
			bar.call("set_slot_texture", idx, stack.icon)
		elif bar.has_method("clear_slot_texture"):
			bar.call("clear_slot_texture", idx)
	if _bound_inventory.selected_slot >= 0 and bar.has_method("select_slot"):
		bar.call("select_slot", _bound_inventory.selected_slot)

# ---------------------------------------------------------------------------
# DRAG / DROP HANDLING
# ---------------------------------------------------------------------------

func _on_grid_drag_finished(_from_index: int, _to_index: int, _target_grid: InventoryGrid) -> void:
	"""Called after any drag completes in either grid. Syncs hotbar state."""
	if _bound_inventory == null or not visible:
		return
	_sync_tools_and_seeds_from_hotbar()
	_bound_inventory.inventory_changed.emit()

func _on_hotbar_changed() -> void:
	"""Called when _hotbar_inventory.items changes directly."""
	if not visible or _bound_inventory == null:
		return
	_sync_tools_and_seeds_from_hotbar()

## Moves any hotbar items that aren't tools or seeds back to the main inventory.
## Prevents items from being orphaned when the inventory window closes.
func _return_orphan_hotbar_items() -> void:
	if _bound_inventory == null or _hotbar_inventory == null:
		return
	var to_remove: Array[int] = []
	for i: int in range(_hotbar_inventory.items.size()):
		var stack: ItemStack = _hotbar_inventory.items[i]
		if stack == null:
			continue
		if stack.tool_ref == null and stack.crop_ref == null:
			# Plain item with no tool/seed reference -- move back.
			var leftover: int = _bound_inventory.add_item(stack)
			if leftover <= 0:
				to_remove.append(i)
	# Remove the orphaned items from the hotbar (in reverse order).
	to_remove.reverse()
	for idx: int in to_remove:
		_hotbar_inventory.items.remove_at(idx)

# ---------------------------------------------------------------------------
# OVERLAY BLOCKING
# ---------------------------------------------------------------------------

func _is_blocked_by_other_overlay() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var chest_ui: CanvasLayer = tree.root.get_node_or_null("ChestUI") as CanvasLayer
	if chest_ui != null and chest_ui.visible:
		return true
	var pause_menu: CanvasLayer = tree.root.get_node_or_null("PauseMenu") as CanvasLayer
	if pause_menu == null:
		return false
	if pause_menu.has_method(&"is_open"):
		return bool(pause_menu.call("is_open"))
	return pause_menu.visible
