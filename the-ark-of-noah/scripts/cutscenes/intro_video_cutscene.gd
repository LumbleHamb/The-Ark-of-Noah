class_name IntroVideoCutscene
extends Control

@export var next_scene_path: String = "res://scenes/world/world.tscn"
@export var fallback_duration_seconds: float = 3.0
@export var video_resource_path: String = "res://video.mp4"

@onready var video_player: VideoStreamPlayer = %VideoPlayer
@onready var fallback_label: Label = %FallbackLabel

func _ready() -> void:
	video_player.finished.connect(_on_video_finished)
	if _try_play_video(video_resource_path):
		return
	fallback_label.text = "Intro video not found or unsupported. Add your video at:\n%s" % video_resource_path
	fallback_label.visible = true
	await get_tree().create_timer(fallback_duration_seconds).timeout
	_transition_to_next_scene()

func _try_play_video(path: String) -> bool:
	if path.strip_edges().is_empty():
		return false
	var loaded_resource: Resource = ResourceLoader.load(path)
	if loaded_resource == null:
		return false
	if loaded_resource is VideoStream:
		video_player.stream = loaded_resource as VideoStream
		video_player.play()
		return true
	return false

func _on_video_finished() -> void:
	_transition_to_next_scene()

func _transition_to_next_scene() -> void:
	var transition_node: Node = get_node_or_null("/root/scene_transition")
	if transition_node != null and transition_node.has_method("transition"):
		transition_node.call("transition", next_scene_path)
	else:
		get_tree().change_scene_to_file(next_scene_path)
