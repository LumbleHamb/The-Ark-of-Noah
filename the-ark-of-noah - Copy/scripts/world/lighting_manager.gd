class_name LightingManager
extends Node

## Controls global ambient colour (CanvasModulate) plus all PointLight2D nodes
## that belong to torches, lamps, campfires, and the player.
##
## Architecture:
##   - A single CanvasModulate child tints the entire 2D canvas.
##     Colour is smoothly interpolated based on TimeManager day progress.
##   - A group "light_source" is scanned for PointLight2D children.
##     Each is enabled/disabled and colour-tinted based on time of day.
##   - The player's personal light is handled by a dedicated PointLight2D
##     child of the player, also managed here.
##
## Why CanvasModulate + PointLight2D?
##   CanvasModulate is the cheapest way to shift global colour — a single
##   GPU blend.  PointLight2D gives localised cone/radius lighting around
##   each source.  Combined they produce the Stardew feel: a warm/cool
##   world tint layered with local torch/fire glow at night.
##   A full-screen shader would be overkill and less portable.

# ============================================================================
# SIGNALS
# ============================================================================
signal ambient_color_changed(color: Color)

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var modulate: CanvasModulate = $CanvasModulate

# ============================================================================
# EXPORTS
# ============================================================================
## Reference to the player's personal PointLight2D (night glow).
@export var player_light: PointLight2D = null

## How fast the light flickers (0 = no flicker).
@export var flicker_speed: float = 6.0

## How much flicker varies the energy (0.0 = none, 0.3 = strong).
@export var flicker_strength: float = 0.08

## Phase at which light sources first switch ON.
## Default SUNSET = lights come on at dusk (19:00) so lamps/campfires glow
## as the sun sets — not only once it is fully dark.
@export var light_start_phase: TimeManager.TimePhase = TimeManager.TimePhase.SUNSET

## Extra energy applied to light sources during the darkest phases
## (NIGHT + LATE_NIGHT).  0.0 = uniform brightness from dusk to dawn,
## 0.3 = lights get 30% brighter in the dead of night.  Lets designers
## make lamps "come alive" after midnight without affecting dusk glow.
@export_range(0.0, 2.0, 0.01) var night_light_boost: float = 0.25

## How dark the night ambient gets.  0.0 = night as bright as day,
## 1.0 = original curve darkness, >1.0 = extra dark.
@export_range(0.0, 2.0, 0.01) var night_darkness: float = 1.0:
	set(v):
		night_darkness = v
		if is_inside_tree() and time_manager:
			_update_ambient(time_manager.get_day_progress())

## Global brightness multiplier for all PointLight2D energy values.
## Adjust this to make ALL night lights brighter/dimmer at once.
@export_range(0.0, 5.0, 0.1) var light_energy_multiplier: float = 1.0:
	set(v):
		light_energy_multiplier = v
		if is_inside_tree():
			_apply_flicker(_last_night)

## Global size multiplier for all PointLight2D texture_scale values.
## Adjust this to make ALL night lights larger/smaller at once.
@export_range(0.0, 5.0, 0.1) var light_scale_multiplier: float = 1.0:
	set(v):
		light_scale_multiplier = v
		if is_inside_tree():
			_apply_size()

# ============================================================================
# STATE
# ============================================================================
var time_manager: TimeManager = null

var _light_sources: Array[Node] = []
var _source_lights: Dictionary = {}   # Node → Array[PointLight2D]
var _source_components: Dictionary = {} # Node → LightSourceComponent
var _flicker_offset: float = 0.0
var _last_night: bool = false          # lights-on state (dusk → dawn)
var _last_deep_night: bool = false     # full-night boost state
var _player_light_base_energy: float = 1.2
var _player_light_base_scale: float = 4.0
## Current rain intensity (0..1), fed by the WeatherManager. Rain darkens
## the ambient colour and cools its tint.
var _rain_intensity: float = 0.0
## Whether we have successfully connected to the WeatherManager.
var _weather_connected: bool = false

# Ambient colour curve: key = day_progress (0.0 – 1.0), value = Color
# Key points match the time phases.
const AMBIENT_CURVE: Dictionary = {
	0.00: Color("#0a0a1a"),  # 00:00 Late Night — deep blue-black
	0.10: Color("#0a0a1a"),  # 01:00
	0.17: Color("#14142e"),  # 04:00 Pre-dawn — cold dark
	0.21: Color("#4a3a2a"),  # 05:00 just before sunrise — warm bleed
	0.25: Color("#d4a060"),  # 06:00 Sunrise — warm orange
	0.33: Color("#f0d8a0"),  # 08:00 Morning — warm bright
	0.50: Color("#ffffff"),  # 12:00 Midday — pure white
	0.71: Color("#f0d8a0"),  # 17:00 Afternoon — warm bright
	0.79: Color("#d47840"),  # 19:00 Sunset — deep orange
	0.83: Color("#6a4050"),  # 20:00 Dusk — purple-blue
	0.88: Color("#1a1a3a"),  # 21:00 Night — dark blue
	1.00: Color("#0a0a1a"),  # 24:00 Late Night
}

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"lighting_manager")
	
	# Store base energy and scale for player light.
	if player_light and is_instance_valid(player_light):
		_player_light_base_energy = player_light.energy
		_player_light_base_scale = player_light.texture_scale
	
	# Find TimeManager.
	time_manager = _find_time_manager()
	if time_manager:
		# Connect to phase_changed for responsive transition callbacks.
		time_manager.phase_changed.connect(_on_phase_changed)
		# Initial setup.
		_update_ambient(time_manager.get_day_progress())
		# Use the lamp-on check (dusk → dawn) for initial state so lights
		# are immediately lit if the game starts in the evening.
		_last_night = _lamps_should_be_on()
		_last_deep_night = time_manager.get_phase() in [TimeManager.TimePhase.NIGHT, TimeManager.TimePhase.LATE_NIGHT]
	else:
		push_warning("LightingManager: no TimeManager found — lighting will not update.")
	
	# Refresh sources first, THEN update lights so they get the correct state.
	_refresh_light_sources()
	_update_lights(_last_night)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	# Hook into the weather system for rain darkening. Deferred so the
	# WeatherManager autoload is ready before we connect.
	call_deferred(&"_connect_weather")

func _process(delta: float) -> void:
	_flicker_offset += delta * flicker_speed
	
	if time_manager == null:
		return
	
	var progress: float = time_manager.get_day_progress()
	_update_ambient(progress)
	
	# "Lamps on" = from the configured start phase (default dusk/SUNSET)
	# through to sunrise.  This is broader than is_night() so lamps glow
	# during the golden-hour/dusk transition rather than snapping on at 21:00.
	var lamps_on: bool = _lamps_should_be_on()
	if lamps_on != _last_night:
		_last_night = lamps_on
		_update_lights(lamps_on)
		_apply_flicker(lamps_on)  # Apply energy multiplier immediately
	
	# Deep-night energy boost: lights get slightly brighter in the dead of
	# night (NIGHT + LATE_NIGHT) vs early dusk/dawn.  Toggled reactively.
	var deep_night: bool = time_manager.get_phase() in [TimeManager.TimePhase.NIGHT, TimeManager.TimePhase.LATE_NIGHT]
	if deep_night != _last_deep_night:
		_last_deep_night = deep_night
		_apply_flicker(_last_night)  # re-apply with or without boost
	else:
		# Still apply flicker every frame while lamps are on.
		_apply_flicker(_last_night)
	
	# Lazy-connect to the weather system if it wasn't ready at _ready time.
	if not _weather_connected:
		_connect_weather()

## Returns true when light sources should be enabled.
## Spans from the configured light_start_phase through pre-dawn / sunrise.
func _lamps_should_be_on() -> bool:
	if time_manager == null:
		return false
	var phase: TimeManager.TimePhase = time_manager.get_phase()
	# Everything from the start phase through late-night and pre-dawn is "on".
	# Sunrise (06:00–08:00) is the fade-off boundary; treat as off so lamps
	# extinguish as the sun comes up.
	return phase >= light_start_phase or phase == TimeManager.TimePhase.PRE_DAWN

# ============================================================================
# AMBIENT COLOUR
# ============================================================================
func _update_ambient(progress: float) -> void:
	var sorted_keys: Array = AMBIENT_CURVE.keys()
	sorted_keys.sort()
	
	# Find the two surrounding keyframes.
	var prev_key: float = sorted_keys[0]
	var next_key: float = sorted_keys[-1]
	for k in sorted_keys:
		if k <= progress:
			prev_key = k
		if k >= progress and k < next_key:
			next_key = k
	
	var prev_color: Color = AMBIENT_CURVE[prev_key]
	var next_color: Color = AMBIENT_CURVE[next_key]
	
	# Interpolate.
	var t: float = 0.0
	if next_key > prev_key:
		t = (progress - prev_key) / (next_key - prev_key)
	
	var color: Color = prev_color.lerp(next_color, t)
	
	# ========================================================================
	# NIGHT DARKNESS — lets the user control how dark nighttime gets.
	#   0.0 = night ambient is fully bright (like midday white)
	#   1.0 = original curve behaviour
	#  >1.0 = even darker than the curve (extrapolates toward black)
	#
	# We only apply this when it's actually dark (luminance < 0.4) so that
	# daytime and golden-hour colours are untouched.
	# ========================================================================
	if night_darkness != 1.0:
		var lum: float = color.get_luminance()
		if lum < 0.4:
			if night_darkness < 1.0:
				# Brighter nights — blend the dark colour toward white.
				color = Color.WHITE.lerp(color, night_darkness)
			else:
				# Darker nights — push the dark colour further toward black.
				var extra: float = clampf(night_darkness - 1.0, 0.0, 1.0)
				color = color.lerp(Color.BLACK, extra)
	
	# ========================================================================
	# RAIN DARKENING — rain cools and dims the ambient colour. The WeatherManager
	# pushes rain intensity (0..1) here; we blend toward a cool grey-blue so the
	# world feels overcast during rain and stormy during full storms.
	# ========================================================================
	if _rain_intensity > 0.01:
		var rain_tint: Color = Color(0.45, 0.5, 0.6, 1.0)  # cool overcast grey-blue
		color = color.lerp(rain_tint, _rain_intensity * 0.5)
	
	modulate.color = color
	ambient_color_changed.emit(color)

# ============================================================================
# PHASE TRANSITION CALLBACKS
# ============================================================================
func _on_phase_changed(_phase: TimeManager.TimePhase) -> void:
	# Phase changes are already handled by _process via is_night check,
	# but we use this for any future event-driven logic (e.g. playing
	# a brief transition animation). Subclasses can override.
	pass

# ============================================================================
# WEATHER INTEGRATION — rain darkens ambient, driven by WeatherManager
# ============================================================================
func _connect_weather() -> void:
	if _weather_connected:
		return
	if get_tree() == null:
		return
	var wm: WeatherManager = get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager
	if wm == null:
		return  # No weather system in this scene — that's fine, rain stays 0.
	_weather_connected = true
	wm.rain_intensity_changed.connect(_on_rain_intensity_changed)

## Called by WeatherManager with the smoothed rain intensity (0..1).
func _on_rain_intensity_changed(intensity: float) -> void:
	_rain_intensity = intensity

# ============================================================================
# LIGHT SOURCE MANAGEMENT
# ============================================================================
func _refresh_light_sources() -> void:
	# Scan the tree for nodes in group 'light_source'.
	# Guard: during scene teardown, get_tree() can be null (e.g. when a
	# LightSource's _exit_tree calls unregister_light_source after the
	# LightingManager has already left the tree).
	if get_tree() == null:
		_light_sources.clear()
		return
	_light_sources = get_tree().get_nodes_in_group(&"light_source")
	_source_lights.clear()
	_source_components.clear()
	
	for node in _light_sources:
		# Look for a LightSourceComponent on this node.
		var comp: LightSourceComponent = node.get_node_or_null("LightSource") as LightSourceComponent
		if comp and is_instance_valid(comp):
			_source_components[node] = comp
		
		# Collect PointLight2D children recursively.
		var lights: Array[PointLight2D] = []
		_collect_point_lights(node, lights)
		if lights.size() > 0:
			_source_lights[node] = lights

func _collect_point_lights(node: Node, out: Array[PointLight2D]) -> void:
	# Recursively collect PointLight2D children.
	if node is PointLight2D:
		out.append(node)
		return  # Don't recurse into light nodes
	for child in node.get_children():
		_collect_point_lights(child, out)

func _update_lights(is_night: bool) -> void:
	# Enable/disable lights and toggle LightSource animations.
	for node in _light_sources:
		# Toggle LightSource component animations.
		var comp: LightSourceComponent = _source_components.get(node)
		if comp and is_instance_valid(comp):
			comp.set_lit(is_night)
		
		# Toggle PointLight2D children and apply scale + energy multipliers.
		var lights: Array = _source_lights.get(node, [])
		for light in lights:
			if not is_instance_valid(light):
				continue
			light.enabled = is_night
			if is_night:
				var base_scale: float = light.get_meta(&"base_texture_scale", light.texture_scale)
				light.texture_scale = base_scale * light_scale_multiplier
				var base_energy: float = light.get_meta(&"base_energy", light.energy)
				light.energy = base_energy * light_energy_multiplier
	
	# Handle player light separately.
	if player_light and is_instance_valid(player_light):
		player_light.enabled = is_night
		if is_night:
			player_light.texture_scale = _player_light_base_scale * light_scale_multiplier
			player_light.energy = _player_light_base_energy * light_energy_multiplier

func _apply_flicker(is_night: bool) -> void:
	# Apply subtle energy flicker to all active lights.
	if not is_night:
		return
	
	# Deep-night boost multiplier (1.0 at dusk/dawn, 1.0+night_light_boost in
	# the dead of night).  Computed once per frame for all lights.
	var boost: float = 1.0 + (night_light_boost if _last_deep_night else 0.0)
	
	for node in _light_sources:
		var lights: Array = _source_lights.get(node, [])
		for light in lights:
			if not is_instance_valid(light) or not light.enabled:
				continue
			var base: float = light.get_meta(&"base_energy", 1.0)
			var flicker: float = sin(_flicker_offset + light.global_position.length() * 0.1) * flicker_strength
			light.energy = (base + flicker) * light_energy_multiplier * boost
	
	# Player light flicker.
	if player_light and is_instance_valid(player_light) and player_light.enabled:
		var flicker: float = sin(_flicker_offset * 1.5) * (flicker_strength * 1.5)
		player_light.energy = (_player_light_base_energy + flicker) * light_energy_multiplier * boost

## Reapply texture_scale to all active lights using current multiplier.
## Called when the user tweaks light_scale_multiplier in the inspector.
func _apply_size() -> void:
	for node in _light_sources:
		var lights: Array = _source_lights.get(node, [])
		for light in lights:
			if not is_instance_valid(light) or not light.enabled:
				continue
			var base_scale: float = light.get_meta(&"base_texture_scale", light.texture_scale)
			light.texture_scale = base_scale * light_scale_multiplier
	
	if player_light and is_instance_valid(player_light) and player_light.enabled:
		player_light.texture_scale = _player_light_base_scale * light_scale_multiplier

func register_light_source(node: Node) -> void:
	# Allow runtime registration of new light sources (e.g. placed torches).
	if not node.is_in_group(&"light_source"):
		node.add_to_group(&"light_source")
	_refresh_light_sources()
	# Apply current night state to the newly registered light source.
	_update_lights(_last_night)

func unregister_light_source(node: Node) -> void:
	if node.is_in_group(&"light_source"):
		node.remove_from_group(&"light_source")
	_refresh_light_sources()

# ============================================================================
# DYNAMIC LIGHT SOURCE TRACKING
# ============================================================================
func _on_node_added(node: Node) -> void:
	# Auto-register new light sources when they enter the scene.
	if node is PointLight2D or node is LightSourceComponent:
		call_deferred(&"_refresh_and_apply_lights")
	elif node.get_child_count() > 0 and node.is_inside_tree():
		for child in node.get_children():
			if child is LightSourceComponent:
				call_deferred(&"_refresh_and_apply_lights")
				break

func _on_node_removed(node: Node) -> void:
	# Auto-unregister removed light sources.
	if node.is_in_group(&"light_source") or node is PointLight2D or node is LightSourceComponent:
		call_deferred(&"_refresh_light_sources")

# Refreshes the light source list then applies the current night/day state.
func _refresh_and_apply_lights() -> void:
	_refresh_light_sources()
	_update_lights(_last_night)

# ============================================================================
# HELPERS
# ============================================================================
func _find_time_manager() -> TimeManager:
	var tm: TimeManager = get_node("/root/world/TimeManager") as TimeManager
	if tm == null and get_tree() != null:
		tm = get_tree().get_first_node_in_group(&"time_manager")
	if tm == null and get_tree() != null:
		tm = get_tree().root.find_child("TimeManager", true, false) as TimeManager
	return tm
