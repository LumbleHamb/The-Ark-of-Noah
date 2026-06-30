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
@export var item_capacity: int = 48
@export_range(2, 16, 1) var hotbar_slot_count: int = 8
@export var fixed_slot_mode: bool = false

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
	var tool_count: int = tool_inventory.size()
	var total: int = tool_count + seed_inventory.size()
	return selected_slot >= tool_count and selected_slot < total

## Compatibility helper: in this project, selecting a seed slot represents
## having the seed pouch equipped/active.
func is_seed_pouch_equipped() -> bool:
	return is_seed_selected()

func get_total_slots() -> int:
	return tool_inventory.size() + seed_inventory.size()

func get_hotbar_slot_count() -> int:
	return hotbar_slot_count

func get_hotbar_texture(slot_index: int) -> Texture2D:
	if slot_index < 0 or slot_index >= hotbar_slot_count:
		return null
	if slot_index < tool_inventory.size():
		var tool: ToolData = tool_inventory[slot_index]
		return tool.icon if tool != null else null
	var seed_index: int = slot_index - tool_inventory.size()
	if seed_index >= 0 and seed_index < seed_inventory.size():
		var crop: CropData = seed_inventory[seed_index]
		return crop.seed_sprite if crop != null else null
	return null

func get_hotbar_slot_label(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= hotbar_slot_count:
		return ""
	if slot_index < tool_inventory.size():
		var tool: ToolData = tool_inventory[slot_index]
		return tool.tool_name if tool != null else ""
	var seed_index: int = slot_index - tool_inventory.size()
	if seed_index >= 0 and seed_index < seed_inventory.size():
		var crop: CropData = seed_inventory[seed_index]
		return crop.crop_name if crop != null else ""
	return ""

## Updates action bar icons to match inventory contents.
func update_action_bar() -> void:
	if _action_bar == null:
		return
	if not _action_bar.has_method("set_slot_texture"):
		return
	for idx: int in range(hotbar_slot_count):
		if _action_bar.has_method("clear_slot_texture"):
			_action_bar.clear_slot_texture(idx)
		var tex: Texture2D = get_hotbar_texture(idx)
		if tex != null:
			_action_bar.set_slot_texture(idx, tex)

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
		if stack.stackable:
			leftover = new_stack.add(leftover)
		else:
			# Non-stackable items each fill exactly one slot.
			new_stack.count = 1
			leftover -= 1
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
	if fixed_slot_mode:
		if to >= items.size():
			items.resize(item_capacity)
		var src_fixed: ItemStack = items[from]
		if src_fixed == null:
			return
		var dst_fixed: ItemStack = items[to]
		if dst_fixed != null and dst_fixed.same_type(src_fixed) and dst_fixed.stackable:
			var fixed_leftover: int = dst_fixed.add(src_fixed.count)
			if fixed_leftover <= 0:
				items[from] = null
			else:
				src_fixed.count = fixed_leftover
		else:
			items[from] = dst_fixed
			items[to] = src_fixed
		items_changed.emit()
		inventory_changed.emit()
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
	if fixed_slot_mode and from >= items.size():
		return false
	var stack: ItemStack = items[from]
	if stack == null:
		return false
	# If a specific target slot was given, try to place it there.
	if to >= 0 and to < other.item_capacity:
		if other.fixed_slot_mode and other.items.size() < other.item_capacity:
			other.items.resize(other.item_capacity)
		# Target slot is within bounds — check what's in it.
		if to < other.items.size() and other.items[to] != null:
			var dst: ItemStack = other.items[to]
			if dst.same_type(stack) and dst.stackable:
				# Merge same-type stackable items.
				var leftover: int = dst.add(stack.count)
				if leftover <= 0:
					if fixed_slot_mode:
						items[from] = null
					else:
						items.remove_at(from)
				else:
					stack.count = leftover
				other.items_changed.emit()
				other.inventory_changed.emit()
				items_changed.emit()
				inventory_changed.emit()
				return true
			else:
				# Slot has a different item — swap them.
				other.items[to] = stack
				items[from] = dst
				items_changed.emit()
				inventory_changed.emit()
				other.items_changed.emit()
				other.inventory_changed.emit()
				return true
		else:
			# Target slot is empty — place the item directly.
			if to >= other.items.size():
				# Pad the array if needed.
				other.items.resize(to + 1)
			other.items[to] = stack
			if fixed_slot_mode:
				items[from] = null
			else:
				items.remove_at(from)
			items_changed.emit()
			inventory_changed.emit()
			other.items_changed.emit()
			other.inventory_changed.emit()
			return true
	# No specific target slot (or out of range): auto-place via add_item.
	var leftover_count: int = other.add_item(stack)
	if leftover_count <= 0:
		if fixed_slot_mode:
			items[from] = null
		else:
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
	var item_data: Array[Dictionary] = []
	for stack: ItemStack in items:
		item_data.append({
			"id": stack.item_id,
			"name": stack.item_name,
			"count": stack.count,
			"max_stack": stack.max_stack,
			"stackable": stack.stackable,
		})
	var tool_paths: Array[String] = []
	for tool: ToolData in tool_inventory:
		tool_paths.append(tool.resource_path if tool != null else "")
	var seed_paths: Array[String] = []
	for crop: CropData in seed_inventory:
		seed_paths.append(crop.resource_path if crop != null else "")
	return {
		"items": item_data,
		"capacity": item_capacity,
		"equipped_tool": equipped_tool_index,
		"selected_slot": selected_slot,
		"tools": tool_paths,
		"seeds": seed_paths,
	}

func load_from_save(data: Dictionary) -> void:
	items.clear()
	tool_inventory.clear()
	seed_inventory.clear()
	item_capacity = int(data.get("capacity", item_capacity))
	var raw_items: Array = data.get("items", []) as Array
	for entry_variant: Variant in raw_items:
		var entry: Dictionary = entry_variant as Dictionary
		var stack: ItemStack = ItemStack.new()
		stack.item_id = String(entry.get("id", ""))
		stack.item_name = String(entry.get("name", stack.item_id))
		stack.count = int(entry.get("count", 1))
		stack.max_stack = int(entry.get("max_stack", 1))
		stack.stackable = bool(entry.get("stackable", false))
		items.append(stack)
	var tool_paths_raw: Array = data.get("tools", []) as Array
	for path_variant: Variant in tool_paths_raw:
		var tool_path: String = String(path_variant)
		if tool_path == "":
			continue
		var tool_res: ToolData = ResourceLoader.load(tool_path) as ToolData
		if tool_res != null:
			tool_inventory.append(tool_res)
	var seed_paths_raw: Array = data.get("seeds", []) as Array
	for path_variant: Variant in seed_paths_raw:
		var seed_path: String = String(path_variant)
		if seed_path == "":
			continue
		var crop_res: CropData = ResourceLoader.load(seed_path) as CropData
		if crop_res != null:
			seed_inventory.append(crop_res)
	equipped_tool_index = int(data.get("equipped_tool", -1))
	selected_slot = int(data.get("selected_slot", -1))
	if selected_slot >= get_total_slots():
		selected_slot = -1
	update_action_bar()
	items_changed.emit()
	inventory_changed.emit()
