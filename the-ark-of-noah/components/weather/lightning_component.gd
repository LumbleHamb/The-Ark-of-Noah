class_name LightningComponent
extends Component

## ============================================================================
## LIGHTNING COMPONENT — Handles lightning flash visuals.
##
## Listens to the WeatherManager's `lightning_strike` signal and produces a
## brief screen flash that temporarily overrides darkness. The flash uses a
## full-screen ColorRect overlay (added to the component's entity, which should
## be a CanvasLayer or a high-z-index Node2D for screen-wide coverage).
##
## Randomised per strike: brightness, duration. Position randomisation is
## represented by the bolt sprite's offset (optional). The component also pokes
## the LightingManager to briefly brighten ambient for the strike duration.
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
## Optional lightning bolt sprite shown at the strike location.
@export var bolt_texture: Texture2D = preload("res://assets/generated/lightning_bolt_frame_0.png")

## Flash overlay colour.
@export var flash_color: Color = Color(1.0, 1.0, 0.95, 1.0)

## Maximum flash overlay alpha at full brightness.
@export_range(0.0, 1.0, 0.01) var max_flash_alpha: float = 0.7

## Whether to show the jagged bolt sprite at a random horizontal position.
@export var show_bolt_sprite: bool = true

## Bolt sprite vertical span (pixels) at the strike position.
@export_range(50, 500, 10) var bolt_height: float = 300.0

## If true, briefly brighten the LightingManager ambient during the flash.
@export var brighten_ambient: bool = true

## How much to boost ambient brightness during a flash (0..1).
@export_range(0.0, 1.0, 0.01) var ambient_boost: float = 0.6

# ============================================================================
# STATE
# ============================================================================
var _weather_manager: WeatherManager = null
var _lighting_manager: LightingManager = null
var _flash_rect: ColorRect = null
var _bolt_sprite: Sprite2D = null
var _active_tween: Tween = null

func _component_ready() -> void:
	_build_flash_overlay()
	_build_bolt_sprite()
	_weather_manager = _find_weather_manager()
	_lighting_manager = _find_lighting_manager()
	if _weather_manager:
		_weather_manager.lightning_strike.connect(_on_lightning_strike)

func _process(_delta: float) -> void:
	if _weather_manager == null:
		_weather_manager = _find_weather_manager()
		if _weather_manager:
			_weather_manager.lightning_strike.connect(_on_lightning_strike)

# ============================================================================
# FLASH
# ============================================================================
func _on_lightning_strike(brightness: float, duration: float) -> void:
	if _flash_rect:
		_flash_rect.color.a = brightness * max_flash_alpha
		_flash_rect.show()
		# Fade out over the strike duration (+ a little tail for double-strike feel).
		if _active_tween and is_instance_valid(_active_tween):
			_active_tween.kill()
		_active_tween = create_tween()
		_active_tween.tween_property(_flash_rect, "color:a", 0.0, duration + 0.15)
		_active_tween.tween_callback(_flash_rect.hide)
	
	# Optional bolt sprite at a random horizontal position.
	if show_bolt_sprite and _bolt_sprite:
		_bolt_sprite.position.x = randf_range(-300.0, 300.0)
		_bolt_sprite.scale.y = bolt_height / 128.0 * (0.7 + brightness * 0.5)
		_bolt_sprite.modulate.a = brightness
		_bolt_sprite.show()
		if _active_tween and is_instance_valid(_active_tween):
			_active_tween.parallel().tween_property(_bolt_sprite, "modulate:a", 0.0, duration)
		else:
			_active_tween = create_tween()
			_active_tween.tween_property(_bolt_sprite, "modulate:a", 0.0, duration)
			_active_tween.tween_callback(_bolt_sprite.hide)
	
	# Brief ambient brightening.
	if brighten_ambient and _lighting_manager:
		_ambient_flash(duration)

func _ambient_flash(duration: float) -> void:
	# We can't easily tween the LightingManager's internal modulate without
	# reaching into it, so we use the night_darkness setter as a proxy: drop
	# darkness briefly (brighter) then restore. This is a gentle nudge.
	var original: float = _lighting_manager.night_darkness
	if _active_tween and is_instance_valid(_active_tween):
		_active_tween.parallel().tween_method(
			func(v: float) -> void:
				if _lighting_manager and is_instance_valid(_lighting_manager):
					_lighting_manager.night_darkness = v,
			maxf(0.1, original - ambient_boost), original, duration + 0.2)

# ============================================================================
# OVERLAY CONSTRUCTION
# ============================================================================
func _build_flash_overlay() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.name = "LightningFlash"
	_flash_rect.color = flash_color
	_flash_rect.color.a = 0.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.show_behind_parent = false
	# Full-screen anchors.
	_flash_rect.anchor_right = 1.0
	_flash_rect.anchor_bottom = 1.0
	_flash_rect.offset_right = 0.0
	_flash_rect.offset_bottom = 0.0
	_flash_rect.visible = false
	# Add to the entity. If the entity is a CanvasLayer this is screen-space.
	# Deferred because the parent may still be setting up children.
	var entity: Node = get_entity()
	if entity:
		entity.add_child.call_deferred(_flash_rect)
	else:
		add_child.call_deferred(_flash_rect)

func _build_bolt_sprite() -> void:
	if not show_bolt_sprite:
		return
	_bolt_sprite = Sprite2D.new()
	_bolt_sprite.name = "LightningBolt"
	_bolt_sprite.texture = bolt_texture
	_bolt_sprite.z_index = 100
	_bolt_sprite.visible = false
	_bolt_sprite.centered = true
	_bolt_sprite.position = Vector2(0, -150)
	var entity: Node = get_entity()
	if entity and entity is Node2D:
		(entity as Node2D).add_child.call_deferred(_bolt_sprite)
	elif entity:
		entity.add_child.call_deferred(_bolt_sprite)
	else:
		add_child.call_deferred(_bolt_sprite)

# ============================================================================
# HELPERS
# ============================================================================
func _find_weather_manager() -> WeatherManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager

func _find_lighting_manager() -> LightingManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"lighting_manager") as LightingManager
