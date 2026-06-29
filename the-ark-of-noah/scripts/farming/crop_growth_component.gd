class_name FarmCropGrowthMath
extends Node

## Stateless crop-growth helper used by FarmManager.
##
## Why this exists:
## - Keeps growth math isolated from map/interaction code.
## - Makes crop progression reusable for future greenhouse/planter systems.

func get_expected_stage(days_elapsed: int, growth_days: int, growth_stages: int) -> int:
	var safe_days: int = maxi(1, growth_days)
	var safe_stages: int = maxi(1, growth_stages)
	var progressed: int = int(floor(float(days_elapsed) * float(safe_stages) / float(safe_days)))
	return clampi(progressed, 0, safe_stages - 1)

func is_harvestable(stage: int, growth_stages: int) -> bool:
	var last_stage: int = maxi(0, growth_stages - 1)
	return stage >= last_stage
