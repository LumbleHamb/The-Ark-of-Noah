class_name WanderComponent
extends Component

## AI wandering for NPCs/animals. Picks random targets within a radius and moves toward them.

signal started_wandering(target: Vector2)
signal stopped_wandering()
signal reached_target()

@export var wander_radius: float = 128.0
@export var walk_speed: float = 30.0
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 8.0
@export var wander_chance: float = 0.4
@export var detection_component_path: NodePath = NodePath("")

var home_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var is_wandering: bool = false
var idle_timer: float = 0.0
var _detection: DetectionComponent = null

func _component_ready() -> void:
	var entity := get_entity() as Node2D
	if entity:
		home_position = entity.global_position
	if detection_component_path != NodePath(""):
		_detection = get_node(detection_component_path) as DetectionComponent
	if _detection == null:
		_detection = get_sibling_component_by_name("DetectionComponent") as DetectionComponent
	_pick_new_idle_time()

## Starts wandering to a random target within wander_radius.
func start_wandering() -> void:
	if is_wandering:
		return
	is_wandering = true
	target_position = _pick_wander_target()
	started_wandering.emit(target_position)

func stop_wandering() -> void:
	is_wandering = false
	stopped_wandering.emit()

## Processes idle timer. Returns true if wandering started.
func process_idle(delta: float) -> bool:
	idle_timer -= delta
	if idle_timer <= 0.0:
		if _detection and _detection.is_target_too_close(48.0):
			return false
		if randf() < wander_chance:
			start_wandering()
			return true
		else:
			_pick_new_idle_time()
	return false

## Processes wandering movement. Returns true when target reached.
func process_wander(_delta: float, entity: CharacterBody2D) -> bool:
	if _detection and _detection.is_target_too_close(48.0):
		stop_wandering()
		return false
	var dist := entity.global_position.distance_squared_to(target_position)
	if dist < 16.0:
		stop_wandering()
		_pick_new_idle_time()
		reached_target.emit()
		return true
	var move_dir := entity.global_position.direction_to(target_position)
	entity.velocity = move_dir * walk_speed
	entity.move_and_slide()
	return false

## Returns the direction toward the wander target, or zero if not wandering.
func get_move_direction() -> Vector2:
	if not is_wandering:
		return Vector2.ZERO
	var entity := get_entity() as Node2D
	if not entity:
		return Vector2.ZERO
	return entity.global_position.direction_to(target_position)

func _pick_wander_target() -> Vector2:
	var offset := Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	return home_position + offset

func _pick_new_idle_time() -> void:
	idle_timer = randf_range(idle_time_min, idle_time_max)
