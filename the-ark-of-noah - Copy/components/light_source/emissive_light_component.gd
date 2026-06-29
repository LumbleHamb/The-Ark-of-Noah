class_name EmissiveLightComponent
extends Component

## All-in-one drop-in light emitter for any sprite that should glow at night.
##
## Unlike the bare LightSourceComponent (which only registers the parent with
## the LightingManager and requires a separate PointLight2D sibling), this
## component OWNS its own PointLight2D child configured in the Inspector.
##
## Usage:
##   1. Drop the EmissiveLightComponent scene as a child of any decor sprite
##      (lamp, campfire, torch, lantern, glowing crystal, etc.).
##   2. In the Inspector set: light_color, light_energy, light_scale, offset.
##   3. Optionally wire flame_sprite + lit_animation for an animated flame.
##   4. The LightingManager will auto-discover this via the "light_source"
##      group and switch the light on at dusk / off at sunrise.
##
## This makes adding a new light-emitting object a single drag-and-drop — no
## manual PointLight2D creation, no group setup, no LightingManager wiring.

# ============================================================================
# EXPORTS — designer-facing configuration
# ============================================================================
## Colour of the emitted light (warm orange for fire, cool blue for magic, etc.).
@export var light_color: Color = Color(1.0, 0.82, 0.5, 1.0)

## Base brightness of the light. LightingManager multiplies this by its
## global light_energy_multiplier and a deep-night boost at runtime.
@export_range(0.0, 5.0, 0.05) var light_energy: float = 1.5

## Size of the light texture (radius).  LightingManager applies a global
## light_scale_multiplier on top of this.
@export_range(0.1, 10.0, 0.1) var light_scale: float = 3.0

## Pixel offset of the light from the parent's origin.
@export var light_offset: Vector2 = Vector2.ZERO

## If true the light casts shadows (slightly more expensive; good for
## campfires/lamps near walls, off for tiny decorative glows).
@export var shadow_enabled: bool = true

## Optional animated sprite for the flame/fire visual (played when lit).
@export var flame_sprite: AnimatedSprite2D = null

## Animation name to play when lit (night).  Empty = no animation.
@export var lit_animation: String = ""

## Optional animation name for daytime (smouldering / idle).  Empty = hide.
@export var unlit_animation: String = ""

## If true, this light operates automatically by time of day (on at dusk,
## off at dawn).  Set false for script-controlled lights.
@export var auto_light: bool = true

# ============================================================================
# INTERNAL
# ============================================================================
var _point_light: PointLight2D = null
var _inner_source: LightSourceComponent = null
var _glow_texture: Texture2D = preload("res://images/generated/light_glow_256.png")

# ============================================================================
# LIFECYCLE
# ============================================================================
func _component_ready() -> void:
	# Build our own PointLight2D so the designer doesn't have to.
	_point_light = PointLight2D.new()
	_point_light.name = "PointLight2D"
	_point_light.color = light_color
	_point_light.energy = light_energy
	_point_light.texture = _glow_texture
	_point_light.texture_scale = light_scale
	_point_light.position = light_offset
	_point_light.shadow_enabled = shadow_enabled
	_point_light.shadow_color = Color(0, 0, 0, 0.8)
	_point_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_point_light.shadow_filter_smooth = 4.0
	_point_light.enabled = false  # LightingManager controls on/off
	# Store base metadata so LightingManager flicker/boost can read it back.
	_point_light.set_meta(&"base_energy", light_energy)
	_point_light.set_meta(&"base_texture_scale", light_scale)
	add_child(_point_light)

	# Use the existing LightSourceComponent to do the group registration +
	# animation control.  We hand it our flame sprite config and base_energy
	# so it mirrors what a manually-placed component would do.
	_inner_source = LightSourceComponent.new()
	_inner_source.name = "LightSource"
	_inner_source.flame_sprite = flame_sprite
	_inner_source.lit_animation = lit_animation
	_inner_source.unlit_animation = unlit_animation
	_inner_source.base_energy = light_energy
	_inner_source.auto_light = auto_light
	# The LightSourceComponent expects PointLight2D siblings of its parent
	# (this node).  Our _point_light is a child of this node, so the
	# component's _find_lights() (which scans get_parent().get_children())
	# will find it because _inner_source's parent is this node and
	# _point_light is a child of this node too — i.e. a sibling of _inner_source.
	add_child(_inner_source)

# ============================================================================
# PUBLIC API
# ============================================================================
## Called by LightingManager (forwarded through LightSourceComponent).
func set_lit(lit: bool) -> void:
	if _inner_source and is_instance_valid(_inner_source):
		_inner_source.set_lit(lit)

func is_lit() -> bool:
	if _inner_source and is_instance_valid(_inner_source):
		return _inner_source.is_lit()
	return false

## Change the light colour at runtime (e.g. weather can tint a lamp blue).
func set_light_color(color: Color) -> void:
	light_color = color
	if _point_light and is_instance_valid(_point_light):
		_point_light.color = color

## Change the light energy at runtime.
func set_light_energy(energy: float) -> void:
	light_energy = energy
	if _point_light and is_instance_valid(_point_light):
		_point_light.set_meta(&"base_energy", energy)
