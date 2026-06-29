class_name ConstructionAreaComponent
extends Component

signal resource_deposited(item_id: String, amount: int)
signal stage_progressed(stage_index: int)
signal construction_completed(construction_name: String)

@export var construction_name: String = "Construction"
@export var stages: Array[ConstructionStageResource] = []
@export var construction_plan: ConstructionPlanResource = null
@export var current_stage: int = 0
@export var blueprint_sprite: Texture2D = null
@export var completed_scene: PackedScene = null
@export var interact_radius: float = 60.0
@export var accepted_resource_types: Array[String] = []
@export var auto_spawn_stage_scene: bool = true

var _interact_area: Area2D = null
var _deposited_by_stage: Dictionary = {}
var _active_stage_node: Node2D = null
var _is_finished: bool = false

func _component_ready() -> void:
	add_to_group(&"construction_area")
	_apply_plan_if_present()
	_build_interact_zone()
	_refresh_visuals()

func _apply_plan_if_present() -> void:
	if construction_plan != null and construction_plan.stages.size() > 0:
		stages = construction_plan.stages.duplicate()

func is_player_in_zone() -> bool:
	if _interact_area == null:
		return false
	for body: Node2D in _interact_area.get_overlapping_bodies():
		if body.is_in_group(&"player") or body.is_in_group(&"Player"):
			return true
	return false

func is_finished() -> bool:
	return _is_finished

func get_current_stage() -> ConstructionStageResource:
	if current_stage < 0 or current_stage >= stages.size():
		return null
	return stages[current_stage]

func try_deposit(item_id: String, amount: int = 1) -> int:
	if _is_finished:
		return 0
	if amount <= 0:
		return 0
	var stage: ConstructionStageResource = get_current_stage()
	if stage == null:
		return 0
	if accepted_resource_types.size() > 0 and not accepted_resource_types.has(item_id):
		return 0
	var requirement: Resource = _find_requirement(stage, item_id)
	if requirement == null:
		return 0
	var key: String = _stage_item_key(current_stage, item_id)
	var already: int = int(_deposited_by_stage.get(key, 0))
	var remaining: int = maxi(requirement.amount - already, 0)
	if remaining <= 0:
		return 0
	var accepted: int = mini(amount, remaining)
	_deposited_by_stage[key] = already + accepted
	resource_deposited.emit(item_id, accepted)
	if _is_stage_complete(stage):
		_advance_stage()
	return accepted

func get_required_count(item_id: String) -> int:
	var stage: ConstructionStageResource = get_current_stage()
	if stage == null:
		return 0
	var requirement: Resource = _find_requirement(stage, item_id)
	if requirement == null:
		return 0
	return requirement.amount

func get_deposited_count(item_id: String) -> int:
	var key: String = _stage_item_key(current_stage, item_id)
	return int(_deposited_by_stage.get(key, 0))

func _find_requirement(stage: ConstructionStageResource, item_id: String) -> Resource:
	for requirement: Resource in stage.requirements:
		if requirement != null and requirement.item_id == item_id:
			return requirement
	return null

func _is_stage_complete(stage: ConstructionStageResource) -> bool:
	for requirement: Resource in stage.requirements:
		if requirement == null:
			continue
		var key: String = _stage_item_key(current_stage, requirement.item_id)
		var deposited: int = int(_deposited_by_stage.get(key, 0))
		if deposited < requirement.amount:
			return false
	return true

func _advance_stage() -> void:
	current_stage += 1
	if current_stage >= stages.size():
		_complete_construction()
		return
	stage_progressed.emit(current_stage)
	_refresh_visuals()

func _complete_construction() -> void:
	_is_finished = true
	construction_completed.emit(construction_name)
	if completed_scene != null:
		var entity: Node2D = get_entity() as Node2D
		if entity != null and entity.get_parent() != null:
			var completed_instance: Node2D = completed_scene.instantiate() as Node2D
			entity.get_parent().add_child(completed_instance)
			completed_instance.global_position = entity.global_position
			completed_instance.global_rotation = entity.global_rotation
	var entity_to_free: Node = get_entity()
	if entity_to_free != null:
		entity_to_free.queue_free()

func _refresh_visuals() -> void:
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return
	var blueprint_node: Sprite2D = entity.get_node_or_null("BlueprintSprite") as Sprite2D
	if blueprint_node == null:
		blueprint_node = Sprite2D.new()
		blueprint_node.name = "BlueprintSprite"
		entity.add_child.call_deferred(blueprint_node)
	if blueprint_sprite != null:
		blueprint_node.texture = blueprint_sprite
	blueprint_node.visible = current_stage <= 0
	if _active_stage_node != null:
		_active_stage_node.queue_free()
		_active_stage_node = null
	if not auto_spawn_stage_scene:
		return
	var stage: ConstructionStageResource = get_current_stage()
	if stage != null and stage.stage_scene != null:
		_active_stage_node = stage.stage_scene.instantiate() as Node2D
		if _active_stage_node != null:
			_active_stage_node.name = "StageVisual"
			entity.add_child.call_deferred(_active_stage_node)

func _build_interact_zone() -> void:
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return
	_interact_area = entity.get_node_or_null("InteractZone") as Area2D
	if _interact_area != null:
		return
	_interact_area = Area2D.new()
	_interact_area.name = "InteractZone"
	_interact_area.monitoring = true
	_interact_area.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	_interact_area.add_child(shape)
	entity.add_child.call_deferred(_interact_area)

func _stage_item_key(stage_index: int, item_id: String) -> String:
	return "%d:%s" % [stage_index, item_id]
