extends Node

## WeatherManager behavior tests.
## Uses assertions (no boolean returns) so the test runner can treat assertion
## failures as test failures directly.

var _wm: WeatherManager = null
var _state_clear: int = 0
var _state_stormy: int = 3
var _state_windy: int = 1
var _effect_wind: int = 1
var _effect_rain: int = 2
var _effect_lightning: int = 3
var _effect_thunder: int = 4

func _ensure_wm() -> WeatherManager:
	if _wm != null and is_instance_valid(_wm):
		return _wm
	var wm_script: Script = load("res://scripts/world/weather_manager.gd") as Script
	assert(wm_script != null, "WeatherManager script failed to load")
	_wm = wm_script.new() as WeatherManager
	assert(_wm != null, "WeatherManager instance failed to create")
	_wm.name = "TestWeatherManager"
	_state_clear = _wm.WeatherState.CLEAR
	_state_stormy = _wm.WeatherState.STORMY
	_state_windy = _wm.WeatherState.WINDY
	_effect_wind = _wm.WeatherEffect.WIND
	_effect_rain = _wm.WeatherEffect.RAIN
	_effect_lightning = _wm.WeatherEffect.LIGHTNING
	_effect_thunder = _wm.WeatherEffect.THUNDER
	return _wm

func test_initial_state_is_clear() -> void:
	var wm: WeatherManager = _ensure_wm()
	assert(wm.current_state == _state_clear, "Expected initial weather state CLEAR")

func test_wind_zero_in_clear() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_clear)
	assert(wm.get_wind_strength() < 0.01, "Wind should be near zero in clear weather")

func test_rain_zero_in_clear() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_clear)
	assert(wm.get_rain_intensity() < 0.01, "Rain should be near zero in clear weather")

func test_storm_activates_all_effects() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_stormy)
	assert(wm.has_effect(_effect_wind), "Storm should include wind")
	assert(wm.has_effect(_effect_rain), "Storm should include rain")
	assert(wm.has_effect(_effect_lightning), "Storm should include lightning")
	assert(wm.has_effect(_effect_thunder), "Storm should include thunder")

func test_weather_label_combines_effects() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_stormy)
	var label: String = wm.get_weather_label()
	assert("Wind" in label, "Weather label should include Wind")
	assert("Rain" in label, "Weather label should include Rain")
	assert("Lightning" in label, "Weather label should include Lightning")

func test_wind_has_nonzero_target_in_storm() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_stormy)
	assert(wm.wind_strength > 0.01, "Storm should set a non-zero wind target")

func test_rain_has_nonzero_target_in_storm() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_stormy)
	assert(wm.rain_intensity > 0.01, "Storm should set a non-zero rain target")

func test_state_changed_signal_emits() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_clear)
	var fired: bool = false
	wm.state_changed.connect(func(_a: int, _b: int) -> void: fired = true, CONNECT_ONE_SHOT)
	wm.force_state(_state_windy)
	assert(fired, "state_changed signal should fire when forcing a new state")

func test_clear_has_no_rain_effect() -> void:
	var wm: WeatherManager = _ensure_wm()
	wm.force_state(_state_clear)
	assert(not wm.has_effect(_effect_rain), "Clear weather should not include rain effect")

func test_get_weather_label_returns_string() -> void:
	var wm: WeatherManager = _ensure_wm()
	var label: Variant = wm.get_weather_label()
	assert(typeof(label) == TYPE_STRING, "get_weather_label() should return String")
