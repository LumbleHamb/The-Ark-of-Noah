class_name LightSourceComponent
extends Component

## Attach to any light-emitting object (torch, lamp, campfire).
## Registers with LightingManager and controls PointLight2D by time-of-day.

@export var flame_sprite: AnimatedSprite2D = null
@export var base_energy: float = 1.0
@export var auto_light: bool = true

var _lighting_manager: LightingManager = null
var _cached_lights: Array[PointLight2D] = []
var _is_lit: bool = false

func _component_ready() -> void:
	get_parent().add_to_group(&"light_source")

	_find_lights()

	for light: PointLight2D in _cached_lights:
		if is_instance_valid(light):
			light.set_meta(&"base_energy", base_energy)
			light.enabled = false

	# Make sure the sprite is visible and playing.
	if flame_sprite and is_instance_valid(flame_sprite):
		flame_sprite.visible = true
		if not flame_sprite.is_playing():
			flame_sprite.play()

	_lighting_manager = _find_lighting_manager()
	if _lighting_manager:
		_lighting_manager.register_light_source(get_parent())

	_set_lit(false)

func _exit_tree() -> void:
	if _lighting_manager and is_instance_valid(_lighting_manager):
		_lighting_manager.unregister_light_source(get_parent())

## Called by LightingManager to turn the light on (night) or off (day).
func set_lit(lit: bool) -> void:
	if lit == _is_lit:
		return

	_is_lit = lit
	_set_lit(lit)

func is_lit() -> bool:
	return _is_lit

func _set_lit(lit: bool) -> void:
	if not auto_light:
		return

	# ONLY control the PointLight2D.
	for light: PointLight2D in _cached_lights:
		if is_instance_valid(light):
			light.enabled = lit

func _find_lights() -> void:
	_cached_lights.clear()

	var parent: Node = get_parent()
	if not parent:
		return

	for child: Node in parent.get_children():
		if child is PointLight2D:
			_cached_lights.append(child)

func _find_lighting_manager() -> LightingManager:
	var lm: LightingManager = get_tree().get_first_node_in_group(&"lighting_manager")
	if lm == null:
		lm = get_tree().root.find_child("LightingManager", true, false) as LightingManager

	return lm
