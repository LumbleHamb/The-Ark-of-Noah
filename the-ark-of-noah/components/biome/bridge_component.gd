class_name BridgeComponent
extends Component

## Manages the bridge tiles for a biome.
##
## Bridges connect biomes across water/gaps. They are walkable (collision on)
## so the player and animals can cross. This component tracks which bridge
## cells exist and exposes a query so pathfinding / the player can tell a bridge
## tile from a water tile.

@export var bridge_layer_path: NodePath = NodePath("")

var _layer: TileMapLayer = null

func _component_ready() -> void:
	if bridge_layer_path != NodePath(""):
		_layer = get_node(bridge_layer_path) as TileMapLayer
	if _layer == null:
		var entity := get_entity()
		if entity:
			_layer = entity.get_node_or_null("Bridges") as TileMapLayer

func get_layer() -> TileMapLayer:
	return _layer

## Returns true if a bridge tile exists at the given cell (i.e. crossable).
func is_bridge_at(cell: Vector2i) -> bool:
	return _layer != null and _layer.get_cell_source_id(cell) != -1
