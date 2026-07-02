class_name DevMenuInventory
extends InventoryComponent

## ============================================================================
## DEV MENU INVENTORY — Special inventory used by the developer item palette.
##
## Unlike a normal InventoryComponent, this one COPIES items when they are
## dragged to another inventory instead of moving them.  This makes the dev
## menu act as an infinite item source — items never run out.
##
## The inventory is populated from the ItemRegistry, with one slot per
## registered item at max stack size.
## ============================================================================

func _ready() -> void:
	_populate_from_registry()


## Fills the inventory with one stack of every item from the registry.
func _populate_from_registry() -> void:
	items.clear()
	var registry: Node = _find_registry()
	print("DevMenuInventory: _find_registry returned ", registry)
	if registry == null or not registry.has_method(&"get_all_definitions"):
		push_warning("DevMenuInventory: ItemRegistry not found")
		return
	var definitions: Array = registry.get_all_definitions()
	print("DevMenuInventory: got ", definitions.size(), " definitions from registry")
	for def_raw: Variant in definitions:
		var def: ItemDefinition = def_raw as ItemDefinition
		if def == null or def.item_id == "":
			continue
		var stack: ItemStack = def.create_stack(def.max_stack_size)
		items.append(stack)
	item_capacity = maxi(item_capacity, items.size())
	print("DevMenuInventory: populated ", items.size(), " items, capacity=", item_capacity)
	items_changed.emit()
	inventory_changed.emit()


## Resets the dev menu to show all items again (useful after assets reload).
func refresh_items() -> void:
	_populate_from_registry()


## Override: Instead of moving the item out, COPY it to the target inventory.
## The dev menu stack stays in place so it can be used as an infinite source.
func transfer_to(other: InventoryComponent, from: int, to: int) -> bool:
	if other == null or from < 0 or from >= items.size():
		return false
	var stack: ItemStack = items[from]
	if stack == null:
		return false

	# Build a fresh copy of the stack from the definition so it has a proper
	# icon, name, etc.
	var copy: ItemStack = _build_copy(stack)
	if copy == null:
		return false

	# If a specific target slot was given, try to place it there.
	if to >= 0 and to < other.item_capacity:
		if to < other.items.size() and other.items[to] != null:
			var dst: ItemStack = other.items[to]
			if dst.same_type(copy) and dst.stackable:
				# Merge same-type stackable items.
				var leftover: int = dst.add(copy.count)
				if leftover > 0:
					copy.count = leftover
					other.add_item(copy)
			else:
				# Slot has a different item — swap won't work cleanly here
				# since we don't want to take items back. Just add via auto-place.
				other.add_item(copy)
		else:
			# Target slot is empty — place directly.
			if to >= other.items.size():
				other.items.resize(to + 1)
			other.items[to] = copy
	else:
		# No specific target slot: auto-place via add_item.
		other.add_item(copy)

	other.items_changed.emit()
	other.inventory_changed.emit()
	# Don't emit items_changed on ourselves — nothing actually changed here.
	return true


## Builds an ItemStack copy from the definition, preserving count.
func _build_copy(stack: ItemStack) -> ItemStack:
	var registry: Node = _find_registry()
	if registry != null and registry.has_method(&"create_stack"):
		var fresh: ItemStack = registry.call("create_stack", stack.item_id, stack.count)
		if fresh != null:
			return fresh
	# Fallback: manual copy
	var copy: ItemStack = ItemStack.new()
	copy.item_id = stack.item_id
	copy.item_name = stack.item_name
	copy.icon = stack.icon
	copy.count = stack.count
	copy.max_stack = stack.max_stack
	copy.stackable = stack.stackable
	copy.crop_ref = stack.crop_ref
	copy.tool_ref = stack.tool_ref
	return copy


func _find_registry() -> Node:
	# Try multiple methods to find the ItemRegistry autoload.
	
	# Method 1: Direct singleton lookup (plain String, not StringName).
	var reg: Node = Engine.get_singleton("ItemRegistry")
	if reg != null:
		return reg
	
	# Method 2: StringName variant.
	reg = Engine.get_singleton(&"ItemRegistry")
	if reg != null:
		return reg
	
	# Method 3: Search the scene tree root for an ItemRegistry child node.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		for child: Node in tree.root.get_children():
			if child.name == "ItemRegistry":
				return child
	
	return null
