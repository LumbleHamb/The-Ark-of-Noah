class_name TreeTopLayerComponent
extends Component

## Owns the tree TOP (canopy/leaves) tiles for a biome.
##
## Treetops are rendered ABOVE trunks (higher z-index / later TileMapLayer) and
## carry no physics collision — they are decorative. Because they are a separate
## component+layer from TreeTrunkLayerComponent, a future weather system can:
##   - tint them for autumn/winter without touching trunks,
##   - animate them with a wind shader,
##   - remove them for a "bare branches" seasonal state,
##   - or blow them off during a storm, leaving trunks standing.
##
## This component exposes a wind_intensity setter the weather system can drive.

@export var treetop_layer_path: NodePath = NodePath("")
@export var wind_intensity: float = 0.0

var _layer: TileMapLayer = null

func _component_ready() -> void:
	if treetop_layer_path != NodePath(""):
		_layer = get_node(treetop_layer_path) as TileMapLayer
	if _layer == null:
		var entity := get_entity()
		if entity:
			_layer = entity.get_node_or_null("TreeTops") as TileMapLayer

func get_layer() -> TileMapLayer:
	return _layer

## Drives canopy sway. The weather system calls this (0 = still, 1 = gusting).
func set_wind_intensity(amount: float) -> void:
	wind_intensity = clampf(amount, 0.0, 1.0)
	if _layer:
		# Subtle horizontal shimmer via modulate — a real shader can hook here.
		_layer.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(0.85, 0.9, 0.75, 1.0), wind_intensity * 0.4)
