class_name FarmingComponent
extends Component

## Player farming actions: tilling, planting, and harvesting.
## Works with InventoryComponent and FarmManager.

signal farming_action_performed(action: String, tile_pos: Vector2i)

@export var cooldown_time: float = 0.4

var farm_manager: FarmManager = null
var inventory: InventoryComponent = null
var _cooldown: float = 0.0

## Sets up references to the farm manager and player inventory.
func setup(farm_mgr: FarmManager, inv: InventoryComponent) -> void:
	farm_manager = farm_mgr
	inventory = inv

## Advances the action cooldown timer by delta seconds.
func process_cooldown(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func is_on_cooldown() -> bool:
	return _cooldown > 0.0

## Performs a farming action (till or plant) based on the selected slot.
## Returns true if an action was performed.
func do_farming_action(entity_pos: Vector2, last_dir: Vector2) -> bool:
	if _cooldown > 0.0 or farm_manager == null:
		return false
	var target_tile: Vector2i = _get_target_tile(entity_pos, last_dir)
	if inventory and inventory.is_tool_selected():
		var tool: ToolData = inventory.get_selected_tool()
		if tool and tool.tool_type == ToolData.ToolType.HOE:
			if farm_manager.till_tile(target_tile):
				_cooldown = cooldown_time
				farming_action_performed.emit("till", target_tile)
				return true
		return false
	elif inventory and inventory.is_seed_selected():
		return _plant_seed(target_tile)
	return false

## Attempts to harvest at the targeted tile. Returns true if successful.
func try_harvest(entity_pos: Vector2, last_dir: Vector2) -> bool:
	if farm_manager == null or _cooldown > 0.0:
		return false
	var target_tile: Vector2i = _get_target_tile(entity_pos, last_dir)
	var yield_count: int = farm_manager.harvest_tile(target_tile)
	if yield_count > 0:
		_cooldown = cooldown_time
		farming_action_performed.emit("harvest", target_tile)
		return true
	return false

func _plant_seed(tile_pos: Vector2i) -> bool:
	if farm_manager == null or inventory == null:
		return false
	var crop: CropData = inventory.get_selected_seed()
	if not crop:
		return false
	if farm_manager.is_grass_tile(tile_pos) and not farm_manager.get_tile_data(tile_pos)["tilled"]:
		farm_manager.till_tile(tile_pos)
	var planted: bool = false
	var crop_name_key: String = crop.crop_name.to_lower().replace(" ", "_")
	for crop_id in farm_manager.crop_registry.keys():
		if farm_manager.crop_registry[crop_id] == crop:
			if farm_manager.plant_crop(tile_pos, crop_id):
				planted = true
			break
	if not planted and farm_manager.crop_registry.has(crop_name_key):
		if farm_manager.plant_crop(tile_pos, crop_name_key):
			planted = true
	if planted:
		_cooldown = cooldown_time
		farming_action_performed.emit("plant", tile_pos)
	return planted

func _get_target_tile(entity_pos: Vector2, last_dir: Vector2) -> Vector2i:
	var offset: Vector2 = last_dir * 32.0
	var world_pos: Vector2 = entity_pos + offset
	if farm_manager:
		return farm_manager.get_tile_pos(world_pos)
	return Vector2i(floori(world_pos.x / 32), floori(world_pos.y / 32))
