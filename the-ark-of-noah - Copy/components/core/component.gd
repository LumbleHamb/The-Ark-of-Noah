class_name Component
extends Node

## Base class for all components in the entity-component system.
## Components are children of entity nodes. Each owns one specific behavior.
## Subclasses override _component_ready() instead of _ready().

signal component_enabled()
signal component_disabled()

@export var active: bool = true:
	set(v):
		active = v
		_apply_active_state()

func _ready() -> void:
	_apply_active_state()
	_component_ready()

## Override in subclasses instead of _ready().
func _component_ready() -> void:
	pass

## Returns the entity (parent node) this component is attached to.
func get_entity() -> Node:
	return get_parent()

## Finds another component on the same entity by script class.
func get_sibling_component(component_class: Script) -> Component:
	for child: Node in get_parent().get_children():
		if child.get_script() == component_class:
			return child as Component
	return null

## Finds another component on the same entity by node name.
func get_sibling_component_by_name(comp_name: String) -> Component:
	var child := get_parent().get_node_or_null(comp_name)
	if child is Component:
		return child as Component
	return null

func _apply_active_state() -> void:
	if active:
		component_enabled.emit()
	else:
		component_disabled.emit()
	set_process(active)
	set_physics_process(active)
	set_process_input(active)
	set_process_unhandled_input(active)
