class_name InventoryComponent
extends Component

## ============================================================================
## INVENTORY COMPONENT — Reusable inventory for any entity that holds items.
##
## Drop this on the player, an NPC shopkeeper, a chest, or a storage wagon.
## It owns three kinds of storage so it stays compatible with the existing
## action bar AND supports a modern stack-based item inventory:
##
##   1. tool_inventory  : Array[ToolData] — the player's hotbar tools (hoes,
##                         axes, pickaxes). Drives the ActionBar hotbar and the
##                         farming / attack systems. Kept for compatibility.
##   2. seed_inventory  : Array[CropData] — seeds the player can plant.
##                         Kept for compatibility with the farming system.
##   3. items           : Array[ItemStack] — a general stack-based inventory
##                         for harvested crops, picked-up loot, and anything
##                         created with ItemStack. This is what the book
##                         inventory grid and chest UI drag/drop between.
##
## Public API (see each function's docstring):
##   - add_item(stack)        : merge or place a stack, returns leftover count.
##   - remove_item(id, n)     : remove n of an item id, returns removed count.
##   - get_item_index(id)     : find the first stack of an item id.
##   - count_of(id)           : total count of an item id across all stacks.
##   - move_slot(from, to)    : drag/drop reorder or merge within this inventory.
##   - transfer_to(other, from, to) : move a stack into another inventory.
##   - equip_tool(index)      : mark a tool slot as the equipped tool.
##
## Signals:
##   - slot_selected(index)        : a hotbar/tool slot was selected.
##   - inventory_changed()         : anything in the inventory changed.
##   - items_changed()             : the stack-based items list changed.
##
## Save/Load: get_save_data() serialises the items array so harvested crops and
## chest contents persist across sessions.
## ============================================================================

signal slot_selected(index: int)
signal inventory_changed()
signal items_changed()

## Maximum number of item slots (stack-based inventory). Tools/seeds are not
## counted against this limit.
@export var item_capacity: int = 24

var tool_inventory: Array[ToolData] = []
var seed_inventory: Array[CropData] = []
var items: Array[ItemStack] = []
var selected_slot: int = -1
var equipped_tool_index: int = -1
var _action_bar: Node = null

# ---------------------------------------------------------------------------
# ACTION-BAR / HOTBAR INTEGRATION (unchanged, kept for compatibility)
# ---------------------------------------------------------------------------
## Registers the action bar for visual updates and slot forwarding.
func setup_with_action_bar(action_bar_node: Node) -> void:
	_action_bar = action_bar_node
	if _action_bar and _action_bar.has_signal("tool_selected"):
		_action_bar.tool_selected.connect(_on_action_bar_selected)

func add_tool(tool: ToolData) -> void:
	tool_inventory.append(tool)
	inventory_changed.emit()

func add_seed(crop: CropData) -> void:
	seed_inventory.append(crop)
	inventory_changed.emit()

func select_slot(index: int) -> bool:
	var total: int = tool_inventory.size() + seed_inventory.size()
	if index < 0 or index >= total:
		return false
	if selected_slot == index:
		return true
	selected_slot = index
	# Auto-equip the tool if a tool slot was selected.
	if index < tool_inventory.size():
		equipped_tool_index = index
	slot_selected.emit(index)
	if _action_bar and _action_bar.has_method("select_slot"):
		_action_bar.select_slot(index)
	return true

func get_selected_tool() -> ToolData:
	if selected_slot < 0 or selected_slot >= tool_inventory.size():
		return null
	return tool_inventory[selected_slot]

func get_selected_seed() -> CropData:
	var tool_count: int = tool_inventory.size()
	var seed_idx: int = selected_slot - tool_count
	if seed_idx < 0 or seed_idx >= seed_inventory.size():
		return null
	return seed_inventory[seed_idx]

func is_tool_selected() -> bool:
	return selected_slot >= 0 and selected_slot < tool_inventory.size()

func is_seed_selected() -> bool:
	return selected_slot >= tool_inventory.size()

func get_total_slots() -> int:
	return tool_inventory.size() + seed_inventory.size()

## Updates action bar icons to match inventory contents.
func update_action_bar() -> void:
	if not _action_bar or not _action_bar.has_method("set_slot_texture"):
		return
	var idx: int = 0
	for tool: ToolData in tool_inventory:
		if tool.icon:
			_action_bar.set_slot_texture(idx, tool.icon)
		idx += 1
	for entry: CropData in seed_inventory:
		if entry.seed_sprite:
			_action_bar.set_slot_texture(idx, entry.seed_sprite)
		idx += 1

func _on_action_bar_selected(slot_index: int) -> void:
	selected_slot = slot_index
	slot_selected.emit(slot_index)

# ---------------------------------------------------------------------------
# STACK-BASED ITEM INVENTORY (harvested crops / pickups / chests / drag-drop)
# ---------------------------------------------------------------------------
## Adds an ItemStack to this inventory, merging into existing stacks of the
## same id when possible.  Returns the number of items that did NOT fit
## (0 = everything was stored).
func add_item(stack: ItemStack) -> int:
	if stack == null:
		return 0
	var leftover: int = stack.count
	# First, try to merge into existing stacks of the same id.
	if stack.stackable:
		for existing: ItemStack in items:
			if existing.same_type(stack) and existing.can_accept_more(1):
				leftover = existing.add(leftover)
				if leftover <= 0:
					items_changed.emit()
					inventory_changed.emit()
					return 0
	# Then place the remainder into empty slots as new stacks.
	while leftover > 0 and items.size() < item_capacity:
		var new_stack: ItemStack = ItemStack.new()
		new_stack.item_id = stack.item_id
		new_stack.item_name = stack.item_name
		new_stack.icon = stack.icon
		new_stack.max_stack = stack.max_stack
		new_stack.stackable = stack.stackable
		new_stack.crop_ref = stack.crop_ref
		new_stack.tool_ref = stack.tool_ref
		leftover = new_stack.add(leftover)
		items.append(new_stack)
	items_changed.emit()
	inventory_changed.emit()
	return leftover

## Removes up to `amount` items matching `item_id`.  Returns the count removed.
func remove_item(item_id: String, amount: int = 1) -> int:
	var removed: int = 0
	for i in range(items.size() - 1, -1, -1):
		var stack: ItemStack = items[i]
		if stack.item_id == item_id:
			removed += stack.remove(amount - removed)
			if stack.is_empty():
				items.remove_at(i)
			if removed >= amount:
				break
	if removed > 0:
		items_changed.emit()
		inventory_changed.emit()
	return removed

## Returns the total count of an item id across all stacks.
func count_of(item_id: String) -> int:
	var total: int = 0
	for stack: ItemStack in items:
		if stack.item_id == item_id:
			total += stack.count
	return total

## Returns the index of the first stack of an item id, or -1.
func get_item_index(item_id: String) -> int:
	for i in range(items.size()):
		if items[i].item_id == item_id:
			return i
	return -1

## Drag/drop reorder within this inventory: move the stack at `from` to `to`.
## If `to` holds a stack of the same stackable type they merge; otherwise swap.
func move_slot(from: int, to: int) -> void:
	if from == to:
		return
	if from < 0 or from >= items.size() or to < 0 or to >= item_capacity:
		return
	# Dropping onto an empty slot (to >= array size) = move to end of array.
	if to >= items.size():
		var stack: ItemStack = items[from]
		items.remove_at(from)
		items.append(stack)
		items_changed.emit()
		inventory_changed.emit()
		return
	var src: ItemStack = items[from]
	var dst: ItemStack = items[to]
	if dst != null and src != null and dst.same_type(src) and dst.stackable:
		# Merge src into dst; keep any leftover in src.
		var leftover: int = dst.add(src.count)
		if leftover <= 0:
			items.remove_at(from)
		else:
			src.count = leftover
	else:
		# Swap the two stacks.
		items[from] = dst
		items[to] = src
	items_changed.emit()
	inventory_changed.emit()

## Moves the stack at `from` in this inventory into `other` inventory.
## `to` is a hint slot index in the other inventory (may be -1 = auto-place).
## Returns true if something moved.  Used for player ↔ chest transfers.
func transfer_to(other: InventoryComponent, from: int, to: int) -> bool:
	if other == null or from < 0 or from >= items.size():
		return false
	var stack: ItemStack = items[from]
	if stack == null:
		return false
	# If target slot holds a same-type stackable stack, merge into it directly.
	if to >= 0 and to < other.items.size() and other.items[to] != null:
		var dst: ItemStack = other.items[to]
		if dst.same_type(stack) and dst.stackable:
			var leftover: int = dst.add(stack.count)
			if leftover <= 0:
				items.remove_at(from)
			else:
				stack.count = leftover
			other.items_changed.emit()
			other.inventory_changed.emit()
			items_changed.emit()
			inventory_changed.emit()
			return true
	# Otherwise add to the other inventory (merging where possible).
	var leftover_count: int = other.add_item(stack)
	if leftover_count <= 0:
		items.remove_at(from)
	else:
		stack.count = leftover_count
	items_changed.emit()
	inventory_changed.emit()
	return true

## Marks a tool slot as the equipped tool.
func equip_tool(index: int) -> void:
	if index >= 0 and index < tool_inventory.size():
		equipped_tool_index = index
		inventory_changed.emit()

## Returns the currently equipped ToolData, or null.
func get_equipped_tool() -> ToolData:
	if equipped_tool_index < 0 or equipped_tool_index >= tool_inventory.size():
		return null
	return tool_inventory[equipped_tool_index]

# ---------------------------------------------------------------------------
# SAVE / LOAD (stack-based items only; tools/seeds reload from starter load)
# ---------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var item_data: Array = []
	for stack: ItemStack in items:
		item_data.append({
			"id": stack.item_id,
			"name": stack.item_name,
			"count": stack.count,
			"max_stack": stack.max_stack,
			"stackable": stack.stackable,
		})
	return {
		"items": item_data,
		"capacity": item_capacity,
		"equipped_tool": equipped_tool_index,
	}

func load_from_save(data: Dictionary) -> void:
	items.clear()
	item_capacity = int(data.get("capacity", item_capacity))
	for entry: Dictionary in data.get("items", []):
		var stack: ItemStack = ItemStack.new()
		stack.item_id = entry["id"]
		stack.item_name = entry.get("name", stack.item_id)
		stack.count = int(entry.get("count", 1))
		stack.max_stack = int(entry.get("max_stack", 99))
		stack.stackable = bool(entry.get("stackable", true))
		items.append(stack)
	equipped_tool_index = int(data.get("equipped_tool", -1))
	items_changed.emit()
	inventory_changed.emit()
