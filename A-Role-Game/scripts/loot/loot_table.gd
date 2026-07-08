class_name LootTable
extends Resource

@export var table_id: String = ""
@export var entries: Array[LootEntry] = []
@export var rolls_min: int = 0
@export var rolls_max: int = 1

func get_roll_count(rng: RandomNumberGenerator) -> int:
	var low: int = mini(rolls_min, rolls_max)
	var high: int = maxi(rolls_min, rolls_max)
	return rng.randi_range(low, high)
