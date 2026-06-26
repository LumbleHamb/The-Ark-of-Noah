extends Node

## Tests for the WeatherManager state machine + weather data APIs.
## The manager is instantiated directly (not added to the tree) so _ready does
## not run — but force_state() and all data APIs work without _ready, as the
## state machine's default state is CLEAR and force_state initialises any state.

var _wm: Node = null
var _State_CLEAR: int = 0
var _State_STORMY: int = 3
var _State_WINDY: int = 1
var _Effect_WIND: int = 1
var _Effect_RAIN: int = 2
var _Effect_LIGHTNING: int = 3
var _Effect_THUNDER: int = 4

func _ensure_wm() -> Node:
	if _wm != null and is_instance_valid(_wm):
		return _wm
	var wm_script: Script = load("res://scripts/world/weather_manager.gd")
	_wm = wm_script.new()
	_wm.set_name("TestWeatherManager")
	# Enum values from the instance.
	_State_CLEAR = _wm.WeatherState.CLEAR
	_State_STORMY = _wm.WeatherState.STORMY
	_State_WINDY = _wm.WeatherState.WINDY
	_Effect_WIND = _wm.WeatherEffect.WIND
	_Effect_RAIN = _wm.WeatherEffect.RAIN
	_Effect_LIGHTNING = _wm.WeatherEffect.LIGHTNING
	_Effect_THUNDER = _wm.WeatherEffect.THUNDER
	return _wm

func test_initial_state_is_clear() -> bool:
	var wm: Node = _ensure_wm()
	return wm.current_state == _State_CLEAR

func test_wind_zero_in_clear() -> bool:
	var wm: Node = _ensure_wm()
	return wm.get_wind_strength() < 0.01

func test_rain_zero_in_clear() -> bool:
	var wm: Node = _ensure_wm()
	return wm.get_rain_intensity() < 0.01

func test_storm_activates_all_effects() -> bool:
	var wm: Node = _ensure_wm()
	wm.force_state(_State_STORMY)
	return (
		wm.has_effect(_Effect_WIND) and
		wm.has_effect(_Effect_RAIN) and
		wm.has_effect(_Effect_LIGHTNING) and
		wm.has_effect(_Effect_THUNDER)
	)

func test_weather_label_combines_effects() -> bool:
	var wm: Node = _ensure_wm()
	wm.force_state(_State_STORMY)
	var label: String = wm.get_weather_label()
	return "Wind" in label and "Rain" in label and "Lightning" in label

func test_wind_has_nonzero_target_in_storm() -> bool:
	var wm: Node = _ensure_wm()
	wm.force_state(_State_STORMY)
	return wm.wind_strength > 0.01

func test_rain_has_nonzero_target_in_storm() -> bool:
	var wm: Node = _ensure_wm()
	wm.force_state(_State_STORMY)
	return wm.rain_intensity > 0.01

func test_state_changed_signal_emits() -> bool:
	var wm: Node = _ensure_wm()
	var fired: bool = false
	wm.state_changed.connect(func(_a: int, _b: int): fired = true)
	wm.force_state(_State_WINDY)
	return fired

func test_clear_has_no_rain_effect() -> bool:
	var wm: Node = _ensure_wm()
	wm.force_state(_State_CLEAR)
	return not wm.has_effect(_Effect_RAIN)

func test_get_weather_label_returns_string() -> bool:
	var wm: Node = _ensure_wm()
	var label: Variant = wm.get_weather_label()
	return typeof(label) == TYPE_STRING
