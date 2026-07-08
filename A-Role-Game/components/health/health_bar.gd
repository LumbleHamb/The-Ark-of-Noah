extends CanvasLayer
class_name HealthBar

## HUD element that shows the player's current health as a filled bar.
##
## Must be a child of the Player node. Automatically finds the
## HealthComponent sibling and listens for health_changed signals.
##
## Uses UI textures from the Sliders & Bars folder for the box background
## and fill bar. The fill bar's width shrinks/grows with health level,
## and its color shifts from green → orange → red as health drops.

@export var bar_width: float = 240.0
@export var bar_height: float = 32.0
@export var fill_color: Color = Color(0.25, 0.8, 0.2, 1.0)  # green (high health)
@export var mid_color: Color = Color(0.9, 0.6, 0.1, 1.0)  # orange (mid health)
@export var empty_color: Color = Color(0.8, 0.15, 0.15, 1.0)  # red (low health)
@export var low_health_ratio: float = 0.3  # below this → red
@export var mid_health_ratio: float = 0.6  # below this → orange, above → green

@onready var box_bg: TextureRect = $BoxBg
@onready var fill_bar: TextureRect = $FillBar

var _health: HealthComponent = null
var _fill_max_width: float = 0.0


func _ready() -> void:
	var player := get_parent()
	if player:
		_health = player.get_node_or_null("HealthComponent") as HealthComponent

	if _health:
		_health.health_changed.connect(_on_health_changed)
		_on_health_changed(_health.get_hp(), _health.get_hp())

	# Calculate the maximum fill width (interior of the box with 4px margins)
	box_bg.custom_minimum_size = Vector2(bar_width, bar_height)
	_fill_max_width = bar_width - 8.0  # leave 4px margin on each side

	# Wait one frame so node sizes resolve
	await get_tree().process_frame
	_refresh_fill()


func _on_health_changed(_old: int, _new: int) -> void:
	_refresh_fill()


func _refresh_fill() -> void:
	if not _health or not is_inside_tree():
		return

	var ratio: float = _health.get_hp_ratio()
	var fill_w: float = _fill_max_width * ratio
	fill_bar.size.x = maxf(fill_w, 0.0)

	# Update color based on health level
	if ratio <= 0.001:
		fill_bar.modulate = empty_color
	elif ratio <= low_health_ratio:
		fill_bar.modulate = empty_color
	elif ratio <= mid_health_ratio:
		fill_bar.modulate = mid_color
	else:
		fill_bar.modulate = fill_color
