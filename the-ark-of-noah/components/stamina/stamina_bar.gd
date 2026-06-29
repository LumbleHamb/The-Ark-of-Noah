extends CanvasLayer
class_name StaminaBar

## HUD element that shows the player's current stamina as a filled bar.
##
## Must be a child of the Player node. Automatically finds the
## StaminaComponent sibling and listens for stamina_changed signals.
##
## Uses UI textures from the Sliders & Bars folder for the box background
## and fill bar. The fill bar's width shrinks/grows with stamina level,
## and its color shifts from green → orange → red as stamina drops.

@export var bar_width: float = 240.0
@export var bar_height: float = 26.0
@export var fill_color: Color = Color(0.25, 0.8, 0.2, 1.0)  # green
@export var empty_color: Color = Color(0.6, 0.1, 0.1, 1.0)  # red when empty
@export var low_stamina_ratio: float = 0.25  # below this the bar turns the empty color
@export var low_stamina_color: Color = Color(0.9, 0.6, 0.1, 1.0)  # orange when low

@onready var box_bg: TextureRect = $BoxBg
@onready var fill_bar: TextureRect = $FillBar

var _stamina: StaminaComponent = null
var _fill_max_width: float = 0.0


func _ready() -> void:
	var player := get_parent()
	if player:
		_stamina = player.get_node_or_null("StaminaComponent") as StaminaComponent

	if _stamina:
		_stamina.stamina_changed.connect(_on_stamina_changed)
		_on_stamina_changed(_stamina.current_stamina, _stamina.max_stamina)

	# Calculate the maximum fill width (interior of the box with 4px margins)
	box_bg.custom_minimum_size = Vector2(bar_width, bar_height)
	_fill_max_width = bar_width - 8.0  # leave 4px margin on each side

	# Wait one frame so node sizes resolve
	await get_tree().process_frame
	_refresh_fill()


func _on_stamina_changed(_current: float, _max_val: float) -> void:
	_refresh_fill()


func _refresh_fill() -> void:
	if not _stamina or not is_inside_tree():
		return

	var ratio: float = _stamina.get_stamina_ratio()
	var fill_w: float = _fill_max_width * ratio
	fill_bar.size.x = maxf(fill_w, 0.0)

	# Update color based on stamina level
	if ratio <= 0.001:
		fill_bar.modulate = empty_color
	elif ratio <= low_stamina_ratio:
		fill_bar.modulate = low_stamina_color
	else:
		fill_bar.modulate = fill_color
