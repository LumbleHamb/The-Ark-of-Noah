class_name SettingsPageComponent
extends Control

## ============================================================================
## SETTINGS PAGE COMPONENT
##
## Book settings page with practical controls grouped by category:
## - Audio: master/music/sfx sliders.
## - Graphics: camera zoom, fullscreen, vsync.
## - Controls: key-rebind placeholder text.
## - Gameplay: future-options placeholder text.
##
## Uses project settings for fullscreen/vsync persistence and keeps all widgets
## clipped to the page rect.
## ============================================================================

signal page_opened()
signal page_closed()

@export var page_title: String = "Settings"
@export var categories: Array[String] = ["Audio", "Graphics", "Controls", "Gameplay"]

var _selected_category: int = 0
var _category_list: VBoxContainer = null
var _detail_panel: VBoxContainer = null
var _detail_title: Label = null

var _master_slider: HSlider = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _zoom_slider: HSlider = null
var _fullscreen_checkbox: CheckBox = null
var _vsync_checkbox: CheckBox = null

func _ready() -> void:
	_build_ui()
	_load_display_settings()

func on_page_opened() -> void:
	_rebuild_category_list()
	_show_category(_selected_category)
	page_opened.emit()

func on_page_closed() -> void:
	page_closed.emit()

func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	var title: Label = Label.new()
	title.text = page_title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.31, 0.19, 0.08, 1))
	left.add_child(title)

	_category_list = VBoxContainer.new()
	_category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_category_list)

	for i: int in range(categories.size()):
		var category_button: Button = Button.new()
		category_button.text = categories[i]
		category_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		category_button.pressed.connect(_on_category_selected.bind(i))
		_category_list.add_child(category_button)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	_detail_title = Label.new()
	_detail_title.text = categories[_selected_category]
	_detail_title.add_theme_font_size_override("font_size", 18)
	_detail_title.add_theme_color_override("font_color", Color(0.31, 0.19, 0.08, 1))
	right.add_child(_detail_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail_panel)

	_show_category(_selected_category)

func _on_category_selected(index: int) -> void:
	if index == _selected_category:
		return
	_selected_category = index
	_rebuild_category_list()
	_show_category(index)

func _rebuild_category_list() -> void:
	for i: int in range(_category_list.get_child_count()):
		var category_button: Button = _category_list.get_child(i) as Button
		if category_button == null:
			continue
		category_button.disabled = i == _selected_category

func _show_category(index: int) -> void:
	if _detail_panel == null:
		return
	for child: Node in _detail_panel.get_children():
		child.queue_free()

	_detail_title.text = categories[index]

	match categories[index]:
		"Audio":
			_build_audio_settings()
		"Graphics":
			_build_graphics_settings()
		"Controls":
			_build_controls_settings()
		"Gameplay":
			_build_gameplay_settings()
		_:
			_build_placeholder("No settings available yet.")

func _build_audio_settings() -> void:
	_master_slider = _create_slider_row("Master Volume", 0.0, 1.0, 0.01, 1.0)
	_music_slider = _create_slider_row("Music Volume", 0.0, 1.0, 0.01, 0.8)
	_sfx_slider = _create_slider_row("Sound Effects", 0.0, 1.0, 0.01, 0.8)

	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

func _build_graphics_settings() -> void:
	_zoom_slider = _create_slider_row("Camera Zoom", 0.5, 2.0, 0.05, 1.0)
	_zoom_slider.value_changed.connect(_on_zoom_changed)

	_fullscreen_checkbox = _create_checkbox("Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

	_vsync_checkbox = _create_checkbox("VSync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	_vsync_checkbox.toggled.connect(_on_vsync_toggled)

func _build_controls_settings() -> void:
	_build_placeholder("Key rebinding UI placeholder.\n\nFuture: list actions and allow remapping keys/gamepad buttons.")

func _build_gameplay_settings() -> void:
	_build_placeholder("Gameplay options placeholder.\n\nFuture: crop growth speed, tutorial hints, difficulty options.")

func _build_placeholder(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.5, 0.35, 0.15, 1))
	_detail_panel.add_child(label)

func _create_slider_row(label_text: String, min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var row: VBoxContainer = VBoxContainer.new()
	_detail_panel.add_child(row)

	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(0.36, 0.24, 0.1, 1))
	row.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = clampf(value, min_value, max_value)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	return slider

func _create_checkbox(label_text: String, toggled_on: bool) -> CheckBox:
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = label_text
	checkbox.button_pressed = toggled_on
	checkbox.add_theme_color_override("font_color", Color(0.36, 0.24, 0.1, 1))
	_detail_panel.add_child(checkbox)
	return checkbox

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))

func _on_music_volume_changed(value: float) -> void:
	if AudioServer.get_bus_count() > 1:
		AudioServer.set_bus_volume_db(1, linear_to_db(maxf(value, 0.001)))

func _on_sfx_volume_changed(value: float) -> void:
	if AudioServer.get_bus_count() > 2:
		AudioServer.set_bus_volume_db(2, linear_to_db(maxf(value, 0.001)))

func _on_zoom_changed(value: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		player = tree.get_first_node_in_group(&"Player")
	if player != null:
		var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.zoom = Vector2.ONE * value

func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)

func _load_display_settings() -> void:
	pass
