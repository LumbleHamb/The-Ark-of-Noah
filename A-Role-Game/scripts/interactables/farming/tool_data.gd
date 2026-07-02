class_name ToolData
extends Resource

## Data-driven tool definition.
## To add a new tool: create a .tres file from this template
## with the sprites and properties assigned.

enum ToolType {
	HOE,      # Till soil
	SEED,     # Plant crops (special: uses CropData instead)
	AXE,      # Chop trees
	PICKAXE,  # Mine rocks
	SHOVEL,   # Dig / harvest
}

## Human-readable name, e.g. "Starter Hoe"
@export var tool_name: String = ""

## The tool category.
@export var tool_type: ToolType = ToolType.HOE

## Tier label for upgrade display, e.g. "starter", "copper", "steel", "diamond", "diamond_reinforced"
@export var tier: String = "starter"

## Swing animation frames (4 frames expected: _0, _1, _2, _3)
@export var swing_sprites: Array[Texture2D] = []

## Icon for inventory / hotbar.
@export var icon: Texture2D = null

## Base range in tiles (for interaction check).
@export var range_tiles: int = 1

## Speed multiplier (higher = faster swing).
@export var speed_multiplier: float = 1.0

## Efficiency multiplier (affects yield or energy cost).
@export var efficiency: float = 1.0
