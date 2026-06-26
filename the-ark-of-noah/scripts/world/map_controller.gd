class_name MapController
extends Node

## Root controller for the layered tilemap (map_v2).
##
## Owns the biome nodes and their components. Provides a single entry point for
## cross-biome systems:
##   - Weather: applies wind to every TreeTopLayerComponent, tint to biomes.
##   - Biome lookup: get_biome(id) returns the biome node for a given id.
##
## The biome nodes themselves (BeachBiome, MeadowsBiome, ForestBiome) are children
## of the map root and each carry a BiomeComponent + their per-layer components.

@export var wind_intensity: float = 0.0

## If true, the MapController polls the WeatherManager each frame and drives
## wind to every treetop layer automatically.  Disable to control wind manually.
@export var auto_wind_from_weather: bool = true

## How much the weather wind strength multiplies into canopy intensity.
@export_range(0.0, 2.0, 0.01) var weather_wind_scale: float = 1.0

var _biomes: Dictionary = {}
var _weather_manager: WeatherManager = null

func _ready() -> void:
	_index_biomes()

func _process(_delta: float) -> void:
	if not auto_wind_from_weather:
		return
	if _weather_manager == null:
		if get_tree() != null:
			_weather_manager = get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager
		if _weather_manager == null:
			return
	# Drive the existing apply_wind() from live weather data. This single
	# call fans out to every TreeTopLayerComponent across all biomes — no
	# per-tree scripting required.
	apply_wind(_weather_manager.get_wind_strength() * weather_wind_scale)

func _index_biomes() -> void:
	_biomes.clear()
	for child: Node in get_children():
		var biome_comp: BiomeComponent = child.get_node_or_null("BiomeComponent") as BiomeComponent
		if biome_comp:
			_biomes[biome_comp.biome_id] = child

## Returns the biome node with the given id, or null.
func get_biome(biome_id: String) -> Node:
	return _biomes.get(biome_id, null)

## Returns all biome nodes.
func get_all_biomes() -> Array:
	return _biomes.values()

## Applies wind to every treetop layer in every biome.
func apply_wind(intensity: float) -> void:
	wind_intensity = clampf(intensity, 0.0, 1.0)
	for biome_node: Node in _biomes.values():
		var top_comp: TreeTopLayerComponent = biome_node.get_node_or_null("TreeTopLayerComponent") as TreeTopLayerComponent
		if top_comp:
			top_comp.set_wind_intensity(wind_intensity)
