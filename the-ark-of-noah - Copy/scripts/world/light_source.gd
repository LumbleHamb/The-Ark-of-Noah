class_name LightSource
extends Node

## Attach as a child of any torch, lamp, campfire, or light-emitting object.
## Automatically registers the parent node as a light source with the
## LightingManager and controls AnimatedSprite2D animations based on
## time-of-day.
##
## Usage:
##   1. Add a PointLight2D child to the SAME parent node (alongside this script).
##   2. Add this script to a child node named "LightSource" under the parent.
##   3. Optionally assign an AnimatedSprite2D for the flame/fire visual.
##   4. Optionally assign a shadow sprite (unlit version for daytime).
##   5. The LightingManager will auto-enable/disable the PointLight2D
##      and call set_lit() to control animations.
##
## Inspector setup:
##   - flame_sprite: drag the AnimatedSprite2D for the fire/flame visual
##   - lit_animation: name of the animation to play when night (e.g. "fire")
##   - base_energy: brightness of the PointLight2D child

# ============================================================================
# EXPORTS
# ============================================================================
## Optional animated sprite for the flame/fire visual.
@export var flame_sprite: AnimatedSprite2D = null

## Animation name to play when lit (night). If empty, sprite just shows.
@export var lit_animation: String = ""

## Optional animation name for daytime (e.g. smouldering / idle).
## If blank, the sprite is hidden during daytime.
@export var unlit_animation: String = ""

## Base light energy (stored so flicker can modulate around it).
@export var base_energy: float = 1.0

## If true, this light source operates automatically by time of day.
## Set false for player-controlled lights.
@export var auto_light: bool = true

# ============================================================================
# STATE
# ============================================================================
var _lighting_manager: LightingManager = null
var _cached_lights: Array[PointLight2D] = []
var _is_lit: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	# Put the parent node into the light_source group so LightingManager
	# can discover it and find this component as a child named "LightSource".
	get_parent().add_to_group(&"light_source")
	
	# Cache our PointLight2D siblings and set base energy metadata.
	_find_lights()
	for light in _cached_lights:
		if is_instance_valid(light):
			light.set_meta(&"base_energy", base_energy)
			light.enabled = false  # Start off; LightingManager controls this
	
	# Register with LightingManager.
	_lighting_manager = _find_lighting_manager()
	if _lighting_manager:
		_lighting_manager.register_light_source(get_parent())
	
	# Initial visibility (assuming daytime start).
	_set_lit(false)

func _exit_tree() -> void:
	if _lighting_manager and is_instance_valid(_lighting_manager):
		_lighting_manager.unregister_light_source(get_parent())

# ============================================================================
# PUBLIC API
# ============================================================================
## Called by LightingManager to turn this light on/off.
func set_lit(lit: bool) -> void:
	if lit == _is_lit:
		return
	_is_lit = lit
	_set_lit(lit)

## Returns whether this light is currently emitting.
func is_lit() -> bool:
	return _is_lit

# ============================================================================
# INTERNAL
# ============================================================================
func _set_lit(lit: bool) -> void:
	# Skip animation control if manual mode is needed.
	if not auto_light:
		return
	
	if flame_sprite and is_instance_valid(flame_sprite):
		if lit:
			flame_sprite.visible = true
			if lit_animation != "":
				flame_sprite.play(lit_animation)
		else:
			if unlit_animation != "":
				flame_sprite.visible = true
				flame_sprite.play(unlit_animation)
			else:
				flame_sprite.visible = false
				flame_sprite.stop()

func _find_lights() -> void:
	_cached_lights.clear()
	var parent: Node = get_parent()
	if not parent:
		return
	for child in parent.get_children():
		if child is PointLight2D:
			_cached_lights.append(child)

func _find_lighting_manager() -> LightingManager:
	var lm: LightingManager = get_tree().get_first_node_in_group(&"lighting_manager")
	if lm == null:
		lm = get_tree().root.find_child("LightingManager", true, false) as LightingManager
	return lm
