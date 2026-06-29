class_name CutscenePlaceholder
extends Control

## Generic placeholder cutscene timeline.

@export var next_scene_path: String = "res://scenes/world/world.tscn"
@export var duration_seconds: float = 2.0
@export var caption_text: String = "# PLACEHOLDER: Cutscene"

@onready var caption_label: Label = %CaptionLabel

func _ready() -> void:
	caption_label.text = caption_text
	await get_tree().create_timer(duration_seconds).timeout
	var transition_node: Node = get_node_or_null("/root/scene_transition")
	if transition_node != null and transition_node.has_method("transition"):
		transition_node.call("transition", next_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene_path)
