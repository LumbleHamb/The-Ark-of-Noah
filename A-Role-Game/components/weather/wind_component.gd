class_name WindComponent
extends Component

## ============================================================================
## WIND COMPONENT — Reusable wind receiver.
##
## Drop onto any object that should react to global wind: tree-top TileMapLayers,
## grass sprites, particle emitters, or any Node2D that opts into wind.
##
## The component reads wind data from the WeatherManager singleton each frame
## (cheap polling — no signal-per-frame spam) and applies motion via one of
## three modes selected by `wind_target`:
##
##   TILEMAP_LAYER — sways a TileMapLayer by modulating its modulate + a subtle
##                   position shimmer. (Used by tree-top canopy layers.)
##   SPRITE        — applies a periodic sway offset to a Sprite2D / AnimatedSprite2D
##                   (rotation + position oscillation). Good for grass, banners.
##   PARTICLES     — pushes a GPUParticles2D's process-material direction with
##                   the wind vector, so rain/leaf particles drift.
##
## Wind data (strength, direction, gust) comes entirely from WeatherManager.
## Designers only choose the target + how much sway to apply. No per-tree
## scripting — add this component to a tree-top layer and it just works.
## ============================================================================

enum WindTarget { TILEMAP_LAYER, SPRITE, PARTICLES }

# ============================================================================
# EXPORTS
# ============================================================================
## Which kind of node this component drives.
@export var wind_target: WindTarget = WindTarget.TILEMAP_LAYER

## Path to the node this component sways. If empty, the component tries:
##   - TILEMAP_LAYER: a child named "TreeTops" or the entity's first TileMapLayer
##   - SPRITE: the entity's first Sprite2D/AnimatedSprite2D child
##   - PARTICLES: the entity's first GPUParticles2D child
@export var target_path: NodePath = NodePath("")

## Maximum sway amplitude in pixels (SPRITE) or modulate shift (TILEMAP_LAYER).
@export_range(0.0, 20.0, 0.1) var sway_amplitude: float = 3.0

## Sway frequency (oscillations per second).
@export_range(0.0, 5.0, 0.01) var sway_frequency: float = 1.5

## How strongly wind direction rotates the sprite (radians at full wind).
@export_range(0.0, 0.5, 0.01) var rotation_strength: float = 0.05

## If true, gusts produce a visible extra kick (only for SPRITE/PARTICLES).
@export var react_to_gusts: bool = true

# ============================================================================
# STATE
# ============================================================================
var _weather_manager: WeatherManager = null
var _target_node: Node = null
var _time: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_modulate: Color = Color.WHITE

func _component_ready() -> void:
	# Resolve the target node.
	if target_path != NodePath(""):
		_target_node = get_node_or_null(target_path)
		if _target_node == null and get_parent() != null:
			_target_node = get_parent().get_node_or_null(target_path)
	if _target_node == null:
		_target_node = _auto_resolve_target()
	# Fallback: common leaves setup has AnimatedSprite2D named "leaves_animation"
	# as a sibling of WindComponent under the same parent node.
	if _target_node == null and wind_target == WindTarget.SPRITE and get_parent() != null:
		_target_node = get_parent().get_node_or_null("leaves_animation")
	
	if _target_node is Node2D:
		_base_position = (_target_node as Node2D).position
		_base_rotation = (_target_node as Node2D).rotation
	if _target_node is CanvasItem:
		_base_modulate = (_target_node as CanvasItem).modulate
	
	# Find the weather manager (autoload singleton).
	_weather_manager = _find_weather_manager()

func _process(delta: float) -> void:
	if _weather_manager == null:
		_weather_manager = _find_weather_manager()
		if _weather_manager == null:
			return
	if _target_node == null or not is_instance_valid(_target_node):
		return
	
	_time += delta
	var strength: float = _weather_manager.get_wind_strength()
	var direction: float = _weather_manager.get_wind_direction()
	var gust: float = _weather_manager.get_wind_gust() if react_to_gusts else 0.0
	var storm_intensity: float = _weather_manager.get_storm_intensity() if _weather_manager.has_method("get_storm_intensity") else 0.0
	var effective: float = clampf(strength + gust * 0.3 + storm_intensity * 0.35, 0.0, 1.8)
	
	match wind_target:
		WindTarget.TILEMAP_LAYER:
			_apply_tilemap(effective, direction)
		WindTarget.SPRITE:
			_apply_sprite(effective, direction, gust)
		WindTarget.PARTICLES:
			_apply_particles(effective, direction)

# ============================================================================
# APPLY MODES
# ============================================================================
func _apply_tilemap(strength: float, _direction: float) -> void:
	var layer: TileMapLayer = _target_node as TileMapLayer
	if layer == null:
		return
	# Subtle horizontal shimmer via position + a wind-tinted modulate.
	var sway: float = sin(_time * sway_frequency) * sway_amplitude * strength
	layer.position.x = _base_position.x + sway
	# Wind tint: leaves get slightly desaturated/darkened in strong wind.
	var tint: Color = _base_modulate.lerp(Color(0.85, 0.9, 0.75, 1.0), strength * 0.4)
	layer.modulate = tint

func _apply_sprite(strength: float, _direction: float, gust: float) -> void:
	var sprite: Node2D = _target_node as Node2D
	if sprite == null:
		return
	# Sway position + rotation oscillation.
	var sway: float = sin(_time * sway_frequency) * sway_amplitude * strength
	sprite.position.x = _base_position.x + sway
	# Gusts add a quick rotational kick.
	var gust_kick: float = gust * rotation_strength * 2.0
	sprite.rotation = _base_rotation + sin(_time * sway_frequency * 0.7) * rotation_strength * strength + gust_kick

func _apply_particles(strength: float, direction: float) -> void:
	var particles: GPUParticles2D = _target_node as GPUParticles2D
	if particles == null or particles.process_material == null:
		return
	# Push the process material's direction with wind. We use the
	# ParticleProcessMaterial's directional velocity (direction + spread).
	var mat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	# Wind direction is in radians; convert to a Vector2 direction vector.
	var dir_vec: Vector2 = Vector2.from_angle(direction + PI / 2.0)  # bias downward
	# Scale by wind strength. Base gravity stays; wind adds horizontal drift.
	mat.direction = Vector3(dir_vec.x, 1.0, 0.0)  # keep downward gravity, add wind x
	# Modulate initial velocity by wind via the param API.
	mat.set_param_min(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, clampf(strength * 100.0, 0.0, 200.0))
	mat.set_param_max(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, clampf(strength * 100.0, 0.0, 200.0))

# ============================================================================
# HELPERS
# ============================================================================
func _auto_resolve_target() -> Node:
	var entity: Node = get_entity()
	if entity == null:
		return null
	match wind_target:
		WindTarget.TILEMAP_LAYER:
			var t: Node = entity.get_node_or_null("TreeTops")
			if t is TileMapLayer:
				return t
			for child in entity.get_children():
				if child is TileMapLayer:
					return child
		WindTarget.SPRITE:
			for child in entity.get_children():
				if child is Sprite2D or child is AnimatedSprite2D:
					return child
		WindTarget.PARTICLES:
			for child in entity.get_children():
				if child is GPUParticles2D:
					return child
	return null

func _find_weather_manager() -> WeatherManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager
