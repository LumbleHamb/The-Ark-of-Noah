class_name LootEntry
extends Resource

@export var item_id: String = ""
@export_range(0.0, 1.0, 0.001) var chance: float = 1.0
@export var weight: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export var guaranteed: bool = false
@export var rare_tier: int = 0

func roll_quantity(rng: RandomNumberGenerator) -> int:
	var low: int = mini(min_quantity, max_quantity)
	var high: int = maxi(min_quantity, max_quantity)
	return rng.randi_range(low, high)
