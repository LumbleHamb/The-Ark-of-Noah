class_name CropData
extends Resource

## Data-driven crop definition used by the farming rewrite.
## WHY: adding a crop should be resource-only, with no code changes.

@export var crop_name: String = ""
@export var growth_stages: int = 4
@export var growth_days: int = 4
@export var stage_sprites: Array[Texture2D] = []

@export var harvest_item_id: String = ""
@export var harvest_item_name: String = ""
@export var harvest_amount: int = 1
@export var harvest_icon: Texture2D = null

@export var regrowable: bool = false
@export var regrow_days: int = 2

@export var seed_sprite: Texture2D = null
@export var seed_tile_coords: Vector2i = Vector2i.ZERO

## Legacy compatibility fields kept so old .tres assets still load.
@export var min_yield: int = 1
@export var max_yield: int = 1
@export var harvest_sprite: Texture2D = null

func get_growth_days() -> int:
	return maxi(growth_days, 1)

func get_growth_stage_count() -> int:
	if stage_sprites.size() > 0:
		return stage_sprites.size()
	return maxi(growth_stages, 1)

func get_stage_sprite(stage: int) -> Texture2D:
	if stage_sprites.is_empty():
		return seed_sprite
	var max_index: int = stage_sprites.size() - 1
	var clamped: int = clampi(stage, 0, max_index)
	return stage_sprites[clamped]

func is_regrowable() -> bool:
	return regrowable

func get_regrow_days() -> int:
	return maxi(regrow_days, 1)

func get_harvest_amount() -> int:
	if harvest_amount > 0:
		return harvest_amount
	return maxi(randi_range(min_yield, max_yield), 1)

func get_harvest_item_id() -> String:
	if harvest_item_id != "":
		return harvest_item_id
	if harvest_item_name != "":
		return harvest_item_name.to_lower().replace(" ", "_")
	return crop_name.to_lower().replace(" ", "_")

func get_harvest_display_name() -> String:
	if harvest_item_name != "":
		return harvest_item_name
	return crop_name

func get_harvest_icon() -> Texture2D:
	if harvest_icon != null:
		return harvest_icon
	if harvest_sprite != null:
		return harvest_sprite
	if seed_sprite != null:
		return seed_sprite
	return get_stage_sprite(get_growth_stage_count() - 1)
