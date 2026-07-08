class_name AIDebug
extends Node

@export var enabled: bool = false
@export var draw_state_label: bool = true
@export var draw_ranges: bool = true
@export var draw_los: bool = true
@export var draw_navigation: bool = true
@export var draw_velocity: bool = false

static var _instance: AIDebug


func _ready() -> void:
	_instance = self


static func should_draw() -> bool:
	if OS.has_feature("release"):
		return false
	if _instance == null:
		return false
	return _instance.enabled


static func should_draw_state_label() -> bool:
	return should_draw() and _instance.draw_state_label


static func should_draw_ranges() -> bool:
	return should_draw() and _instance.draw_ranges


static func should_draw_los() -> bool:
	return should_draw() and _instance.draw_los


static func should_draw_navigation() -> bool:
	return should_draw() and _instance.draw_navigation


static func should_draw_velocity() -> bool:
	return should_draw() and _instance.draw_velocity


static func set_enabled(v: bool) -> void:
	if _instance != null:
		_instance.enabled = v
