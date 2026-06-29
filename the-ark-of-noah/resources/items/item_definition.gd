class_name ItemDefinition
extends Resource

## ============================================================================
## ITEM DEFINITION RESOURCE
##
## Data-only item definition used by inventory/UI/save systems.
## Item stacks reference this resource indirectly by ID and optional references.
## ============================================================================

enum ItemCategory {
	RESOURCE,
	SEED,
	TOOL,
	FOOD,
	FLOWER,
	ORE,
	FISH,
	CRAFTING,
	QUEST,
	MISC,
}

@export var item_id: String = ""
@export var item_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var world_sprite: Texture2D = null
@export var weight: float = 0.0
@export var sell_value: int = 0
@export var category: ItemCategory = ItemCategory.MISC
@export var can_equip: bool = false
@export var tool_type: String = ""
@export var consumable: bool = false
@export var quest_item: bool = false
@export var max_stack_size: int = 1

## Creates an ItemStack from this definition, with icon, name, etc. pre-filled.
func create_stack(amount: int = 1) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.item_id = item_id
	stack.item_name = item_name
	stack.icon = icon
	stack.count = clampi(amount, 1, max_stack_size)
	stack.max_stack = max_stack_size
	stack.stackable = max_stack_size > 1
	return stack
