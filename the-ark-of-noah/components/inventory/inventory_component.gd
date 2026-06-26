class_name InventoryComponent
extends Component

## Generic inventory for tools, seeds, and items.
## Manages slot selection and integrates with the ActionBar UI.

signal slot_selected(index: int)
signal inventory_changed()

var tool_inventory: Array[ToolData] = []
var seed_inventory: Array[CropData] = []
var selected_slot: int = -1
var _action_bar: Node = null

## Registers the action bar for visual updates and slot forwarding.
func setup_with_action_bar(action_bar_node: Node) -> void:
	_action_bar = action_bar_node
	if _action_bar and _action_bar.has_signal("tool_selected"):
		_action_bar.tool_selected.connect(_on_action_bar_selected)

## Adds a tool and emits inventory_changed.
func add_tool(tool: ToolData) -> void:
	tool_inventory.append(tool)
	inventory_changed.emit()

## Adds a seed crop and emits inventory_changed.
func add_seed(crop: CropData) -> void:
	seed_inventory.append(crop)
	inventory_changed.emit()

## Selects a slot by index. Returns true if the slot was valid.
func select_slot(index: int) -> bool:
	var total: int = tool_inventory.size() + seed_inventory.size()
	if index < 0 or index >= total:
		return false
	if selected_slot == index:
		return true
	selected_slot = index
	slot_selected.emit(index)
	if _action_bar and _action_bar.has_method("select_slot"):
		_action_bar.select_slot(index)
	return true

## Returns the ToolData for the selected tool slot, or null.
func get_selected_tool() -> ToolData:
	if selected_slot < 0 or selected_slot >= tool_inventory.size():
		return null
	return tool_inventory[selected_slot]

## Returns the CropData for the selected seed slot, or null.
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

## Returns total number of tool + seed slots.
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
