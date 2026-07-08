class_name BiomeSystem
extends Node

signal biome_changed(new_biome_id: String)
signal biome_profile_changed(biome: BiomeDefinition)

@export var biome_database: BiomeDatabase
@export var biome_paint_layer_path: NodePath
@export var default_biome_id: String = "meadows"
@export var tracked_player_path: NodePath

var _paint_layer: TileMapLayer
var _tracked_player: Node2D
var _last_biome_id: String = ""


func _ready() -> void:
	_paint_layer = get_node_or_null(biome_paint_layer_path) as TileMapLayer
	if tracked_player_path.is_empty() == false:
		_tracked_player = get_node_or_null(tracked_player_path) as Node2D
	if _tracked_player == null:
		var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
		if players.is_empty() == false:
			_tracked_player = players[0] as Node2D
	set_process(_tracked_player != null)
	_last_biome_id = get_biome_id_at_global_position(_tracked_player.global_position if _tracked_player != null else Vector2.ZERO)
	_apply_biome_profile(_last_biome_id)


func _process(_delta: float) -> void:
	if _tracked_player == null or is_instance_valid(_tracked_player) == false:
		return
	var current: String = get_biome_id_at_global_position(_tracked_player.global_position)
	if current != _last_biome_id:
		_last_biome_id = current
		biome_changed.emit(current)
		_apply_biome_profile(current)


func get_biome_id_at_global_position(world_pos: Vector2) -> String:
	if _paint_layer == null:
		return default_biome_id
	var cell: Vector2i = _paint_layer.local_to_map(_paint_layer.to_local(world_pos))
	var source_id: int = _paint_layer.get_cell_source_id(cell)
	if source_id < 0:
		return default_biome_id
	var atlas: Vector2i = _paint_layer.get_cell_atlas_coords(cell)
	if atlas.x < 0:
		return default_biome_id
	return _atlas_x_to_biome_id(atlas.x)


func get_biome_at_global_position(world_pos: Vector2) -> BiomeDefinition:
	if biome_database == null:
		return null
	var biome_id: String = get_biome_id_at_global_position(world_pos)
	var biome: BiomeDefinition = biome_database.get_biome_by_id(biome_id)
	if biome != null:
		return biome
	return biome_database.get_biome_by_id(default_biome_id)


func get_current_biome() -> BiomeDefinition:
	if _tracked_player == null:
		return null
	return get_biome_at_global_position(_tracked_player.global_position)


func _atlas_x_to_biome_id(atlas_x: int) -> String:
	if biome_database == null:
		return default_biome_id
	if atlas_x >= 0 and atlas_x < biome_database.biomes.size():
		var biome: BiomeDefinition = biome_database.biomes[atlas_x]
		if biome != null:
			return biome.biome_id
	return default_biome_id


func _apply_biome_profile(biome_id: String) -> void:
	if biome_database == null:
		return
	var biome: BiomeDefinition = biome_database.get_biome_by_id(biome_id)
	if biome == null:
		biome = biome_database.get_biome_by_id(default_biome_id)
	if biome == null:
		return
	biome_profile_changed.emit(biome)
	_apply_lighting_profile(biome)
	_apply_audio_profile(biome)


func _apply_lighting_profile(biome: BiomeDefinition) -> void:
	if get_tree() == null:
		return
	var lighting_manager: Node = get_tree().get_first_node_in_group(&"lighting_manager")
	if lighting_manager != null and lighting_manager.has_method("set_biome_modifiers"):
		lighting_manager.call("set_biome_modifiers", biome.lighting_tint, biome.lighting_energy_multiplier)


func _apply_audio_profile(biome: BiomeDefinition) -> void:
	if get_tree() == null:
		return
	var audio_manager: Node = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		return
	if audio_manager.has_method("set_meta"):
		audio_manager.set_meta(&"biome_music_event", biome.music_event)
		audio_manager.set_meta(&"biome_ambient_event", biome.ambient_event)
