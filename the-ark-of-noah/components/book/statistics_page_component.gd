class_name StatisticsPageComponent
extends Control

## ============================================================================
## STATISTICS PAGE COMPONENT
##
## Book page that renders gameplay statistics from the GameStats autoload.
## Designed to be data-driven: it loops through a dictionary, so adding new
## stats only requires registering a new key in GameStats.
## ============================================================================

signal page_opened()
signal page_closed()

@export var page_title: String = "Statistics"

var _title_label: Label = null
var _stats_container: VBoxContainer = null

func _ready() -> void:
	_build_ui()

func on_page_opened() -> void:
	_refresh_stats()
	page_opened.emit()

func on_page_closed() -> void:
	page_closed.emit()

func _build_ui() -> void:
	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.set_anchors_preset(PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 20)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_right", 20)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(root_margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	root_margin.add_child(layout)

	_title_label = Label.new()
	_title_label.text = page_title
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.31, 0.19, 0.08, 1))
	layout.add_child(_title_label)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_stats_container = VBoxContainer.new()
	_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_stats_container)

func _refresh_stats() -> void:
	if _stats_container == null:
		return
	for child: Node in _stats_container.get_children():
		child.queue_free()

	var game_stats_node: Node = get_node_or_null("/root/game_stats")
	if game_stats_node == null or not game_stats_node.has_method("get_all_stats"):
		var missing_label: Label = Label.new()
		missing_label.text = "GameStats autoload not found."
		missing_label.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2, 1))
		_stats_container.add_child(missing_label)
		return

	var stats: Dictionary = game_stats_node.call("get_all_stats") as Dictionary
	for stat_key: String in stats.keys():
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = game_stats_node.call("format_stat_name", stat_key) as String
		name_label.add_theme_color_override("font_color", Color(0.36, 0.24, 0.1, 1))
		row.add_child(name_label)

		var value_label: Label = Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = str(stats[stat_key])
		value_label.add_theme_color_override("font_color", Color(0.2, 0.16, 0.08, 1))
		row.add_child(value_label)

		_stats_container.add_child(row)
