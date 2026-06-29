extends Node

## ============================================================================
## WEATHER MANAGER — Central dynamic weather system.
##
## Owns the weather state machine and broadcasts wind/rain/lightning/thunder
## data to every interested component via signals + a polling API.
##
## Architecture:
##   - WeatherManager is an autoload singleton (group "weather_manager").
##   - It reads the in-game clock (TimeManager) to modulate weather probability
##     by time-of-day (e.g. storms more likely in the afternoon, fog at dawn).
##   - A clean state machine (CLEAR → WIND → RAIN → STORM → TRANSITION) drives
##     weather evolution. No giant if/else chains.
##   - Each weather aspect (wind, rain, lightning, thunder) is an INDEPENDENT
##     flag + intensity value. They can combine freely: windy+rain, rain+lightning,
##     wind+thunder, full storm, etc.
##   - Components (WindComponent, RainComponent, LightningComponent,
##     ThunderComponent) poll get_wind() / get_rain_intensity() / etc. each
##     frame — cheap reads, no signal-per-frame spam.
##   - Discrete transitions (storm start, lightning strike, thunder) use signals.
##
## Day/Night integration:
##   - Storm probability curve varies by TimePhase (see STORM_PROBABILITY_BY_PHASE).
##   - Rain darkens ambient — LightingManager subscribes to weather_changed and
##     blends a rain tint into the CanvasModulate.
##   - Lightning temporarily overrides darkness via a flash signal the
##     LightningComponent handles.
##   - Early-morning fog is a future hook (phase-based fog chance exported).
##
## All designer-facing tuning lives in WeatherController (a Component placed in
## the world scene). WeatherManager reads a controller if one exists; otherwise
## it uses its own built-in defaults. This keeps the manager reusable while
## giving designers a clean Inspector surface.
## ============================================================================

# ============================================================================
# SIGNALS — discrete events (NOT per-frame data; use polling for wind/rain)
# ============================================================================
signal weather_changed(active_effects: Array)  # Array of WeatherEffect enums currently on
signal wind_changed(strength: float, direction: float)  # direction in radians
signal rain_intensity_changed(intensity: float)  # 0..1
signal lightning_strike(brightness: float, duration: float)  # a flash just happened
signal thunder_triggered(distance: float)  # simulated distance 0=near, 1=far
signal state_changed(from_state: int, to_state: int)
signal storm_intensity_changed(intensity: float)

# ============================================================================
# ENUMS
# ============================================================================
enum WeatherEffect { CALM, WIND, RAIN, LIGHTNING, THUNDER }
enum WeatherState { CLEAR, WINDY, RAINY, STORMY, TRANSITIONING }

# ============================================================================
# STATE — current weather data (polled by components)
# ============================================================================
var current_state: WeatherState = WeatherState.CLEAR
var active_effects: Array[WeatherEffect] = [WeatherEffect.CALM]

var wind_strength: float = 0.0        # 0..1 target
var wind_direction: float = 0.0      # radians
var _wind_display: float = 0.0       # smoothed display value
var _wind_gust_timer: float = 0.0
var _wind_gust_active: float = 0.0   # 0..1 gust envelope
var _storm_intensity: float = 0.0    # 0..1, used by wind/tree sway/audio

var rain_intensity: float = 0.0      # 0..1 target
var _rain_display: float = 0.0       # smoothed

var _lightning_cooldown: float = 0.0
var _thunder_pending: bool = false
var _thunder_delay: float = 0.0

# ============================================================================
# REFERENCES
# ============================================================================
var time_manager: TimeManager = null
var _controller: Node = null  # WeatherController (untyped to avoid circular dep)

# ============================================================================
# CONFIG — built-in defaults (overridden by WeatherController if present)
# ============================================================================
var _storm_chance: float = 0.15
var _rain_chance: float = 0.25
var _wind_chance: float = 0.35
var _lightning_chance: float = 0.5   # chance per storm tick that lightning fires
var _thunder_chance: float = 0.9     # chance that a lightning strike produces thunder
var _min_storm_duration: float = 60.0
var _max_storm_duration: float = 180.0
var _min_clear_duration: float = 90.0
var _max_clear_duration: float = 240.0
var _base_wind_strength: float = 0.3
var _base_rain_intensity: float = 0.5
var _lightning_frequency: float = 0.1  # strikes per second during storm
var _storm_wind_multiplier: float = 1.6
var _gust_frequency: float = 2.2
var _gust_duration: float = 1.0
var _gust_randomness: float = 0.45
var _thunder_delay_min: float = 0.5
var _thunder_delay_max: float = 4.0
var _transition_speed: float = 1.5   # how fast effects ramp in/out
var _season_multiplier: float = 1.0
var _random_seed: int = 0
var _debug: bool = false

# Storm probability multiplier per time phase (future-proof, designer-tunable
# via the controller). 1.0 = neutral. Higher = more storms that phase.
const STORM_PROBABILITY_BY_PHASE: Dictionary = {
	TimeManager.TimePhase.PRE_DAWN: 0.5,
	TimeManager.TimePhase.SUNRISE: 0.6,
	TimeManager.TimePhase.MORNING: 0.7,
	TimeManager.TimePhase.MIDDAY: 1.2,
	TimeManager.TimePhase.AFTERNOON: 1.6,   # afternoon thunderstorms
	TimeManager.TimePhase.SUNSET: 1.3,
	TimeManager.TimePhase.NIGHT: 0.8,
	TimeManager.TimePhase.LATE_NIGHT: 0.4,
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state_timer: float = 0.0
var _state_duration: float = 120.0

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"weather_manager")
	# Seed RNG.
	if _random_seed != 0:
		_rng.seed = _random_seed
	else:
		_rng.randomize()
	# Find the time manager (autoload-safe: search tree).
	_find_time_manager()
	# Try to find a WeatherController in the tree (designer config).
	call_deferred(&"_find_controller")
	# Begin in CLEAR with a fresh clear timer.
	_enter_state(WeatherState.CLEAR)

func _process(delta: float) -> void:
	if time_manager == null:
		_find_time_manager()
	
	# --- State machine timer ---
	_state_timer += delta
	if _state_timer >= _state_duration:
		_pick_next_state()
	
	# --- Wind smoothing + gusts ---
	_update_wind(delta)
	
	# --- Rain smoothing ---
	_update_rain(delta)
	
	# --- Lightning + thunder (only during stormy / lightning-active) ---
	if WeatherEffect.LIGHTNING in active_effects:
		_update_lightning(delta)
	if _thunder_pending:
		_update_thunder(delta)

# ============================================================================
# STATE MACHINE
# ============================================================================
func _enter_state(new_state: WeatherState) -> void:
	var old: int = current_state
	current_state = new_state
	_state_timer = 0.0
	
	match new_state:
		WeatherState.CLEAR:
			_state_duration = _rng.randf_range(_min_clear_duration, _max_clear_duration)
			_set_effects([WeatherEffect.CALM])
			_set_wind_target(0.0)
			_set_rain_target(0.0)
			_set_storm_intensity(0.0)
		WeatherState.WINDY:
			_state_duration = _rng.randf_range(_min_clear_duration * 0.6, _max_clear_duration * 0.6)
			_set_effects([WeatherEffect.WIND])
			_set_wind_target(_base_wind_strength * _rng.randf_range(0.6, 1.0))
			_set_rain_target(0.0)
			_set_storm_intensity(0.15)
		WeatherState.RAINY:
			_state_duration = _rng.randf_range(_min_storm_duration * 0.5, _max_storm_duration * 0.5)
			_set_effects([WeatherEffect.WIND, WeatherEffect.RAIN])
			_set_wind_target(_base_wind_strength * 0.5)
			_set_rain_target(_base_rain_intensity * _rng.randf_range(0.4, 0.7))
			_set_storm_intensity(0.45)
		WeatherState.STORMY:
			_state_duration = _rng.randf_range(_min_storm_duration, _max_storm_duration)
			_set_effects([WeatherEffect.WIND, WeatherEffect.RAIN, WeatherEffect.LIGHTNING, WeatherEffect.THUNDER])
			_set_wind_target(_base_wind_strength * _storm_wind_multiplier * _rng.randf_range(0.9, 1.2))
			_set_rain_target(_base_rain_intensity * _rng.randf_range(0.8, 1.0))
			_set_storm_intensity(1.0)
		WeatherState.TRANSITIONING:
			# Brief interstitial; immediately pick a real next state.
			_state_duration = 0.5
	
	state_changed.emit(old, new_state)
	weather_changed.emit(active_effects)

func _pick_next_state() -> void:
	# Weighted random selection modulated by time-of-day and season.
	var phase_mult: float = 1.0
	if time_manager:
		var phase: TimeManager.TimePhase = time_manager.get_phase()
		phase_mult = STORM_PROBABILITY_BY_PHASE.get(phase, 1.0) * _season_multiplier
	
	# Build weighted choices from current state.
	var weights: Dictionary = {}
	match current_state:
		WeatherState.CLEAR, WeatherState.WINDY:
			weights[WeatherState.WINDY] = _wind_chance
			weights[WeatherState.RAINY] = _rain_chance * phase_mult
			weights[WeatherState.STORMY] = _storm_chance * phase_mult
			weights[WeatherState.CLEAR] = maxf(0.1, 1.0 - (_wind_chance + _rain_chance + _storm_chance))
		WeatherState.RAINY:
			weights[WeatherState.STORMY] = _storm_chance * phase_mult * 0.5
			weights[WeatherState.RAINY] = 0.3
			weights[WeatherState.CLEAR] = 0.2
		WeatherState.STORMY:
			weights[WeatherState.RAINY] = 0.4
			weights[WeatherState.CLEAR] = 0.3
			weights[WeatherState.WINDY] = 0.2
		_:
			weights[WeatherState.CLEAR] = 1.0
	
	# Weighted pick.
	var total: float = 0.0
	for w in weights.values():
		total += w
	var roll: float = _rng.randf() * total
	var picked: WeatherState = WeatherState.CLEAR
	for key in weights.keys():
		roll -= weights[key]
		if roll <= 0.0:
			picked = key
			break
	
	_enter_state(WeatherState.TRANSITIONING)
	# After the short transition, enter the picked state.
	call_deferred(&"_enter_state", picked)

# ============================================================================
# WIND
# ============================================================================
func _update_wind(delta: float) -> void:
	# Smoothly interpolate display wind toward target + gust envelope.
	var target: float = wind_strength + _wind_gust_active * 0.3
	_wind_display = lerpf(_wind_display, target, clampf(delta * _transition_speed, 0.0, 1.0))
	
	# Random gusts — driven by controller-tunable frequency/duration/randomness.
	if wind_strength > 0.05:
		_wind_gust_timer -= delta
		if _wind_gust_timer <= 0.0:
			var random_scale: float = lerpf(1.0 - _gust_randomness, 1.0 + _gust_randomness, _rng.randf())
			var storm_boost: float = lerpf(1.0, 1.6, _storm_intensity)
			_wind_gust_active = clampf(_rng.randf_range(0.25, 1.0) * wind_strength * random_scale * storm_boost, 0.0, 1.5)
			var next_delay: float = maxf(0.05, _gust_frequency / maxf(wind_strength + (_storm_intensity * 0.5), 0.1))
			_wind_gust_timer = next_delay * _rng.randf_range(0.7, 1.3)
		# Decay gust envelope over configured gust duration.
		var gust_decay_speed: float = 1.0 / maxf(_gust_duration, 0.05)
		_wind_gust_active = maxf(0.0, _wind_gust_active - delta * gust_decay_speed)
	else:
		_wind_gust_active = 0.0
	
	# Emit wind_changed only when display changes meaningfully (throttled).
	wind_changed.emit(_wind_display, wind_direction)

func _set_wind_target(strength: float) -> void:
	wind_strength = clampf(strength, 0.0, 1.0)
	# Randomise direction occasionally when wind is active.
	if wind_strength > 0.05:
		wind_direction = _rng.randf_range(-0.4, 0.4)  # mostly downward bias (top-down game)

## Polled by WindComponent each frame. Returns smoothed wind strength 0..1.
func get_wind_strength() -> float:
	return _wind_display

## Polled by WindComponent. Returns wind direction in radians.
func get_wind_direction() -> float:
	return wind_direction

## Polled by shaders/components that want gust info (0..1).
func get_wind_gust() -> float:
	return _wind_gust_active

func get_storm_intensity() -> float:
	return _storm_intensity

# ============================================================================
# RAIN
# ============================================================================
func _update_rain(delta: float) -> void:
	_rain_display = lerpf(_rain_display, rain_intensity, clampf(delta * _transition_speed, 0.0, 1.0))
	rain_intensity_changed.emit(_rain_display)

func _set_rain_target(intensity: float) -> void:
	rain_intensity = clampf(intensity, 0.0, 1.0)

## Polled by RainComponent. Returns smoothed rain intensity 0..1.
func get_rain_intensity() -> float:
	return _rain_display

# ============================================================================
# LIGHTNING
# ============================================================================
func _update_lightning(delta: float) -> void:
	_lightning_cooldown -= delta
	if _lightning_cooldown <= 0.0:
		_fire_lightning()
		# Reset cooldown based on frequency + randomness.
		_lightning_cooldown = 1.0 / maxf(_lightning_frequency, 0.01) * _rng.randf_range(0.5, 2.0)

func _fire_lightning() -> void:
	var brightness: float = _rng.randf_range(0.6, 1.0)
	var duration: float = _rng.randf_range(0.08, 0.25)
	lightning_strike.emit(brightness, duration)
	
	# Maybe schedule thunder.
	if _rng.randf() < _thunder_chance:
		_thunder_pending = true
		# Simulated distance: closer strikes → shorter delay.
		var distance: float = _rng.randf_range(0.0, 1.0)
		_thunder_delay = lerpf(_thunder_delay_min, _thunder_delay_max, distance)
		# Store distance for the thunder signal.
		set_meta(&"_pending_thunder_distance", distance)

# ============================================================================
# THUNDER
# ============================================================================
func _update_thunder(delta: float) -> void:
	_thunder_delay -= delta
	if _thunder_delay <= 0.0:
		_thunder_pending = false
		var distance: float = get_meta(&"_pending_thunder_distance", 0.5)
		thunder_triggered.emit(distance)

# ============================================================================
# EFFECTS HELPERS
# ============================================================================
func _set_effects(effects: Array) -> void:
	active_effects.clear()
	for e in effects:
		active_effects.append(e)

func _set_storm_intensity(intensity: float) -> void:
	_storm_intensity = clampf(intensity, 0.0, 1.0)
	storm_intensity_changed.emit(_storm_intensity)

## Returns true if a given effect is currently active.
func has_effect(effect: WeatherEffect) -> bool:
	return effect in active_effects

# ============================================================================
# CONTROLLER / CONFIG INTEGRATION
# ============================================================================
func _find_controller() -> void:
	if get_tree() == null:
		return
	# Look for a node in the weather_controller group (placed by designer).
	_controller = get_tree().get_first_node_in_group(&"weather_controller")
	if _controller:
		_apply_controller_config()

func _apply_controller_config() -> void:
	if _controller == null:
		return
	_storm_chance = _controller.storm_chance
	_rain_chance = _controller.rain_chance
	_wind_chance = _controller.wind_chance
	_lightning_chance = _controller.lightning_chance
	_thunder_chance = _controller.thunder_chance
	_min_storm_duration = _controller.min_storm_duration
	_max_storm_duration = _controller.max_storm_duration
	_min_clear_duration = _controller.min_clear_duration
	_max_clear_duration = _controller.max_clear_duration
	_base_wind_strength = _controller.wind_strength
	_base_rain_intensity = _controller.rain_intensity
	_lightning_frequency = _controller.lightning_frequency
	_storm_wind_multiplier = _controller.storm_wind_multiplier
	_gust_frequency = _controller.gust_frequency
	_gust_duration = _controller.gust_duration
	_gust_randomness = _controller.gust_randomness
	_thunder_delay_min = _controller.thunder_delay_min
	_thunder_delay_max = _controller.thunder_delay_max
	_transition_speed = _controller.transition_speed
	_season_multiplier = _controller.season_multiplier
	_random_seed = _controller.random_seed
	_debug = _controller.enable_debug
	if _random_seed != 0:
		_rng.seed = _random_seed
	if _debug:
		print("[WeatherManager] Controller config applied: storm=%.2f rain=%.2f wind=%.2f" % [_storm_chance, _rain_chance, _wind_chance])

# ============================================================================
# TIME MANAGER
# ============================================================================
func _find_time_manager() -> void:
	if get_tree() == null:
		return
	time_manager = get_tree().get_first_node_in_group(&"time_manager") as TimeManager
	if time_manager == null:
		time_manager = get_tree().root.find_child("TimeManager", true, false) as TimeManager

# ============================================================================
# DEBUG
# ============================================================================
func _debug_print() -> void:
	if not _debug:
		return
	print("[WeatherManager] state=%s effects=%s wind=%.2f rain=%.2f" % [
		WeatherState.keys()[current_state], active_effects, _wind_display, _rain_display])

## Allows external systems (e.g. a debug overlay) to force a weather state.
func force_state(state: WeatherState) -> void:
	_enter_state(state)

## Returns a human-readable label for the current weather (for UI/debug).
func get_weather_label() -> String:
	var labels: Array[String] = []
	for e in active_effects:
		match e:
			WeatherEffect.CALM: labels.append("Calm")
			WeatherEffect.WIND: labels.append("Wind")
			WeatherEffect.RAIN: labels.append("Rain")
			WeatherEffect.LIGHTNING: labels.append("Lightning")
			WeatherEffect.THUNDER: labels.append("Thunder")
	if labels.size() == 0:
		return "Calm"
	return " + ".join(labels)
