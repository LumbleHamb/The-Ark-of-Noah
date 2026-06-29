class_name BucketComponent
extends Component

signal bucket_state_changed(state_item_id: String)

const BUCKET_EMPTY_ID: String = "bucket_empty"
const BUCKET_PITCH_ID: String = "bucket_pitch"

@export var auto_grant_starter_bucket: bool = true

var _inventory: InventoryComponent = null

func _component_ready() -> void:
	_inventory = get_sibling_component_by_name("InventoryComponent") as InventoryComponent
	if _inventory == null:
		return
	if auto_grant_starter_bucket and _inventory.count_of(BUCKET_EMPTY_ID) <= 0 and _inventory.count_of(BUCKET_PITCH_ID) <= 0:
		_inventory.add_item(_make_stack(BUCKET_EMPTY_ID, "Empty Bucket", 1))
		bucket_state_changed.emit(BUCKET_EMPTY_ID)

func has_empty_bucket() -> bool:
	return _inventory != null and _inventory.count_of(BUCKET_EMPTY_ID) > 0

func has_pitch_bucket() -> bool:
	return _inventory != null and _inventory.count_of(BUCKET_PITCH_ID) > 0

func collect_pitch() -> bool:
	if _inventory == null:
		return false
	if _inventory.remove_item(BUCKET_EMPTY_ID, 1) <= 0:
		return false
	_inventory.add_item(_make_stack(BUCKET_PITCH_ID, "Bucket of Pitch", 1))
	bucket_state_changed.emit(BUCKET_PITCH_ID)
	return true

func deposit_pitch() -> bool:
	if _inventory == null:
		return false
	if _inventory.remove_item(BUCKET_PITCH_ID, 1) <= 0:
		return false
	_inventory.add_item(_make_stack(BUCKET_EMPTY_ID, "Empty Bucket", 1))
	bucket_state_changed.emit(BUCKET_EMPTY_ID)
	return true

func _make_stack(item_id: String, item_name: String, count: int) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.item_id = item_id
	stack.item_name = item_name
	stack.count = count
	stack.max_stack = 99
	stack.stackable = true
	return stack
