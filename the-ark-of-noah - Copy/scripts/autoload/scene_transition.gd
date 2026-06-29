extends CanvasLayer

## Singleton autoload that provides smooth fade-to-black / fade-from-black transitions.

## Persists across scene changes. Call transition() to use it.

var _color_rect: ColorRect

func _ready() -> void:
	layer = 128
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)

## Fades to black, changes scene, then fades back in.
func transition(scene_path: String, fade_duration: float = 0.5) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_color_rect, "color:a", 1.0, fade_duration)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_color_rect, "color:a", 0.0, fade_duration)
	await tween.finished
