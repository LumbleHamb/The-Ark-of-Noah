class_name FarmManager
extends Node2D

## Core farming system manager.
##
## Architecture:
## - Node2D root added as child of World
## - TileMapLayer for tilled-soil visuals (fertilized soil.png atlas)
## - Node2D container for per-crop Sprite2D visuals (lightweight, no nodes per tile for logic)
## - Dictionary<Vector2i, Dictionary> for all tile state (data-driven, zero node overhead)
## - Real-time growth using Time.get_unix_time_from_system() — no watering needed
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
@onready var soil_layer: TileMapLayer = $SoilLayer
@onready var crop_container: Node2D = $Crops

# ============================================================================
# EXPORTS
# ============================================================================
## Soil atlas texture (fertilized soil.png recommended).
@export var soil_texture: Texture2D = null

## Tile coordinate in the soil atlas for "tilled" soil.
@export var tilled_tile_atlas: Vector2i = Vector2i(0, 0)

## Max number of crops to update per frame (spread load).
@export var max_updates_per_frame: int = 20

## Check interval in seconds (don't check every frame for large farms).
@export var growth_check_interval: float = 2.0

# ============================================================================
# STATE
# ============================================================================
var _tiles: Dictionary = {}
var _crop_sprites: Dictionary = {}
var _growth_timer: float = 0.0
var _update_cursor: int = 0

## Crop registry: crop_id -> CropData (loaded from resources/crops/*.tres)
var crop_registry: Dictionary = {}

## Seed-to-crop mapping: seed_id -> crop_id
var seed_to_crop: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	add_to_group(&"farm_manager")
	_setup_soil_layer()
	_load_crop_registry()

func _process(delta: float) -> void:
	_growth_timer += delta
	if _growth_timer < growth_check_interval:
		return
	_growth_timer -= growth_check_interval
	_process_crop_growth()

# ============================================================================
# SOIL LAYER SETUP
# ============================================================================
func _setup_soil_layer() -> void:
	if soil_texture == null:
		return
	var tileset := TileSet.new()
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = soil_texture
	atlas_source.texture_region_size = Vector2i(32, 32)
	
	var tex_w: int = soil_texture.get_width()
	var tex_h: int = soil_texture.get_height()
	var cols: int = int(tex_w / 32.0)
	var rows: int = int(tex_h / 32.0)
	for y in range(rows):
		for x in range(cols):
			atlas_source.create_tile(Vector2i(x, y))
	
	tileset.add_source(atlas_source, 0)
	soil_layer.tile_set = tileset

func set_soil_tile(tile_pos: Vector2i, atlas_coord: Vector2i) -> void:
	soil_layer.set_cell(tile_pos, 0, atlas_coord)

func clear_soil_tile(tile_pos: Vector2i) -> void:
	soil_layer.set_cell(tile_pos, -1)

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
				# seed_to_crop maps seed_id -> crop_id for future inventory system use
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
			"tilled": false, "crop_id": "", "crop": null,
			"planted_at": 0.0, "growth_stage": 0,
			"harvestable": false, "regrow_count": 0,
		}
	return _tiles[tile_pos]

func is_tillable(tile_pos: Vector2i) -> bool:
	return not get_tile_data(tile_pos)["tilled"]

func is_plantable(tile_pos: Vector2i) -> bool:
	var d = get_tile_data(tile_pos)
	return d["tilled"] and d["crop"] == null

func is_harvestable(tile_pos: Vector2i) -> bool:
	return get_tile_data(tile_pos)["harvestable"]

# ============================================================================
# ACTIONS
# ============================================================================
func till_tile(tile_pos: Vector2i) -> bool:
	if not is_tillable(tile_pos):
		return false
	var d = get_tile_data(tile_pos)
	d["tilled"] = true
	set_soil_tile(tile_pos, tilled_tile_atlas)
	tile_tilled.emit(tile_pos)
	return true

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
	d["planted_at"] = Time.get_unix_time_from_system()
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
		d["planted_at"] = Time.get_unix_time_from_system()
		d["growth_stage"] = crop.growth_stages - 2
		d["harvestable"] = false
		d["regrow_count"] += 1
		_update_crop_sprite(tile_pos, crop.get_stage_sprite(d["growth_stage"]))
	else:
		_remove_crop_sprite(tile_pos)
		d["crop"] = null
		d["crop_id"] = ""
		d["planted_at"] = 0.0
		d["growth_stage"] = 0
		d["harvestable"] = false
	
	crop_harvested.emit(tile_pos, crop_name, yield_count)
	return yield_count

# ============================================================================
# GROWTH SYSTEM (real-time, no watering)
# ============================================================================
func _process_crop_growth() -> void:
	var planted: Array = []
	for tile_pos in _tiles.keys():
		var d = _tiles[tile_pos]
		if d["crop"] != null and not d["harvestable"]:
			planted.append(tile_pos)
	
	if planted.is_empty():
		return
	
	var now: float = Time.get_unix_time_from_system()
	var batch_count: int = mini(max_updates_per_frame, planted.size())
	for idx in range(batch_count):
		if _update_cursor >= planted.size():
			_update_cursor = 0
			break
		var tile_pos: Vector2i = planted[_update_cursor]
		_update_cursor += 1
		
		var d = _tiles[tile_pos]
		var crop = d["crop"]
		if crop == null:
			continue
		
		var elapsed: float = now - d["planted_at"]
		var time_per_stage: float = crop.growth_time_seconds / float(crop.growth_stages)
		var expected_stage: int = mini(int(elapsed / time_per_stage), crop.growth_stages - 1)
		
		if expected_stage > d["growth_stage"]:
			d["growth_stage"] = expected_stage
			_update_crop_sprite(tile_pos, crop.get_stage_sprite(expected_stage))
			crop_grew.emit(tile_pos, expected_stage)
			
			if expected_stage >= crop.growth_stages - 1:
				d["harvestable"] = true
				crop_harvestable.emit(tile_pos, crop.crop_name)
	
	if _update_cursor >= planted.size():
		_update_cursor = 0

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
	sprite.position = Vector2(tile_pos) * 32
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
				"crop_id": d["crop_id"],
				"planted_at": d["planted_at"],
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
		d["crop_id"] = saved["crop_id"]
		d["planted_at"] = saved["planted_at"]
		d["growth_stage"] = saved["growth_stage"]
		d["harvestable"] = saved["harvestable"]
		d["regrow_count"] = saved.get("regrow_count", 0)
		
		if saved["tilled"]:
			set_soil_tile(tile_pos, tilled_tile_atlas)
		
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
