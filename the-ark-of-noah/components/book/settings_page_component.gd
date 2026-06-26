class_name SettingsPageComponent
extends Control

## ============================================================================
## SETTINGS PAGE COMPONENT — The first visible page when the book opens.
##
## Populated with placeholder settings text across typical categories:
## Graphics, Audio, Gameplay, Controls, Accessibility, Language.
##
## This is a placeholder — the user will connect actual settings later.
## The page is built procedurally so adding/removing categories is trivial.
## Implements the BookPage interface (on_page_opened/on_page_closed) via
## duck-typing so it doesn't depend on a base class at parse time.
## ============================================================================

signal page_opened()
signal page_closed()

## Title displayed at the top of the page.
@export var page_title: String = "Settings"

## Categories to display (left = category list, right = placeholder detail).
@export var categories: Array[String] = [
	"Graphics",
	"Audio",
	"Gameplay",
	"Controls",
	"Accessibility",
	"Language",
]

var _selected_category: int = 0
var _category_list: VBoxContainer = null
var _detail_panel: VBoxContainer = null

func _ready() -> void:
	_build_ui()

## Called by the BookUIController when this page becomes visible.
func on_page_opened() -> void:
	page_opened.emit()

## Called by the BookUIController when navigating away from this page.
func on_page_closed() -> void:
	page_closed.emit()

func _build_ui() -> void:
	# Full-rect margins.
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(hbox)

	# Left: title + category list.
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	var title: Label = Label.new()
	title.text = page_title
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.31, 0.19, 0.08, 1))
	title.custom_minimum_size = Vector2(0, 40)
	left.add_child(title)

	_category_list = VBoxContainer.new()
	_category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_category_list)

	for i in range(categories.size()):
		var cat_label: Label = Label.new()
		cat_label.text = categories[i]
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_label.add_theme_color_override("font_color",
			Color(0.4, 0.28, 0.12, 1) if i == _selected_category else Color(0.5, 0.35, 0.15, 0.7))
		cat_label.custom_minimum_size = Vector2(0, 28)
		cat_label.gui_input.connect(_on_category_gui_input.bind(i))
		_category_list.add_child(cat_label)

	# Right: placeholder detail panel.
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(180, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	var detail_title: Label = Label.new()
	detail_title.text = categories[_selected_category]
	detail_title.add_theme_font_size_override("font_size", 20)
	detail_title.add_theme_color_override("font_color", Color(0.31, 0.19, 0.08, 1))
	detail_title.custom_minimum_size = Vector2(0, 40)
	right.add_child(detail_title)

	_detail_panel = VBoxContainer.new()
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail_panel)
	_populate_placeholder_detail()

func _populate_placeholder_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()
	var placeholder: Label = Label.new()
	placeholder.text = "(Placeholder — connect actual " + categories[_selected_category] + " settings here.)"
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.35, 0.15, 0.7))
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(placeholder)

func _on_category_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index != _selected_category:
			_selected_category = index
			_rebuild_category_list()
			# Update detail title + content.
			var right_title: Label = _detail_panel.get_parent().get_child(0)
			right_title.text = categories[index]
			_populate_placeholder_detail()

func _rebuild_category_list() -> void:
	for i in range(_category_list.get_child_count()):
		var lbl: Label = _category_list.get_child(i)
		lbl.add_theme_color_override("font_color",
			Color(0.4, 0.28, 0.12, 1) if i == _selected_category else Color(0.5, 0.35, 0.15, 0.7))
