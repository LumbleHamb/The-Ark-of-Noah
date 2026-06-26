class_name TreeTrunkLayerComponent
extends Component

## Owns the tree TRUNK tiles for a biome.
##
## Trees are deliberately split into trunks and treetops so a future weather
## system (wind, seasonal leaf loss, storm blow-down) can animate / swap the
## treetop layer independently of the trunks (which stay static and collidable).
##
## Trunk tiles carry physics collision so the player and animals are blocked by
## tree stems. Treetops (see TreeTopLayerComponent) are purely visual and sit on a
## higher draw layer.

@export var trunk_layer_path: NodePath = NodePath("")
@export var add_collision: bool = true

var _layer: TileMapLayer = null

func _component_ready() -> void:
	if trunk_layer_path != NodePath(""):
		_layer = get_node(trunk_layer_path) as TileMapLayer
	if _layer == null:
		var entity := get_entity()
		if entity:
			_layer = entity.get_node_or_null("TreeTrunks") as TileMapLayer

func get_layer() -> TileMapLayer:
	return _layer
