class_name ResourceCollectorComponent
extends Component

signal resource_collected(resource_id: String, amount: int)

@export var source_resource_id: String = "pitch"
@export var required_container_item_id: String = "bucket_empty"
@export var produced_item_id: String = "bucket_pitch"
@export var produce_amount: int = 1
@export var interact_radius: float = 40.0

var _interact_area: Area2D = null

func _component_ready() -> void:
	add_to_group(&"resource_collector")
	_build_interact_zone()

func is_player_in_zone() -> bool:
	if _interact_area == null:
		return false
	for body: Node2D in _interact_area.get_overlapping_bodies():
		if body.is_in_group(&"player") or body.is_in_group(&"Player"):
			return true
	return false

func collect_into(inventory: InventoryComponent) -> int:
	if inventory == null:
		return 0
	if inventory.remove_item(required_container_item_id, 1) <= 0:
		return 0
	var produced_stack: ItemStack = ItemStack.new()
	produced_stack.item_id = produced_item_id
	produced_stack.item_name = produced_item_id.capitalize()
	produced_stack.count = produce_amount
	produced_stack.max_stack = 1
	produced_stack.stackable = false
	var leftover: int = inventory.add_item(produced_stack)
	if leftover > 0:
		# Rollback container consumption if produced item did not fit.
		var container_stack: ItemStack = ItemStack.new()
		container_stack.item_id = required_container_item_id
		container_stack.item_name = required_container_item_id.capitalize()
		container_stack.count = 1
		container_stack.max_stack = 1
		container_stack.stackable = false
		inventory.add_item(container_stack)
		return 0
	resource_collected.emit(source_resource_id, produce_amount)
	return produce_amount

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
