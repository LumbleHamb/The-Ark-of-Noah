class_name WeatherController
extends Component

## ============================================================================
## WEATHER CONTROLLER — Designer-facing configuration component.
##
## Place ONE of these anywhere in the world scene (e.g. as a child of the world
## root, or under a "Systems" node). On _component_ready it registers with the
## WeatherManager (group "weather_controller") and feeds it every exported
## value below. Reorder/tweak nothing in the manager — all tuning lives here.
##
## This is intentionally a thin, declaration-only component: it has no behaviour
## of its own beyond pushing config at startup. All weather logic stays in the
## WeatherManager and its sibling effect-components.
## ============================================================================

# --- Probabilities (0..1) — chance of each weather arising from a calm state ---
@export_group("Chances")
## Probability that a storm (wind+rain+lightning+thunder) starts.
@export_range(0.0, 1.0, 0.01) var storm_chance: float = 0.15
## Probability of plain rain (no lightning).
@export_range(0.0, 1.0, 0.01) var rain_chance: float = 0.25
## Probability of plain wind (no rain).
@export_range(0.0, 1.0, 0.01) var wind_chance: float = 0.35
## Chance a lightning strike fires each storm-tick while lightning is active.
@export_range(0.0, 1.0, 0.01) var lightning_chance: float = 0.5
## Chance that a lightning strike also produces thunder.
@export_range(0.0, 1.0, 0.01) var thunder_chance: float = 0.9

# --- Durations (seconds) ---
@export_group("Durations")
## Minimum length of a storm once it begins.
@export var min_storm_duration: float = 60.0
## Maximum length of a storm.
@export var max_storm_duration: float = 180.0
## Minimum clear/calm stretch between weather events.
@export var min_clear_duration: float = 90.0
## Maximum clear/calm stretch.
@export var max_clear_duration: float = 240.0

# --- Intensities ---
@export_group("Intensities")
## Base wind strength (0..1). Storms multiply this via storm_wind_multiplier.
@export_range(0.0, 1.0, 0.01) var wind_strength: float = 0.3
## Base rain intensity (0..1). Light rain ~0.3, storm ~1.0.
@export_range(0.0, 1.0, 0.01) var rain_intensity: float = 0.5
## How often lightning strikes while lightning is active (strikes/sec).
@export_range(0.0, 1.0, 0.01) var lightning_frequency: float = 0.1
## Storm wind multiplier. 1.0 = same as base, 2.0 = double base wind in storms.
@export_range(1.0, 3.0, 0.05) var storm_wind_multiplier: float = 1.6

# --- Wind / Gust model ---
@export_group("Wind")
## Average seconds between gust starts at base intensity.
@export_range(0.2, 10.0, 0.1) var gust_frequency: float = 2.2
## Average gust envelope duration in seconds.
@export_range(0.1, 5.0, 0.1) var gust_duration: float = 1.0
## Randomness scale applied to gust intensity/timing (0..1).
@export_range(0.0, 1.0, 0.01) var gust_randomness: float = 0.45

# --- Thunder ---
@export_group("Thunder")
## Minimum delay between a lightning flash and its thunder (close strike).
@export var thunder_delay_min: float = 0.5
## Maximum delay (distant strike). Delay is randomised by simulated distance.
@export var thunder_delay_max: float = 4.0

# --- Transitions / future-proofing ---
@export_group("Advanced")
## How fast weather effects ramp in/out (higher = snappier transitions).
@export var transition_speed: float = 1.5
## Season multiplier (future-proof). Scales storm probability per season. 1.0 = neutral.
@export var season_multiplier: float = 1.0
## Random seed for deterministic weather. 0 = randomise each run.
@export var random_seed: int = 0
## Print weather state changes to the console.
@export var enable_debug: bool = false

func _component_ready() -> void:
	# Register so WeatherManager can find and read us.
	add_to_group(&"weather_controller")
	# If the WeatherManager autoload is already _ready, push config now.
	var wm: WeatherManager = _find_weather_manager()
	if wm and wm.has_method(&"_apply_controller_config"):
		# Re-trigger the manager's lookup so it picks us up, then apply.
		wm.call_deferred(&"_find_controller")

func _find_weather_manager() -> WeatherManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager
