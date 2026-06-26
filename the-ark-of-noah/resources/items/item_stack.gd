class_name ItemStack
extends Resource

## ============================================================================
## ITEM STACK — A stackable pile of one item type.
##
## This is the common currency shared by every inventory in the game:
##   - The player's InventoryComponent (tools, seeds, harvested crops, pickups).
##   - The ChestComponent's storage.
##   - Harvest pickups that fly into the player's inventory.
##
## An ItemStack holds:
##   - item_id   : a stable string id (e.g. "carrot", "hoes_starter").
##   - item_name : human-readable name for tooltips / UI.
##   - icon      : the Texture2D shown in the slot.
##   - count     : how many are in this stack (>= 1).
##   - max_stack : the largest a single stack can grow (1 = unstackable, e.g. tools).
##   - stackable : if false, each item occupies its own slot (tools, equipment).
##   - crop_ref  : optional CropData, if this stack represents a harvested crop.
##   - tool_ref  : optional ToolData, if this stack represents a tool.
##
## Create one with ItemStack.create(...) or new() and set the fields.  Save it
## inside an InventoryComponent / ChestComponent (those own arrays of stacks).
## ============================================================================

@export var item_id: String = ""
@export var item_name: String = "Item"
@export var icon: Texture2D = null
@export var count: int = 1
@export var max_stack: int = 99
@export var stackable: bool = true
@export var crop_ref: CropData = null
@export var tool_ref: ToolData = null

## Quick constructor for code that builds stacks inline.
static func create(id: String, display_name: String, icon_texture: Texture2D, amount: int = 1, maximum_stack: int = 99, is_stackable: bool = true) -> Resource:
	var stack = ItemStack.new()
	stack.item_id = id
	stack.item_name = display_name
	stack.icon = icon_texture
	stack.count = maxi(1, amount)
	stack.max_stack = maxi(1, maximum_stack)
	stack.stackable = is_stackable
	return stack

## Returns true if this stack can accept more of the same item.
func can_accept_more(amount: int) -> bool:
	if not stackable:
		return false
	return count + amount <= max_stack

## Returns the number of items from `amount` that could not fit into this stack.
func add(amount: int) -> int:
	if not stackable:
		return amount
	var room: int = max_stack - count
	var taken: int = mini(amount, room)
	count += taken
	return amount - taken

## Removes up to `amount` items.  Returns the number actually removed.
func remove(amount: int) -> int:
	var taken: int = mini(amount, count)
	count -= taken
	return taken

func is_empty() -> bool:
	return count <= 0

## Returns true if two stacks refer to the same item type (so they can merge).
func same_type(other: Resource) -> bool:
	return other != null and other.item_id == item_id
