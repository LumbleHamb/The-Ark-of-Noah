class_name BlacksmithShopComponent
extends Component

const ShopTradeListResourceClass: Script = preload("res://scripts/resources/shop/shop_trade_list_resource.gd")

## ============================================================================
## BLACKSMITH SHOP COMPONENT — Turn any NPC into a shop where the player can
## trade resources (ores, wood, gems) for items, tools, or seeds.
##
## Usage:
##   Drop this on a Node2D (the blacksmith NPC).  It builds an interaction
##   zone (Area2D) so the player can detect it.  When the player presses
##   interact while standing in the zone, the BlacksmithShopUI autoload
##   opens and displays all trades from the `trades` array.
##
## The player can then click any trade they can afford (costs are checked
## against the player's InventoryComponent).  On confirmation the costs are
## removed and the reward is added to the player's inventory (tools go to
## the action bar, seeds to the seed inventory, items to the item grid).
## ============================================================================

signal shop_opened()
signal shop_closed()
signal trade_completed(offer_id: String)

## Name shown at the top of the shop UI.
@export var shop_name: String = "Blacksmith"

## Array of ShopTradeResource offers.
@export var trades: Array[Resource] = []
@export var beginner_trade_list: Resource = preload("res://resources/shop/blacksmith_beginner_trades.tres")

## Interaction zone radius (pixels).
@export var interact_radius: float = 48.0

## Optional AnimatedSprite2D child for idle animation.
@export var idle_animation: String = "idle"

var _interact_area: Area2D = null
var _anim_sprite: AnimatedSprite2D = null
var _is_open: bool = false

func _component_ready() -> void:
	add_to_group(&"blacksmith_shop")
	if beginner_trade_list != null and trades.is_empty() and beginner_trade_list.get_script() == ShopTradeListResourceClass:
		var list_resource: ShopTradeListResource = beginner_trade_list as ShopTradeListResource
		if list_resource != null:
			trades = list_resource.trades.duplicate()
	_build_interact_zone()
	_anim_sprite = get_entity().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _anim_sprite and _anim_sprite.sprite_frames:
		if idle_animation != "" and _anim_sprite.sprite_frames.has_animation(idle_animation):
			_anim_sprite.play(idle_animation)


## Returns true if the player is standing in this shop's interaction zone.
func is_player_in_zone() -> bool:
	if _interact_area != null:
		for body: Node2D in _interact_area.get_overlapping_bodies():
			if body.is_in_group(&"player") or body.is_in_group(&"Player"):
				return true
	# Fallback: distance check.
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var player_node: Node2D = tree.get_first_node_in_group(&"Player") as Node2D
	if player_node == null:
		player_node = tree.get_first_node_in_group(&"player") as Node2D
	if player_node == null:
		return false
	return entity.global_position.distance_to(player_node.global_position) <= interact_radius * 2.0


## Opens the shop UI for the given player.
func open_for(_player: Node) -> void:
	if _is_open:
		return
	_is_open = true
	shop_opened.emit()


## Closes the shop.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	shop_closed.emit()


func is_open() -> bool:
	return _is_open


## Checks if the player can afford a given trade.
func can_afford(trade: ShopTradeResource, inventory: InventoryComponent) -> bool:
	if trade == null or inventory == null or trade.costs.is_empty():
		return false
	for cost_res: Resource in trade.costs:
		var cost: ShopCostResource = cost_res as ShopCostResource
		if cost == null:
			continue
		if inventory.count_of(cost.item_id) < cost.count:
			return false
	return true


## Executes a trade: consumes costs, gives reward.  Returns true on success.
func execute_trade(trade: ShopTradeResource, inventory: InventoryComponent) -> bool:
	if trade == null or inventory == null:
		return false
	if not can_afford(trade, inventory):
		return false
	# Consume costs.
	for cost_res: Resource in trade.costs:
		var cost: ShopCostResource = cost_res as ShopCostResource
		if cost == null:
			continue
		inventory.remove_item(cost.item_id, cost.count)
	# Give reward.
	if trade.rewards_item():
		# Use ItemRegistry for proper icon/name.
		var reg: Node = get_node_or_null("/root/ItemRegistry")
		var stack: ItemStack = null
		if reg and reg.has_method("create_stack"):
			stack = reg.create_stack(trade.reward_item_id, trade.reward_item_count)
		if stack == null:
			# Fallback: manual creation if not in registry.
			stack = ItemStack.new()
			stack.item_id = trade.reward_item_id
			stack.item_name = trade.reward_item_id.capitalize()
			stack.count = trade.reward_item_count
			stack.max_stack = 99
			stack.stackable = true
		var leftover: int = inventory.add_item(stack)
		if leftover > 0:
			# Refund costs if reward didn't fit.
			for cost_res: Resource in trade.costs:
				var cost: ShopCostResource = cost_res as ShopCostResource
				if cost == null:
					continue
				var reg2: Node = get_node_or_null("/root/ItemRegistry")
				var refund: ItemStack = null
				if reg2 and reg2.has_method("create_stack"):
					refund = reg2.create_stack(cost.item_id, cost.count)
				if refund == null:
					refund = ItemStack.new()
					refund.item_id = cost.item_id
					refund.item_name = cost.item_id.capitalize()
					refund.count = cost.count
					refund.max_stack = 99
					refund.stackable = true
				inventory.add_item(refund)
			return false
	elif trade.rewards_tool():
		var tool: ToolData = trade.reward_tool as ToolData
		if tool:
			inventory.add_tool(tool)
	elif trade.rewards_crop():
		var crop: CropData = trade.reward_crop as CropData
		if crop:
			inventory.add_seed(crop)
	trade_completed.emit(trade.offer_id)
	return true


func _build_interact_zone() -> void:
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return
	var existing: Area2D = entity.get_node_or_null("InteractZone") as Area2D
	if existing:
		_interact_area = existing
		return
	_interact_area = Area2D.new()
	_interact_area.name = "InteractZone"
	_interact_area.monitoring = true
	_interact_area.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	_interact_area.add_child(shape)
	entity.add_child.call_deferred(_interact_area)
