class_name ThunderComponent
extends Component

## ============================================================================
## THUNDER COMPONENT — Plays thunder audio after a lightning flash.
##
## Listens to the WeatherManager's `thunder_triggered` signal, which carries a
## simulated distance (0 = close strike, 1 = distant). The component picks a
## random audio clip from `thunder_clips`, sets its volume/pitch based on
## distance, and plays it.
##
## Supports multiple thunder audio clips for variety. If no clips are assigned,
## the component synthesises a simple rumble so the feature still works out of
## the box (designers can drop real .wav/.ogg files in later).
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
## Array of audio streams to randomly choose from for thunder.
@export var thunder_clips: Array[AudioStream] = []

## Volume for a close strike (dB). 0 = loudest typical.
@export_range(-40.0, 0.0, 0.5) var close_volume: float = -3.0

## Volume for a distant strike (dB).
@export_range(-60.0, 0.0, 0.5) var distant_volume: float = -25.0

## Pitch scale range (min, max) for variation.
@export var pitch_min: float = 0.85
@export var pitch_max: float = 1.15

## If true and no clips are assigned, generate a procedural rumble.
@export var synthesize_if_empty: bool = true

# ============================================================================
# STATE
# ============================================================================
var _weather_manager: WeatherManager = null
var _audio_player: AudioStreamPlayer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _component_ready() -> void:
	_rng.randomize()
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "ThunderPlayer"
	_audio_player.bus = "Master"
	add_child.call_deferred(_audio_player)
	_weather_manager = _find_weather_manager()
	if _weather_manager:
		_weather_manager.thunder_triggered.connect(_on_thunder_triggered)

func _process(_delta: float) -> void:
	if _weather_manager == null:
		_weather_manager = _find_weather_manager()
		if _weather_manager:
			_weather_manager.thunder_triggered.connect(_on_thunder_triggered)

# ============================================================================
# THUNDER
# ============================================================================
func _on_thunder_triggered(distance: float) -> void:
	# distance: 0 = close (loud, sharp), 1 = far (quiet, low rumble).
	var volume: float = lerpf(close_volume, distant_volume, distance)
	var pitch: float = _rng.randf_range(pitch_min, pitch_max) * lerpf(1.0, 0.8, distance)
	
	if thunder_clips.size() > 0:
		var clip: AudioStream = thunder_clips[_rng.randi() % thunder_clips.size()]
		_play_clip(clip, volume, pitch)
	elif synthesize_if_empty:
		_play_synthesized(volume, pitch)

func _play_clip(clip: AudioStream, volume: float, pitch: float) -> void:
	if _audio_player == null:
		return
	_audio_player.stream = clip
	_audio_player.volume_db = volume
	_audio_player.pitch_scale = pitch
	_audio_player.play()

func _play_synthesized(volume: float, pitch: float) -> void:
	# Without real audio clips there is nothing to play. We emit a debug print
	# so designers know to drop thunder .wav/.ogg files into `thunder_clips`.
	# (AudioStreamGenerator requires a per-frame _process_audio callback which
	#  is overkill for a one-shot SFX — real audio clips are the right tool.)
	if OS.has_feature("debug"):
		print("[ThunderComponent] No audio clips assigned — drop .wav/.ogg files into thunder_clips. (volume=%.1f dB, pitch=%.2f)" % [volume, pitch])

# ============================================================================
# HELPERS
# ============================================================================
func _find_weather_manager() -> WeatherManager:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group(&"weather_manager") as WeatherManager
