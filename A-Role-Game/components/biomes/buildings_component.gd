class_name BuildingsComponent
extends Component

## Manages the buildings layer for a biome (houses, shelters, fences).
##
## Buildings are placed as instanced tiles or child scene instances on the
## entity's "Buildings" TileMapLayer. This component tracks building counts and
## provides a query API for placement validation (is the cell free of buildings).

@export var buildings_layer_path: NodePath = NodePath("")

var _layer: TileMapLayer = null

func _component_ready() -> void:
	if buildings_layer_path != NodePath(""):
		_layer = get_node(buildings_layer_path) as TileMapLayer
	if _layer == null:
		var entity := get_entity()
		if entity:
			_layer = entity.get_node_or_null("Buildings") as TileMapLayer

func get_layer() -> TileMapLayer:
	return _layer

## Returns true if a building tile exists at the given cell.
func has_building_at(cell: Vector2i) -> bool:
	return _layer != null and _layer.get_cell_source_id(cell) != -1

## Returns the number of building tiles placed in this biome.
func building_count() -> int:
	return _layer.get_used_cells().size() if _layer != null else 0
