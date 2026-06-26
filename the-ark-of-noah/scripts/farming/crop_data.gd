class_name CropData
extends Resource

## Data-driven crop definition. Create a .tres file from this template to add new crops.


@export var crop_name: String = ""
@export var growth_stages: int = 8
@export var growth_days: int = 3
@export var min_yield: int = 1
@export var max_yield: int = 1
@export var regrowable: bool = false
@export var regrow_days: int = 1
@export var stage_sprites: Array[Texture2D] = []
@export var seed_sprite: Texture2D = null
@export var harvest_sprite: Texture2D = null
@export var harvest_item_name: String = ""
@export var seed_tile_coords: Vector2i = Vector2i.ZERO

## Returns the sprite for a given 0-based growth stage, clamped to valid range.
func get_stage_sprite(stage: int) -> Texture2D:
	var idx: int = clampi(stage, 0, stage_sprites.size() - 1)
	if idx < stage_sprites.size():
		return stage_sprites[idx]
	return null

## Rolls a random harvest yield between min and max.
func get_yield() -> int:
	return randi_range(min_yield, max_yield)
