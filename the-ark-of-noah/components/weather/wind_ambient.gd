class_name WindAmbient
extends AudioStreamPlayer

## ============================================================================
## WIND AMBIENT — Plays ambient wind audio based on WeatherManager wind strength.
##
## Place this node in the world scene (e.g. under WeatherFX CanvasLayer).
## Replace placeholder_wind.wav with your own .wav/.ogg file when ready.
## ============================================================================

## Built-in placeholder wind sound.
var _placeholder_wind: AudioStream = preload("res://assets/audio/placeholder_wind.wav")

## Minimum volume (dB) when wind is very light.
@export_range(-60.0, 0.0, 0.5) var min_volume_db: float = -40.0

## Maximum volume (dB) at full wind.
@export_range(-60.0, 0.0, 0.5) var max_volume_db: float = -6.0

var _weather_manager: WeatherManager = null

func _ready() -> void:
	stream = _placeholder_wind
	volume_db = -60.0
	bus = "Master"

func _process(delta: float) -> void:
	if _weather_manager == null:
		_weather_manager = _find_weather_manager()
		if _weather_manager == null:
			return
	
	var strength: float = _weather_manager.get_wind_strength()
	var storm_intensity: float = _weather_manager.get_storm_intensity() if _weather_manager.has_method("get_storm_intensity") else 0.0
	var effective: float = clampf(strength + storm_intensity * 0.5, 0.0, 1.5)
	
	if effective > 0.05:
		if not playing:
			play()
		var target_vol: float = lerpf(min_volume_db, max_volume_db, minf(effective, 1.0))
		volume_db = lerpf(volume_db, target_vol, delta * 2.0)
		pitch_scale = lerpf(pitch_scale, lerpf(0.8, 1.2, minf(effective, 1.0)), delta * 1.5)
	else:
		volume_db = lerpf(volume_db, -60.0, delta * 3.0)
		if volume_db < -55.0 and playing:
			stop()
			volume_db = min_volume_db
			pitch_scale = 1.0

func _find_weather_manager() -> WeatherManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager
