class_name FadeComponent
extends Component

## Fade in/out transitions for any CanvasItem entity.
## Call fade_in() / fade_out() to trigger transitions.

signal fade_started(direction: String)
signal fade_completed(direction: String)

@export var fade_in_duration: float = 0.5
@export var fade_out_duration: float = 0.8
@export var auto_fade_in: bool = true

var _fade_tween: Tween = null
var _entity_canvas: CanvasItem = null

func _component_ready() -> void:
	_entity_canvas = _find_canvas_item()
	if not _entity_canvas:
		push_warning("FadeComponent: no CanvasItem found on entity ", get_entity().name)
		return
	if auto_fade_in:
		fade_in()

## Fades from transparent to opaque over the given duration.
func fade_in(duration: float = -1.0) -> void:
	if not _entity_canvas:
		return
	var dur: float = fade_in_duration if duration < 0 else duration
	_kill_tween()
	_entity_canvas.modulate.a = 0.0
	fade_started.emit("in")
	_fade_tween = create_tween()
	_fade_tween.tween_property(_entity_canvas, ^"modulate:a", 1.0, dur)
	_fade_tween.finished.connect(_on_fade_in_complete.bind(dur))

## Fades from opaque to transparent over the given duration.
func fade_out(duration: float = -1.0) -> void:
	if not _entity_canvas:
		return
	var dur: float = fade_out_duration if duration < 0 else duration
	_kill_tween()
	fade_started.emit("out")
	_fade_tween = create_tween()
	_fade_tween.tween_property(_entity_canvas, ^"modulate:a", 0.0, dur)
	_fade_tween.finished.connect(_on_fade_out_complete.bind(dur))

## Returns true if a fade tween is currently active.
func is_fading() -> bool:
	return _fade_tween != null and _fade_tween.is_valid()

## Stops any active fade immediately.
func kill_fade() -> void:
	_kill_tween()

func _on_fade_in_complete(_duration: float) -> void:
	fade_completed.emit("in")

func _on_fade_out_complete(_duration: float) -> void:
	fade_completed.emit("out")

func _kill_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

func _find_canvas_item() -> CanvasItem:
	var parent := get_parent()
	if parent is CanvasItem:
		return parent as CanvasItem
	var current := parent
	while current:
		if current is CanvasItem:
			return current as CanvasItem
		current = current.get_parent()
	return null
