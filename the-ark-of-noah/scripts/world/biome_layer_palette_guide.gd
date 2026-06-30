class_name BiomeLayerPaletteGuide
extends Resource

const TILESET_PATH: String = "res://images/tilesets/terrains/grass_tileset.tres"

const LAYER_ORDER: PackedStringArray = [
	"Ground",
	"Meadows",
	"Grass",
	"Beach",
	"Water",
	"Paths",
	"Collision",
	"TilledSoil",
	"Crops",
	"Decor_Back",
	"Harvestables",
	"Bridges",
	"TreeTrunks",
	"Buildings",
	"NPCNavigationMask",
	"Decor_Front",
	"TreeTops",
	"Interaction"
]

const SOURCE_LABELS: Dictionary = {
	0: "full_tileset (base terrain, paths, many props)",
	1: "waterfall-spritesheet (animated waterfall columns)",
	2: "beach_grass_trans (animated shoreline transitions)",
	3: "grass-to-water transitions (animated coast edges)",
	4: "beach foam atlas (animated coastline foam)",
	5: "Atlas-Props-sheet3 (props/bridges/decor)",
	8: "props.png (trees/rocks/objects)"
}

const ANIMATED_SOURCES: PackedInt32Array = [1, 2, 3, 4]

const STARTER_TILES: Dictionary = {
	"Meadows": {"source_id": 0, "atlas": Vector2i(22, 3)},
	"Grass": {"source_id": 0, "atlas": Vector2i(21, 2)},
	"Beach": {"source_id": 4, "atlas": Vector2i(9, 0)},
	"Water": {"source_id": 0, "atlas": Vector2i(0, 0)},
	"Paths": {"source_id": 0, "atlas": Vector2i(20, 3)}
}
