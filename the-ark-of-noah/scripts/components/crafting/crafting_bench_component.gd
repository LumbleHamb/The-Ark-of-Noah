class_name CraftingBenchComponent
extends Component

signal crafted(recipe_id: String)

@export var bench_name: String = "Crafting Bench"
@export var recipes: Array[Resource] = []
@export var interact_radius: float = 48.0

var _interact_area: Area2D = null

func _component_ready() -> void:
	add_to_group(&"crafting_bench")
	_build_interact_zone()

func is_player_in_zone() -> bool:
	if _interact_area == null:
		return false
	for body: Node2D in _interact_area.get_overlapping_bodies():
		if body.is_in_group(&"player") or body.is_in_group(&"Player"):
			return true
	return false

func craft_first_available(inventory: InventoryComponent) -> bool:
	for recipe: Resource in recipes:
		if recipe != null and can_craft(recipe, inventory):
			return craft(recipe.recipe_id, inventory)
	return false

func can_craft(recipe: Resource, inventory: InventoryComponent) -> bool:
	if recipe == null or inventory == null:
		return false
	for ingredient: Resource in recipe.ingredients:
		if ingredient == null:
			continue
		if inventory.count_of(ingredient.item_id) < ingredient.count:
			return false
	return true

func craft(recipe_id: String, inventory: InventoryComponent) -> bool:
	if inventory == null:
		return false
	var recipe: Resource = _find_recipe(recipe_id)
	if recipe == null:
		return false
	if not can_craft(recipe, inventory):
		return false
	for ingredient: Resource in recipe.ingredients:
		if ingredient != null:
			inventory.remove_item(ingredient.item_id, ingredient.count)
	for output: Resource in recipe.outputs:
		if output == null:
			continue
		var stack: ItemStack = ItemStack.new()
		stack.item_id = output.item_id
		stack.item_name = output.item_id.capitalize()
		stack.count = output.count
		stack.max_stack = 99
		stack.stackable = true
		inventory.add_item(stack)
	crafted.emit(recipe.recipe_id)
	return true

func _find_recipe(recipe_id: String) -> Resource:
	for recipe: Resource in recipes:
		if recipe != null and recipe.recipe_id == recipe_id:
			return recipe
	return null

func _build_interact_zone() -> void:
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return
	_interact_area = entity.get_node_or_null("InteractZone") as Area2D
	if _interact_area != null:
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
