class_name RainComponent
extends Component

## ============================================================================
## RAIN COMPONENT — Reusable rain particle system.
##
## Drop onto a Node2D (typically a child of the world root or a weather layer).
## Reads rain intensity from the WeatherManager and smoothly ramps a
## GPUParticles2D emitter up/down. Supports light rain, heavy rain, and storm
## rain via the `intensity` value (0..1).
##
## The emitter is created procedurally so the component is fully self-contained
## — no external scene dependency. It uses the generated rain_drop texture.
##
## Future optimisation hooks:
##   - `max_particles` caps the emitter so it scales across devices.
##   - `follow_target` lets the rain follow the player so only screen-area rain
##     is simulated (huge perf win for large worlds).
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
## Raindrop sprite texture. Defaults to the generated asset.
@export var drop_texture: Texture2D = preload("res://assets/generated/rain_drop_frame_0.png")

## Maximum particle count at full intensity. Scale down for low-end devices.
@export_range(50, 2000, 10) var max_particles: int = 600

## Area (in pixels) the rain emitter covers. Rain falls within this box.
@export var rain_area: Vector2 = Vector2(1920, 1080)

## Optional Node2D the rain follows (keeps rain only around the player).
## If set, the component repositions itself to track this node each frame.
@export var follow_target: Node2D = null

## If following, only emit within this radius (pixels) of the target.
@export_range(100, 2000, 10) var follow_radius: float = 700.0

## Base fall speed of raindrops (px/s).
@export_range(50, 1000, 10) var fall_speed: float = 400.0

## How much wind tilts the rain (0 = vertical, 1 = strongly tilted).
@export_range(0.0, 1.0, 0.01) var wind_tilt: float = 0.6

# ============================================================================
# STATE
# ============================================================================
var _weather_manager: WeatherManager = null
var _particles: GPUParticles2D = null
var _process_mat: ParticleProcessMaterial = null
var _display_intensity: float = 0.0

func _component_ready() -> void:
	_build_emitter()
	_weather_manager = _find_weather_manager()
	# Start invisible until rain comes.
	if _particles:
		_particles.emitting = false

func _process(delta: float) -> void:
	if _weather_manager == null:
		_weather_manager = _find_weather_manager()
		if _weather_manager == null:
			return
	
	# Smoothly follow target if set (perf optimisation).
	if follow_target and is_instance_valid(follow_target) and _particles:
		_particles.global_position = follow_target.global_position
	
	# Read target intensity from manager and smooth toward it.
	var target: float = _weather_manager.get_rain_intensity()
	_display_intensity = lerpf(_display_intensity, target, clampf(delta * 3.0, 0.0, 1.0))
	
	if _particles == null:
		return
	
	# Toggle emission + scale amount with intensity.
	if _display_intensity > 0.02:
		_particles.emitting = true
		# Scale particle count with intensity (pooled — Godot handles the pool).
		_particles.amount = int(lerpf(10.0, float(max_particles), _display_intensity))
		# Apply wind tilt to the process material direction.
		_apply_wind_tilt()
	else:
		_particles.emitting = false

# ============================================================================
# EMITTER CONSTRUCTION
# ============================================================================
func _build_emitter() -> void:
	_particles = GPUParticles2D.new()
	_particles.name = "RainEmitter"
	_particles.amount = 50
	_particles.lifetime = 2.0
	_particles.local_coords = false
	_particles.texture = drop_texture
	
	# Process material: gravity pulls down, wind adds horizontal drift.
	_process_mat = ParticleProcessMaterial.new()
	_process_mat.particle_flag_disable_z = true
	_process_mat.gravity = Vector3(0.0, fall_speed * 0.5, 0.0)
	_process_mat.direction = Vector3(0.0, 1.0, 0.0)
	_process_mat.spread = 5.0
	# Velocity via the param_min/max API (no direct property in 4.7).
	# A min/max range creates natural speed variation.
	_process_mat.set_param_min(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, fall_speed * 0.8)
	_process_mat.set_param_max(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, fall_speed * 1.2)
	# Emission shape: a box covering the rain area.
	_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_mat.emission_box_extents = Vector3(rain_area.x * 0.5, rain_area.y * 0.5, 0.0)
	_particles.process_material = _process_mat
	
	# Render above most world content but below UI.
	_particles.z_index = 50
	
	# Add as a child of this component's entity (so it inherits positioning).
	# Deferred because the parent may still be setting up children.
	var entity: Node2D = get_entity() as Node2D
	if entity:
		_particles.position = Vector2.ZERO
		entity.add_child.call_deferred(_particles)
	else:
		# Fallback: add to the component itself.
		add_child.call_deferred(_particles)

func _apply_wind_tilt() -> void:
	if _process_mat == null or _weather_manager == null:
		return
	var wind: float = _weather_manager.get_wind_strength()
	var dir: float = _weather_manager.get_wind_direction()
	# Tilt the rain direction by wind. direction vector = down + wind x.
	var tilt: float = sin(dir) * wind * wind_tilt
	_process_mat.direction = Vector3(tilt, 1.0, 0.0).normalized()
	_process_mat.set_param_max(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, fall_speed + wind * 200.0)
	_process_mat.set_param_min(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, fall_speed + wind * 200.0)

# ============================================================================
# HELPERS
# ============================================================================
func _find_weather_manager() -> WeatherManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager

## Returns the current smoothed rain intensity (0..1) for external query.
func get_display_intensity() -> float:
	return _display_intensity
