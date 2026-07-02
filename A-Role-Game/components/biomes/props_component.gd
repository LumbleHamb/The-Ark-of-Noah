class_name PropsComponent
extends Component

## Manages the props layer for a biome (rocks, flowers, bushes, debris).
##
## Props are placed as tiles on the entity's "Props" TileMapLayer child.
## This component exposes prop lookup + a spawn/despawn hook so props can be
## chunk-loaded alongside the rest of the biome.

@export var props_layer_path: NodePath = NodePath("")

var _layer: TileMapLayer = null

func _component_ready() -> void:
	if props_layer_path != NodePath(""):
		_layer = get_node(props_layer_path) as TileMapLayer
	if _layer == null:
		var entity := get_entity()
		if entity:
			_layer = entity.get_node_or_null("Props") as TileMapLayer

func get_layer() -> TileMapLayer:
	return _layer

## Returns true if a prop tile exists at the given cell.
func has_prop_at(cell: Vector2i) -> bool:
	return _layer != null and _layer.get_cell_source_id(cell) != -1
