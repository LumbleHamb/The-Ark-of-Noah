class_name DetectionComponent
extends Component

## Detects when targets enter/exit a proximity area by group membership.
## Creates or reuses an Area2D child for detection.

signal target_entered(body: Node2D)
signal target_exited(body: Node2D)

@export var detection_radius: float = 48.0
@export var target_group: String = "Player"

var area: Area2D = null
var detected_targets: Array[Node2D] = []

func _component_ready() -> void:
	var entity := get_entity()
	var existing_area := entity.get_node_or_null("DetectionArea") as Area2D
	if existing_area:
		area = existing_area
		area.collision_mask = 2
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		return
	# Create the detection area as a child of the ENTITY (a Node2D) so it has a
	# valid 2D transform and participates in physics detection. We defer the
	# add_child call until the entity's _ready() has finished building children,
	# otherwise Godot errors with "Parent is busy setting up children".
	area = Area2D.new()
	area.name = "DetectionArea"
	area.collision_mask = 2
	area.monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = detection_radius
	shape.shape = circle
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_add_area_deferred.call_deferred(entity, area)

func _add_area_deferred(entity: Node, a: Area2D) -> void:
	if not is_instance_valid(entity) or not is_instance_valid(a):
		return
	entity.add_child(a)

## Returns the closest detected target, or null if none.
func get_closest_target() -> Node2D:
	if detected_targets.is_empty():
		return null
	var entity := get_entity() as Node2D
	if not entity:
		return detected_targets[0]
	var closest: Node2D = detected_targets[0]
	var closest_dist := entity.global_position.distance_squared_to(closest.global_position)
	for target: Node2D in detected_targets:
		var d := entity.global_position.distance_squared_to(target.global_position)
		if d < closest_dist:
			closest = target
			closest_dist = d
	return closest

func has_target() -> bool:
	return not detected_targets.is_empty()

## Returns true if the closest target is within the given distance.
func is_target_too_close(threshold: float) -> bool:
	var target := get_closest_target()
	if not target:
		return false
	var entity := get_entity() as Node2D
	if not entity:
		return false
	var d := entity.global_position.distance_squared_to(target.global_position)
	return d < threshold * threshold

## Returns true if the closest target is beyond the given safe distance.
func is_target_safe(threshold: float) -> bool:
	var target := get_closest_target()
	if not target:
		return true
	var entity := get_entity() as Node2D
	if not entity:
		return true
	var d := entity.global_position.distance_squared_to(target.global_position)
	return d > threshold * threshold

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(target_group):
		if not detected_targets.has(body):
			detected_targets.append(body)
			target_entered.emit(body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(target_group):
		detected_targets.erase(body)
		target_exited.emit(body)
