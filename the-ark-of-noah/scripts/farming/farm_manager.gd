class_name FarmManager
extends Node2D

## Core farming manager.
##
## Handles tile-state persistence, tilling, planting, growth, and harvesting.
## This rewrite keeps compatibility with existing player/inventory/save systems
## while enforcing stricter farming rules.

const CropDataClass: Script = preload("res://scripts/farming/crop_data.gd")
const CropGrowthMathClass: Script = preload("res://scripts/farming/crop_growth_component.gd")

signal tile_tilled(tile_pos: Vector2i)
signal crop_planted(tile_pos: Vector2i, crop_name: String)
signal crop_grew(tile_pos: Vector2i, stage: int)
signal crop_harvestable(tile_pos: Vector2i, crop_name: String)
signal crop_harvested(tile_pos: Vector2i, crop_name: String, yield_count: int)

@export var tile_size: int = 32
@export var map_node_name: StringName = &"map"
@export var grass_layer_names: Array[StringName] = [&"Grass", &"grass", &"Ground", &"ground"]
@export var tilled_layer_names: Array[StringName] = [&"TilledSoil", &"garden"]
@export var meadows_layer_names: Array[StringName] = [&"Meadows"]

@onready var crop_container: Node2D = $Crops

var grass_layer: TileMapLayer = null
var tilled_layer: TileMapLayer = null
var meadows_layer: TileMapLayer = null
var time_manager: TimeManager = null
var growth_component: Node = null

var _tiles: Dictionary[Vector2i, Dictionary] = {}
var _crop_sprites: Dictionary[Vector2i, Sprite2D] = {}
var _harvest_indicators: Dictionary[Vector2i, Label] = {}
var _last_checked_day: int = -1
var crop_registry: Dictionary[String, CropData] = {}
var seed_to_crop: Dictionary[String, String] = {}
var _map_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group(&"farm_manager")
	_find_map_layers()
	_load_crop_registry()
	_find_time_manager()
	_setup_growth_component()

func _setup_growth_component() -> void:
	growth_component = get_node_or_null("CropGrowthMath") as Node
	if growth_component == null:
		growth_component = CropGrowthMathClass.new() as Node
		growth_component.name = "CropGrowthMath"
		add_child(growth_component)

func _find_time_manager() -> void:
	time_manager = get_tree().get_first_node_in_group(&"time_manager") as TimeManager
	if time_manager != null and not time_manager.time_tick.is_connected(_on_time_tick):
		time_manager.time_tick.connect(_on_time_tick)
		_last_checked_day = time_manager.current_day

func _on_time_tick(_hour: int, _minute: int, day: int) -> void:
	if day != _last_checked_day:
		_last_checked_day = day
		_on_day_change(day)

func _on_day_change(day: int) -> void:
	_process_daily_growth(day)
	_process_soil_reversion(day)

func _find_map_layers() -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var map_node: Node = world.get_node_or_null(NodePath(String(map_node_name)))
	if map_node == null:
		push_warning("FarmManager: map node not found")
		return
	grass_layer = _find_first_layer(map_node, grass_layer_names)
	tilled_layer = _find_first_layer(map_node, tilled_layer_names)
	meadows_layer = _find_first_layer(map_node, meadows_layer_names)
	if map_node is Node2D:
		_map_offset = (map_node as Node2D).position
	if grass_layer == null:
		push_warning("FarmManager: grass layer not found")
	if tilled_layer == null:
		push_warning("FarmManager: tilled soil layer not found")
	if meadows_layer == null:
		push_warning("FarmManager: meadows mask layer not found; tilling will fallback to grass-only check")

func _find_first_layer(root: Node, names: Array[StringName]) -> TileMapLayer:
	for layer_name: StringName in names:
		var direct_node: Node = root.get_node_or_null(NodePath(String(layer_name)))
		if direct_node is TileMapLayer:
			return direct_node as TileMapLayer
		var recursive_node: Node = root.find_child(String(layer_name), true, false)
		if recursive_node is TileMapLayer:
			return recursive_node as TileMapLayer
	return null

func is_grass_tile(tile_pos: Vector2i) -> bool:
	if grass_layer == null:
		return false
	return grass_layer.get_cell_source_id(tile_pos) != -1

func is_meadows_tile(tile_pos: Vector2i) -> bool:
	if meadows_layer == null:
		# Backward compatible fallback for old maps.
		return is_grass_tile(tile_pos)
	return meadows_layer.get_cell_source_id(tile_pos) != -1

func is_tillable(tile_pos: Vector2i) -> bool:
	if not is_meadows_tile(tile_pos):
		return false
	if not is_grass_tile(tile_pos):
		return false
	var tile_data: Dictionary = get_tile_data(tile_pos)
	return not bool(tile_data.get("tilled", false))

func till_tile(tile_pos: Vector2i) -> bool:
	if not is_tillable(tile_pos):
		return false
	if tilled_layer == null:
		return false
	var tile_data: Dictionary = get_tile_data(tile_pos)
	tile_data["tilled"] = true
	tile_data["tilled_at_day"] = time_manager.current_day if time_manager != null else 0
	tilled_layer.set_cells_terrain_connect([tile_pos], 0, 0, false)
	tile_tilled.emit(tile_pos)
	return true

func clear_soil_tile(tile_pos: Vector2i) -> void:
	if tilled_layer == null:
		return
	tilled_layer.set_cell(tile_pos, -1)

func _load_crop_registry() -> void:
	var crop_dir: String = "res://resources/crops/"
	var dir: DirAccess = DirAccess.open(crop_dir)
	if dir == null:
		push_warning("FarmManager: no crop resources at %s" % crop_dir)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var path: String = crop_dir.path_join(file_name)
			var crop_resource: Resource = ResourceLoader.load(path)
			if crop_resource is CropData:
				var crop: CropData = crop_resource as CropData
				var crop_id: String = crop.crop_name.to_lower().replace(" ", "_")
				crop_registry[crop_id] = crop
				seed_to_crop[crop_id] = crop_id
		file_name = dir.get_next()
	dir.list_dir_end()
	print("FarmManager: loaded %d crops" % crop_registry.size())

func get_tile_data(tile_pos: Vector2i) -> Dictionary:
	if not _tiles.has(tile_pos):
		_tiles[tile_pos] = {
			"tilled": false,
			"tilled_at_day": -1,
			"crop_id": "",
			"crop": null,
			"planted_at_day": -1,
			"growth_stage": 0,
			"harvestable": false,
			"regrow_count": 0,
		}
	return _tiles[tile_pos]

func is_plantable(tile_pos: Vector2i) -> bool:
	var tile_data: Dictionary = get_tile_data(tile_pos)
	return bool(tile_data.get("tilled", false)) and tile_data.get("crop") == null

func is_harvestable(tile_pos: Vector2i) -> bool:
	var tile_data: Dictionary = get_tile_data(tile_pos)
	return bool(tile_data.get("harvestable", false))

func plant_crop(tile_pos: Vector2i, crop_id: String) -> bool:
	if not is_plantable(tile_pos):
		return false
	var crop: CropData = crop_registry.get(crop_id)
	if crop == null:
		push_warning("FarmManager: unknown crop '%s'" % crop_id)
		return false
	var tile_data: Dictionary = get_tile_data(tile_pos)
	tile_data["crop"] = crop
	tile_data["crop_id"] = crop_id
	tile_data["planted_at_day"] = time_manager.current_day if time_manager != null else 0
	tile_data["growth_stage"] = 0
	tile_data["harvestable"] = false
	tile_data["regrow_count"] = 0
	_remove_harvest_indicator(tile_pos)
	_create_crop_sprite(tile_pos, crop.get_stage_sprite(0))
	crop_planted.emit(tile_pos, crop.crop_name)
	return true

func harvest_tile(tile_pos: Vector2i) -> int:
	if not is_harvestable(tile_pos):
		return 0
	var tile_data: Dictionary = get_tile_data(tile_pos)
	var crop: CropData = tile_data.get("crop") as CropData
	if crop == null:
		return 0
	var yield_count: int = crop.get_harvest_amount()
	var crop_name: String = crop.crop_name
	if crop.regrowable:
		tile_data["planted_at_day"] = time_manager.current_day if time_manager != null else 0
		tile_data["growth_stage"] = maxi(0, crop.growth_stages - 2)
		tile_data["harvestable"] = false
		tile_data["regrow_count"] = int(tile_data.get("regrow_count", 0)) + 1
		_remove_harvest_indicator(tile_pos)
		_update_crop_sprite(tile_pos, crop.get_stage_sprite(int(tile_data["growth_stage"])))
	else:
		_remove_harvest_indicator(tile_pos)
		_remove_crop_sprite(tile_pos)
		tile_data["crop"] = null
		tile_data["crop_id"] = ""
		tile_data["planted_at_day"] = -1
		tile_data["growth_stage"] = 0
		tile_data["harvestable"] = false
		clear_soil_tile(tile_pos)
		tile_data["tilled"] = false
		tile_data["tilled_at_day"] = -1
	_spawn_harvest_pickup(crop, tile_pos, yield_count)
	crop_harvested.emit(tile_pos, crop_name, yield_count)
	return yield_count

func _spawn_harvest_pickup(crop: CropData, tile_pos: Vector2i, yield_count: int) -> void:
	if crop == null or yield_count <= 0:
		return
	var item_id: String = crop.get_harvest_item_id()
	var display_name: String = crop.get_harvest_display_name()
	# Prefer explicit harvest icon, but force fallback to mature stage sprite
	# if the icon points to a crate/box style texture.
	var world_texture: Texture2D = crop.get_harvest_icon()
	var lower_name: String = String(world_texture.resource_path if world_texture != null else "").to_lower()
	if world_texture == null or lower_name.contains("crate") or lower_name.contains("box"):
		world_texture = crop.get_stage_sprite(crop.get_growth_stage_count() - 1)
	var stack: ItemStack = ItemStack.new()
	stack.item_id = item_id
	stack.item_name = display_name
	stack.icon = world_texture
	stack.count = yield_count
	stack.max_stack = 99
	stack.stackable = true
	stack.crop_ref = crop
	var world_pos: Vector2 = get_world_pos(tile_pos)
	HarvestPickup.spawn(stack, get_parent(), world_pos - Vector2(0.0, 8.0))

func _process_daily_growth(day: int) -> void:
	for tile_pos: Vector2i in _tiles.keys():
		var tile_data: Dictionary = _tiles[tile_pos]
		var crop: CropData = tile_data.get("crop") as CropData
		if crop == null or bool(tile_data.get("harvestable", false)):
			continue
		var days_elapsed: int = day - int(tile_data.get("planted_at_day", -1))
		if days_elapsed <= 0:
			continue
		var expected_stage: int = growth_component.get_expected_stage(days_elapsed, crop.growth_days, crop.growth_stages)
		if expected_stage > int(tile_data.get("growth_stage", 0)):
			tile_data["growth_stage"] = expected_stage
			_update_crop_sprite(tile_pos, crop.get_stage_sprite(expected_stage))
			crop_grew.emit(tile_pos, expected_stage)
		if growth_component.is_harvestable(expected_stage, crop.growth_stages):
			tile_data["harvestable"] = true
			_show_harvest_indicator(tile_pos)
			crop_harvestable.emit(tile_pos, crop.crop_name)

func _process_soil_reversion(day: int) -> void:
	for tile_pos: Vector2i in _tiles.keys():
		var tile_data: Dictionary = _tiles[tile_pos]
		if not bool(tile_data.get("tilled", false)) or tile_data.get("crop") != null:
			continue
		var tilled_at_day: int = int(tile_data.get("tilled_at_day", -1))
		if tilled_at_day >= 0 and day - tilled_at_day >= 1:
			tile_data["tilled"] = false
			tile_data["tilled_at_day"] = -1
			clear_soil_tile(tile_pos)

func _create_crop_sprite(tile_pos: Vector2i, texture: Texture2D) -> void:
	if _crop_sprites.has(tile_pos):
		_update_crop_sprite(tile_pos, texture)
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(tile_pos) * float(tile_size) + _map_offset
	crop_container.add_child(sprite)
	_crop_sprites[tile_pos] = sprite

func _update_crop_sprite(tile_pos: Vector2i, texture: Texture2D) -> void:
	var sprite: Sprite2D = _crop_sprites.get(tile_pos)
	if sprite != null:
		sprite.texture = texture

func _remove_crop_sprite(tile_pos: Vector2i) -> void:
	var sprite: Sprite2D = _crop_sprites.get(tile_pos)
	if sprite != null:
		sprite.queue_free()
		_crop_sprites.erase(tile_pos)

func _show_harvest_indicator(tile_pos: Vector2i) -> void:
	if _harvest_indicators.has(tile_pos):
		return
	var indicator: Label = Label.new()
	indicator.text = "!"
	indicator.add_theme_font_size_override("font_size", 20)
	indicator.add_theme_color_override("font_color", Color(1.0, 0.87, 0.22, 1.0))
	indicator.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	indicator.add_theme_constant_override("shadow_offset_x", 1)
	indicator.add_theme_constant_override("shadow_offset_y", 1)
	indicator.z_index = 200
	indicator.position = Vector2(tile_pos) * float(tile_size) + _map_offset + Vector2(float(tile_size) * 0.38, -10.0)
	crop_container.add_child(indicator)
	_harvest_indicators[tile_pos] = indicator

func _remove_harvest_indicator(tile_pos: Vector2i) -> void:
	var indicator: Label = _harvest_indicators.get(tile_pos)
	if indicator != null:
		indicator.queue_free()
		_harvest_indicators.erase(tile_pos)

func get_save_data() -> Dictionary:
	var farm_data: Dictionary = {}
	for tile_pos: Vector2i in _tiles.keys():
		var tile_data: Dictionary = _tiles[tile_pos]
		if tile_data.get("crop") != null or bool(tile_data.get("tilled", false)):
			farm_data[var_to_str(tile_pos)] = {
				"tilled": bool(tile_data.get("tilled", false)),
				"tilled_at_day": int(tile_data.get("tilled_at_day", -1)),
				"crop_id": String(tile_data.get("crop_id", "")),
				"planted_at_day": int(tile_data.get("planted_at_day", -1)),
				"growth_stage": int(tile_data.get("growth_stage", 0)),
				"harvestable": bool(tile_data.get("harvestable", false)),
				"regrow_count": int(tile_data.get("regrow_count", 0)),
			}
	return farm_data

func load_from_save(farm_data: Dictionary) -> void:
	for tile_pos: Vector2i in _tiles.keys():
		clear_soil_tile(tile_pos)
		_remove_crop_sprite(tile_pos)
		_remove_harvest_indicator(tile_pos)
	_tiles.clear()
	for key: Variant in farm_data.keys():
		var tile_pos: Vector2i = str_to_var(String(key)) as Vector2i
		var saved: Dictionary = farm_data[key] as Dictionary
		var tile_data: Dictionary = get_tile_data(tile_pos)
		tile_data["tilled"] = bool(saved.get("tilled", false))
		tile_data["tilled_at_day"] = int(saved.get("tilled_at_day", -1))
		tile_data["crop_id"] = String(saved.get("crop_id", ""))
		tile_data["planted_at_day"] = int(saved.get("planted_at_day", -1))
		tile_data["growth_stage"] = int(saved.get("growth_stage", 0))
		tile_data["harvestable"] = bool(saved.get("harvestable", false))
		tile_data["regrow_count"] = int(saved.get("regrow_count", 0))
		if bool(saved.get("tilled", false)):
			tilled_layer.set_cells_terrain_connect([tile_pos], 0, 0, false)
		if String(saved.get("crop_id", "")) != "":
			var crop: CropData = crop_registry.get(String(saved.get("crop_id", "")))
			if crop != null:
				tile_data["crop"] = crop
				_create_crop_sprite(tile_pos, crop.get_stage_sprite(int(saved.get("growth_stage", 0))))
				if bool(saved.get("harvestable", false)):
					_show_harvest_indicator(tile_pos)

func get_world_pos(tile_pos: Vector2i) -> Vector2:
	var tile_center: float = float(tile_size) * 0.5
	return Vector2(tile_pos) * float(tile_size) + Vector2(tile_center, tile_center)

func get_tile_pos(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(tile_size)), floori(world_pos.y / float(tile_size)))

func get_crop_names() -> Array[String]:
	return crop_registry.keys()
