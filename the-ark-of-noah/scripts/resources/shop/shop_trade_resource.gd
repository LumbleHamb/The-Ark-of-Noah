class_name ShopTradeResource
extends Resource

## ============================================================================
## SHOP TRADE — A single trade offer shown in the blacksmith's shop.
##
## Each trade has:
##   - costs[] : items that are consumed from the player's inventory.
##   - One of three reward types:
##       reward_item_id  (for ItemStack items like ingots, keys, gems)
##       reward_tool     (for ToolData tools like axes, pickaxes)
##       reward_crop     (for CropData seeds)
##
## The shop UI shows all available trades and lets the player click one.
## ============================================================================

@export var offer_id: String = ""
@export var offer_name: String = "Trade"
@export_multiline var description: String = ""
@export var costs: Array[Resource] = []

## Reward: item (uses ItemRegistry to create an ItemStack with icon/name).
@export var reward_item_id: String = ""
@export var reward_item_count: int = 1

## Reward: tool (adds to the player's action bar).
@export var reward_tool: Resource = null

## Reward: seed (adds to the player's seed inventory).
@export var reward_crop: Resource = null


## Returns true if this trade rewards an item (vs tool or seed).
func rewards_item() -> bool:
	return reward_item_id != ""


## Returns true if this trade rewards a tool.
func rewards_tool() -> bool:
	return reward_tool != null and reward_tool is ToolData


## Returns true if this trade rewards a seed/crop.
func rewards_crop() -> bool:
	return reward_crop != null and reward_crop is CropData


## Returns a human-readable summary of the reward.
func get_reward_summary() -> String:
	if rewards_item():
		var reg: Node = ItemRegistry
		if reg and reg.has_method("get_item"):
			var def: ItemDefinition = reg.get_item(reward_item_id)
			if def:
				return def.item_name + ((" x%d" % reward_item_count) if reward_item_count > 1 else "")
		return reward_item_id.capitalize()
	if rewards_tool():
		var tool: ToolData = reward_tool as ToolData
		return tool.tool_name if tool.tool_name != "" else "Tool"
	if rewards_crop():
		var crop: CropData = reward_crop as CropData
		return crop.crop_name + " Seeds" if crop.crop_name != "" else "Seeds"
	return "Unknown"
