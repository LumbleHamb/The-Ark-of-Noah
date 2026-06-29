class_name ElevationComponent
extends Component

## Owns the elevation/cliff tiles for a biome.
##
## Elevation is data-only on this component (height offsets, walkable flags)
## so a future weather / pathfinding system can query it without touching the
## TileMapLayer directly. The actual visual tiles live on the entity's child
## TileMapLayer named in elevation_layer_path.

@export var elevation_layer_path: NodePath = NodePath("")
@export var max_height_level: int = 4
@export var step_height_pixels: float = 16.0

var _layer: TileMapLayer = null

func _component_ready() -> void:
	if elevation_layer_path != NodePath(""):
		_layer = get_node(elevation_layer_path) as TileMapLayer
	if _layer == null:
		var entity := get_entity()
		if entity:
			_layer = entity.get_node_or_null("Elevation") as TileMapLayer

func get_layer() -> TileMapLayer:
	return _layer

## Returns the elevation level (0 = sea level) for a given tile cell, or 0.
func get_height_at(cell: Vector2i) -> int:
	if _layer == null:
		return 0
	var data: TileData = _layer.get_cell_tile_data(cell)
	if data == null:
		return 0
	return int(data.get_custom_data("height")) if data.has_meta("height") else 0
