class_name CropGrowthTileComponent
extends Component

## Reusable crop growth logic for one planted crop instance.
## WHY: keeps FarmManager focused on tile-state/rules while this component owns
## day progression, stage visuals, and harvest readiness per crop.

signal stage_changed(new_stage: int)
signal became_harvestable()

@export var sprite_path: NodePath = NodePath("../Sprite2D")

var crop_data: CropData = null
var planted_day: int = 0
var growth_stage: int = 0
var harvestable: bool = false

var _sprite: Sprite2D = null

func _component_ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_apply_visual()

func initialize(data: CropData, day_planted: int, stage: int = 0, is_harvestable: bool = false) -> void:
	crop_data = data
	planted_day = day_planted
	growth_stage = maxi(stage, 0)
	harvestable = is_harvestable
	_apply_visual()

func advance_to_day(current_day: int) -> void:
	if crop_data == null:
		return
	if harvestable:
		return
	var stage_count: int = crop_data.get_growth_stage_count()
	if stage_count <= 0:
		return
	var elapsed_days: int = maxi(current_day - planted_day, 0)
	var target_stage: int = mini(stage_count - 1, int(floor(float(elapsed_days * stage_count) / maxf(float(crop_data.get_growth_days()), 1.0))))
	if target_stage > growth_stage:
		growth_stage = target_stage
		stage_changed.emit(growth_stage)
		_apply_visual()
	if growth_stage >= stage_count - 1:
		harvestable = true
		became_harvestable.emit()

func consume_harvest(current_day: int) -> void:
	if crop_data == null:
		return
	if crop_data.is_regrowable():
		planted_day = current_day - max(crop_data.get_growth_days() - crop_data.get_regrow_days(), 0)
		harvestable = false
		growth_stage = maxi(crop_data.get_growth_stage_count() - 2, 0)
		_apply_visual()

func _apply_visual() -> void:
	if _sprite == null:
		_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		return
	if crop_data == null:
		_sprite.texture = null
		return
	_sprite.texture = crop_data.get_stage_sprite(growth_stage)
