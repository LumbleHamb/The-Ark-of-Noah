class_name FarmManager
extends Node2D

## Core farming system manager.
##
## Architecture:
## - References the `ground` TileMapLayer (map_backup) for grass-tile validation.
## - References the `garden` TileMapLayer (map_backup) for tilled-soil visuals.
##   The garden layer has a terrain set "fertilized_soil" that auto-picks the
##   correct 47-blob edge-transition tile when painting via terrain mode.
## - Node2D container for per-crop Sprite2D visuals (lightweight, no nodes per tile for logic).
## - Dictionary<Vector2i, Dictionary> for all tile state (data-driven, zero node overhead).
## - In-game-day-based growth — each crop's `growth_days` configures maturity speed.
## - Tilled soil reverts to grass after 1 in-game day if no crop is planted.
##
## Adding a crop: create a CropData .tres in resources/crops/, assign sprites.
## Adding a tool: create a ToolData .tres in resources/tools/.
## No code changes needed.

const _CropDataClass = preload("res://scripts/farming/crop_data.gd")

# ============================================================================
# SIGNALS
# ============================================================================
signal tile_tilled(tile_pos: Vector2i)
signal crop_planted(tile_pos: Vector2i, crop_name: String)
signal crop_grew(tile_pos: Vector2i, stage: int)
signal crop_harvestable(tile_pos: Vector2i, crop_name: String)
signal crop_harvested(tile_pos: Vector2i, crop_name: String, yield_count: int)

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var crop_container: Node2D = $Crops

# These are found at runtime by walking up to the world node and finding the map.
var ground_layer: TileMapLayer = null   # green-grass validation
var garden_layer: TileMapLayer = null   # fertilized-soil terrain painting

# TimeManager reference for in-game day tracking.
var time_manager: TimeManager = null

# ============================================================================
# STATE
# ============================================================================
var _tiles: Dictionary = {}
var _crop_sprites: Dictionary = {}
var _last_checked_day: int = -1

## Crop registry: crop_id -> CropData (loaded from resources/crops/*.tres)
var crop_registry: Dictionary = {}

## Seed-to-crop mapping: seed_id -> crop_id
var seed_to_crop: Dictionary = {}

## Map offset to align crop sprites with garden tilemap.
var _map_offset: Vector2 = Vector2.ZERO

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	add_to_group(&"farm_manager")
	_find_map_layers()
	_load_crop_registry()
	_find_time_manager()

func _find_time_manager() -> void:
	time_manager = get_tree().get_first_node_in_group(&"time_manager")
	if time_manager:
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

	var map_node: Node = world.get_node_or_null("map")
	if map_node == null:
		push_warning("FarmManager: no 'map' node found under world")
		return

	ground_layer = map_node.get_node_or_null("ground") as TileMapLayer
	garden_layer = map_node.get_node_or_null("garden") as TileMapLayer

	# Store map offset so crop sprites align with garden tiles.
	if map_node is Node2D:
		_map_offset = (map_node as Node2D).position

	if ground_layer == null:
		push_warning("FarmManager: no 'ground' TileMapLayer found in map")
	if garden_layer == null:
		push_warning("FarmManager: no 'garden' TileMapLayer found in map")

func _process(_delta: float) -> void:
	# Growth is now driven by in-game day changes from TimeManager.
	pass

# ============================================================================
# GRASS VALIDATION (green-grass tiles on the ground layer)
# ============================================================================

## Returns true if the tile position contains a grass tile on the ground layer.
func is_grass_tile(tile_pos: Vector2i) -> bool:
	if ground_layer == null:
		return false
	return ground_layer.get_cell_source_id(tile_pos) != -1

func is_tillable(tile_pos: Vector2i) -> bool:
	if not is_grass_tile(tile_pos):
		return false
	return not get_tile_data(tile_pos)["tilled"]

# ============================================================================
# TILLING (terrain-based, uses garden node's fertilized_soil terrain set)
# ============================================================================

func till_tile(tile_pos: Vector2i) -> bool:
	if not is_tillable(tile_pos):
		return false
	if garden_layer == null:
		return false

	var d = get_tile_data(tile_pos)
	d["tilled"] = true
	d["tilled_at_day"] = time_manager.current_day if time_manager else 0

	# Paint terrain on the garden layer — Godot's terrain system auto-selects
	# the correct 47-blob tile based on neighbors.
	# NOTE: ignore_existing=false is required! With the default true, Godot
	# fails to place a tile when tilling a single isolated cell on an empty
	# layer (all neighbors are empty, so there's nothing to "connect" to).
	garden_layer.set_cells_terrain_connect([tile_pos], 0, 0, false)

	tile_tilled.emit(tile_pos)
	return true

func clear_soil_tile(tile_pos: Vector2i) -> void:
	if garden_layer == null:
		return
	garden_layer.set_cell(tile_pos, -1)

# ============================================================================
# CROP REGISTRY
# ============================================================================
func _load_crop_registry() -> void:
	var crop_dir: String = "res://resources/crops/"
	var dir := DirAccess.open(crop_dir)
	if dir == null:
		push_warning("FarmManager: no crop resources at " + crop_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var path: String = crop_dir.path_join(file_name)
			var crop: Resource = ResourceLoader.load(path)
			if crop is _CropDataClass:
				var crop_id: String = crop.crop_name.to_lower().replace(" ", "_")
				crop_registry[crop_id] = crop
				seed_to_crop[crop_id] = crop_id
		file_name = dir.get_next()
	dir.list_dir_end()

	print("FarmManager: loaded %d crops" % crop_registry.size())

# ============================================================================
# TILE STATE
# ============================================================================
func get_tile_data(tile_pos: Vector2i) -> Dictionary:
	if not _tiles.has(tile_pos):
		_tiles[tile_pos] = {
			"tilled": false, "tilled_at_day": -1,
			"crop_id": "", "crop": null,
			"planted_at_day": -1, "growth_stage": 0,
			"harvestable": false, "regrow_count": 0,
		}
	return _tiles[tile_pos]

func is_plantable(tile_pos: Vector2i) -> bool:
	var d = get_tile_data(tile_pos)
	return d["tilled"] and d["crop"] == null

func is_harvestable(tile_pos: Vector2i) -> bool:
	return get_tile_data(tile_pos)["harvestable"]

# ============================================================================
# ACTIONS
# ============================================================================

func plant_crop(tile_pos: Vector2i, crop_id: String) -> bool:
	if not is_plantable(tile_pos):
		return false

	var crop = crop_registry.get(crop_id)
	if crop == null:
		push_warning("FarmManager: unknown crop '%s'" % crop_id)
		return false

	var d = get_tile_data(tile_pos)
	d["crop"] = crop
	d["crop_id"] = crop_id
	d["planted_at_day"] = time_manager.current_day if time_manager else 0
	d["growth_stage"] = 0
	d["harvestable"] = false
	d["regrow_count"] = 0

	_create_crop_sprite(tile_pos, crop.get_stage_sprite(0))
	crop_planted.emit(tile_pos, crop.crop_name)
	return true

func harvest_tile(tile_pos: Vector2i) -> int:
	if not is_harvestable(tile_pos):
		return 0

	var d = get_tile_data(tile_pos)
	var crop = d["crop"]
	if crop == null:
		return 0

	var yield_count = crop.get_yield()
	var crop_name = crop.crop_name

	if crop.regrowable:
		d["planted_at_day"] = time_manager.current_day if time_manager else 0
		d["growth_stage"] = crop.growth_stages - 2
		d["harvestable"] = false
		d["regrow_count"] += 1
		_update_crop_sprite(tile_pos, crop.get_stage_sprite(d["growth_stage"]))
	else:
		_remove_crop_sprite(tile_pos)
		d["crop"] = null
		d["crop_id"] = ""
		d["planted_at_day"] = -1
		d["growth_stage"] = 0
		d["harvestable"] = false

	crop_harvested.emit(tile_pos, crop_name, yield_count)
	return yield_count

# ============================================================================
# GROWTH SYSTEM (in-game-day-based)
# ============================================================================

## Called once per in-game day to advance all planted crops.
func _process_daily_growth(day: int) -> void:
	for tile_pos in _tiles.keys():
		var d = _tiles[tile_pos]
		if d["crop"] == null or d["harvestable"]:
			continue

		var crop = d["crop"]
		var days_elapsed: int = day - d["planted_at_day"]
		if days_elapsed <= 0:
			continue

		var expected_stage: int = mini(
			days_elapsed * crop.growth_stages / crop.growth_days,
			crop.growth_stages - 1
		)

		if expected_stage > d["growth_stage"]:
			d["growth_stage"] = expected_stage
			_update_crop_sprite(tile_pos, crop.get_stage_sprite(expected_stage))
			crop_grew.emit(tile_pos, expected_stage)

		if expected_stage >= crop.growth_stages - 1:
			d["harvestable"] = true
			crop_harvestable.emit(tile_pos, crop.crop_name)

## Tilled soil reverts to grass after 1 in-game day if no crop is planted.
func _process_soil_reversion(day: int) -> void:
	for tile_pos in _tiles.keys():
		var d = _tiles[tile_pos]
		if not d["tilled"] or d["crop"] != null:
			continue
		if d["tilled_at_day"] >= 0 and day - d["tilled_at_day"] >= 1:
			d["tilled"] = false
			d["tilled_at_day"] = -1
			clear_soil_tile(tile_pos)

# ============================================================================
# CROP VISUALS
# ============================================================================
func _create_crop_sprite(tile_pos: Vector2i, texture: Texture2D) -> void:
	if _crop_sprites.has(tile_pos):
		_update_crop_sprite(tile_pos, texture)
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(tile_pos) * 32 + _map_offset
	crop_container.add_child(sprite)
	_crop_sprites[tile_pos] = sprite

func _update_crop_sprite(tile_pos: Vector2i, texture: Texture2D) -> void:
	var sprite: Sprite2D = _crop_sprites.get(tile_pos)
	if sprite:
		sprite.texture = texture

func _remove_crop_sprite(tile_pos: Vector2i) -> void:
	var sprite: Sprite2D = _crop_sprites.get(tile_pos)
	if sprite:
		sprite.queue_free()
		_crop_sprites.erase(tile_pos)

# ============================================================================
# SAVE / LOAD
# ============================================================================
func get_save_data() -> Dictionary:
	var farm_data: Dictionary = {}
	for tile_pos in _tiles.keys():
		var d = _tiles[tile_pos]
		if d["crop"] != null or d["tilled"]:
			farm_data[var_to_str(tile_pos)] = {
				"tilled": d["tilled"],
				"tilled_at_day": d["tilled_at_day"],
				"crop_id": d["crop_id"],
				"planted_at_day": d["planted_at_day"],
				"growth_stage": d["growth_stage"],
				"harvestable": d["harvestable"],
				"regrow_count": d["regrow_count"],
			}
	return farm_data

func load_from_save(farm_data: Dictionary) -> void:
	for tile_pos in _tiles.keys():
		clear_soil_tile(tile_pos)
		_remove_crop_sprite(tile_pos)
	_tiles.clear()

	for key in farm_data.keys():
		var tile_pos: Vector2i = str_to_var(key)
		var saved = farm_data[key]
		var d = get_tile_data(tile_pos)
		d["tilled"] = saved["tilled"]
		d["tilled_at_day"] = saved.get("tilled_at_day", -1)
		d["crop_id"] = saved["crop_id"]
		d["planted_at_day"] = saved.get("planted_at_day", -1)
		d["growth_stage"] = saved["growth_stage"]
		d["harvestable"] = saved["harvestable"]
		d["regrow_count"] = saved.get("regrow_count", 0)

		if saved["tilled"]:
			till_tile(tile_pos)

		if saved["crop_id"] != "":
			var crop = crop_registry.get(saved["crop_id"])
			if crop:
				d["crop"] = crop
				_create_crop_sprite(tile_pos, crop.get_stage_sprite(saved["growth_stage"]))

# ============================================================================
# UTILITY
# ============================================================================
func get_world_pos(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos) * 32 + Vector2(16, 16)

func get_tile_pos(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / 32), floori(world_pos.y / 32))

func get_crop_names() -> Array[String]:
	return crop_registry.keys()
