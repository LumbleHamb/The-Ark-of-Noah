class_name TimeManager
extends Node

## Internal game-time tracker.
## No visible clock — time is communicated only through world lighting.
##
## Timing (Stardew-like):
##   1 in-game minute = 0.5 real seconds
##   1 in-game hour   = 30 real seconds
##   Full day cycle   = 12 real minutes  (24 h)
##
## Phases:
##   06:00  Sunrise    — warm, brightening
##   08:00  Morning    — bright, warm
##   12:00  Midday     — brightest, neutral
##   17:00  Afternoon  — slight warmth
##   19:00  Sunset     — orange tones, dimming
##   21:00  Night      — dark blue
##   00:00  Late Night — darkest, deep blue
##   04:00  Pre-dawn   — cold dark, beginning to lighten

# ============================================================================
# SIGNALS — Subscribe to these for game events (crop growth, NPC AI, etc.)
# ============================================================================
signal time_tick(hour: int, minute: int, day: int)
signal phase_changed(phase: TimePhase)
signal sunrise()       # 06:00
signal morning()       # 08:00
signal midday()        # 12:00
signal afternoon()     # 17:00
signal sunset()        # 19:00
signal nightfall()     # 21:00
signal late_night()    # 00:00
signal pre_dawn()      # 04:00

# ============================================================================
# PHASE ENUM
# ============================================================================
enum TimePhase {
	PRE_DAWN,    # 04:00 – 05:59  Cold, dark, lightening
	SUNRISE,     # 06:00 – 07:59  Warm, brightening
	MORNING,     # 08:00 – 11:59  Bright, warm
	MIDDAY,      # 12:00 – 16:59  Brightest, neutral
	AFTERNOON,   # 17:00 – 18:59  Slight warmth
	SUNSET,      # 19:00 – 20:59  Orange tones
	NIGHT,       # 21:00 – 23:59  Dark blue
	LATE_NIGHT,  # 00:00 – 03:59  Deepest blue
}

# ============================================================================
# CONFIG
# ============================================================================
## Real seconds per in-game minute.  0.5 = Stardew-like pace.
@export var seconds_per_minute: float = 0.5

## Starting hour (24h format, default 6 = 6 AM).
@export var start_hour: int = 6

## Starting minute.
@export var start_minute: int = 0

## Starting day.
@export var start_day: int = 1

## Starting season (0 = spring, for future use).
@export var start_season: int = 0

# ============================================================================
# STATE
# ============================================================================
var current_hour: int = 6
var current_minute: int = 0
var current_day: int = 1
var current_season: int = 0

var _accumulator: float = 0.0
var _last_phase: TimePhase = TimePhase.SUNRISE

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	current_hour = start_hour
	current_minute = start_minute
	current_day = start_day
	current_season = start_season
	_last_phase = _calc_phase()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"time_manager")

func _process(delta: float) -> void:
	_accumulator += delta
	var step: float = seconds_per_minute
	while _accumulator >= step:
		_accumulator -= step
		_tick()

# ============================================================================
# TIME PROGRESSION
# ============================================================================
func _tick() -> void:
	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		if current_hour >= 24:
			current_hour = 0
			current_day += 1
	
	time_tick.emit(current_hour, current_minute, current_day)
	
	# Check phase transitions
	var phase := _calc_phase()
	if phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase)
		match phase:
			TimePhase.PRE_DAWN:   pre_dawn.emit()
			TimePhase.SUNRISE:    sunrise.emit()
			TimePhase.MORNING:    morning.emit()
			TimePhase.MIDDAY:     midday.emit()
			TimePhase.AFTERNOON:  afternoon.emit()
			TimePhase.SUNSET:     sunset.emit()
			TimePhase.NIGHT:      nightfall.emit()
			TimePhase.LATE_NIGHT: late_night.emit()

# ============================================================================
# PHASE CALC
# ============================================================================
func _calc_phase() -> TimePhase:
	var h: int = current_hour
	if h >= 4 and h < 6:   return TimePhase.PRE_DAWN
	if h >= 6 and h < 8:   return TimePhase.SUNRISE
	if h >= 8 and h < 12:  return TimePhase.MORNING
	if h >= 12 and h < 17: return TimePhase.MIDDAY
	if h >= 17 and h < 19: return TimePhase.AFTERNOON
	if h >= 19 and h < 21: return TimePhase.SUNSET
	if h >= 21 and h < 24: return TimePhase.NIGHT
	return TimePhase.LATE_NIGHT  # 00:00 – 03:59

# ============================================================================
# QUERIES
# ============================================================================
func get_phase() -> TimePhase:
	return _last_phase

func is_night() -> bool:
	return _last_phase in [TimePhase.NIGHT, TimePhase.LATE_NIGHT, TimePhase.PRE_DAWN]

func is_day() -> bool:
	return not is_night()

## Returns 0.0 (midnight) to 1.0 (end of day) for smooth interpolation.
func get_day_progress() -> float:
	var total_minutes: float = current_hour * 60.0 + current_minute
	return total_minutes / (24.0 * 60.0)

# ============================================================================
# SAVE / LOAD
# ============================================================================
func get_save_data() -> Dictionary:
	return {
		"hour": current_hour,
		"minute": current_minute,
		"day": current_day,
		"season": current_season,
		"accumulator": _accumulator,
	}

func load_from_save(data: Dictionary) -> void:
	current_hour = data.get("hour", 6)
	current_minute = data.get("minute", 0)
	current_day = data.get("day", 1)
	current_season = data.get("season", 0)
	_accumulator = data.get("accumulator", 0.0)
	_last_phase = _calc_phase()
