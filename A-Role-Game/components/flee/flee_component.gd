class_name FleeComponent
extends Component

## Fleeing behavior for NPCs/animals when the player gets too close.
## Works with DetectionComponent to determine flee timing and safe distance.

signal started_fleeing(direction: Vector2)
signal finished_fleeing()

@export var flee_distance: float = 48.0
@export var flee_safe_distance: float = 200.0
@export var flee_speed: float = 60.0
@export var detection_component_path: NodePath = NodePath("")

var is_fleeing: bool = false
var flee_direction: Vector2 = Vector2.ZERO
var _detection: DetectionComponent = null

func _component_ready() -> void:
	if detection_component_path != NodePath(""):
		_detection = get_node(detection_component_path) as DetectionComponent
	if _detection == null:
		_detection = get_sibling_component_by_name("DetectionComponent") as DetectionComponent

## Starts fleeing in a direction away from the nearest target.
func start_fleeing() -> void:
	if is_fleeing:
		return
	is_fleeing = true
	flee_direction = _get_flee_direction()
	started_fleeing.emit(flee_direction)

## Stops fleeing and emits finished_fleeing.
func stop_fleeing() -> void:
	is_fleeing = false
	finished_fleeing.emit()

## Processes one frame of flee movement. Returns true when safe distance reached.
func process_flee(entity: CharacterBody2D) -> bool:
	if not is_fleeing:
		return false
	var target := _detection.get_closest_target() if _detection else null
	if target:
		flee_direction = _get_flee_direction_from_target(target)
	entity.velocity = flee_direction * flee_speed
	entity.move_and_slide()
	if _detection and _detection.is_target_safe(flee_safe_distance):
		stop_fleeing()
		return true
	return false

func get_flee_direction() -> Vector2:
	return flee_direction

## Returns true if the closest target is within the flee trigger distance.
func should_start_fleeing() -> bool:
	if not _detection:
		return false
	return _detection.is_target_too_close(flee_distance)

func _get_flee_direction() -> Vector2:
	var target := _detection.get_closest_target() if _detection else null
	if not target:
		return Vector2.RIGHT
	return _get_flee_direction_from_target(target)

func _get_flee_direction_from_target(target: Node2D) -> Vector2:
	var entity := get_entity() as Node2D
	if not entity:
		return Vector2.RIGHT
	var away := entity.global_position - target.global_position
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	return away.normalized()
