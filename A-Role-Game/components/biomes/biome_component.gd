class_name BiomeComponent
extends Component

## Base component for a map biome. A biome owns a set of TileMapLayers and
## manages which tiles belong to its region (beach / meadows / forest).
##
## Subclasses set biome_id and override _component_ready to wire biome-specific
## behaviour. This base provides the shared API the MapController queries so it
## can iterate biomes uniformly (e.g. for weather, day/night tinting, chunking).

@export var biome_id: String = "base"
@export var biome_color: Color = Color.WHITE

## Returns the TileMapLayers that visually represent this biome, in draw order.
func get_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for child: Node in get_entity().get_children():
		if child is TileMapLayer:
			layers.append(child as TileMapLayer)
	return layers

## Returns the combined used-rect (tile coords) across this biome's layers.
func get_used_rect() -> Rect2i:
	var rect: Rect2i = Rect2i()
	var first: bool = true
	for layer: TileMapLayer in get_layers():
		var r: Rect2i = layer.get_used_rect()
		if r.size == Vector2i.ZERO:
			continue
		if first:
			rect = r
			first = false
		else:
			rect = rect.merge(r)
	return rect
