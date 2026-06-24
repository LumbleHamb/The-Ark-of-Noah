class_name CropData
extends Resource

## Data-driven crop definition.
## To add a new crop: create a .tres file from this template,
## assign its sprites, and register it in FarmManager.

@export var crop_name: String = ""

## How many growth stages this crop has (1 = no visible growth).
@export var growth_stages: int = 8

## Total real-time seconds from planted to fully mature.
@export var growth_time_seconds: float = 120.0

## Minimum harvest yield (per crop).
@export var min_yield: int = 1

## Maximum harvest yield (per crop).
@export var max_yield: int = 1

## If true, the crop regrows after harvest (e.g. blueberry, grape, coffee).
@export var regrowable: bool = false

## If regrowable, how many seconds to regrow after harvest.
@export var regrow_time_seconds: float = 60.0

## Sprite for each growth stage (index 0 = seed/just planted).
@export var stage_sprites: Array[Texture2D] = []

## Seed bag icon (for inventory / planting cursor).
@export var seed_sprite: Texture2D = null

## Harvest item icon (for inventory).
@export var harvest_sprite: Texture2D = null

## Display name for the harvest item.
@export var harvest_item_name: String = ""

## Tilemap atlas coords for the seed when displayed (unused for now).
@export var seed_tile_coords: Vector2i = Vector2i.ZERO

func get_stage_sprite(stage: int) -> Texture2D:
	"""Return the sprite for a given 0-based growth stage, clamped."""
	var idx: int = clampi(stage, 0, stage_sprites.size() - 1)
	if idx < stage_sprites.size():
		return stage_sprites[idx]
	return null

func get_yield() -> int:
	"""Roll a random harvest yield."""
	return randi_range(min_yield, max_yield)
