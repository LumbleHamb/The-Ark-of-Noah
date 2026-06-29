class_name SettingsPopup
extends PopupPanel

## Placeholder settings popup for audio/camera/controls/credits.

@onready var master_slider: HSlider = %MasterVolumeSlider
@onready var music_slider: HSlider = %MusicVolumeSlider
@onready var sfx_slider: HSlider = %SfxVolumeSlider
@onready var zoom_in_button: Button = %ZoomInButton
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var close_button: Button = %CloseButton

var _target_camera: Camera2D = null

func _ready() -> void:
	close_button.pressed.connect(hide)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

func set_target_camera(camera: Camera2D) -> void:
	_target_camera = camera

func _on_zoom_in_pressed() -> void:
	if _target_camera == null:
		return
	_target_camera.zoom = (_target_camera.zoom * 0.9).clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

func _on_zoom_out_pressed() -> void:
	if _target_camera == null:
		return
	_target_camera.zoom = (_target_camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clampf(value, 0.001, 1.0)))

func _on_music_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(value, 0.001, 1.0)))

func _on_sfx_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(value, 0.001, 1.0)))
