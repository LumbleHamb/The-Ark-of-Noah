class_name CreditsPageComponent
extends Control

## ============================================================================
## CREDITS PAGE COMPONENT
##
## Placeholder credits page with built-in scrolling support. Future team credits
## can be appended to `credit_lines` without changing layout code.
## ============================================================================

signal page_opened()
signal page_closed()

@export var page_title: String = "Credits"
@export var credit_lines: Array[String] = [
	"The Ark of Noah",
	"",
	"Credits Placeholder",
	"",
	"Design: TBD",
	"Programming: TBD",
	"Art: TBD",
	"Audio: TBD",
	"QA: TBD",
	"",
	"Thank you for playing!"
]

var _title_label: Label = null
var _credits_label: Label = null

func _ready() -> void:
	_build_ui()

func on_page_opened() -> void:
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

	_credits_label = Label.new()
	_credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_credits_label.text = "\n".join(credit_lines)
	_credits_label.add_theme_font_size_override("font_size", 16)
	_credits_label.add_theme_color_override("font_color", Color(0.36, 0.24, 0.1, 1))
	_credits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_credits_label)
