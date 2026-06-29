class_name WorldFlow
extends Node

## Connects world objective completion to phase-2 cutscene architecture.

@export var phase2_cutscene_path: String = "res://scenes/cutscenes/phase2_cutscene_placeholder.tscn"

func _ready() -> void:
	var construction: Node = get_parent().get_node_or_null("BoatConstructionArea")
	if construction == null:
		return
	var component: Node = construction.get_node_or_null("ConstructionAreaComponent")
	if component != null and component.has_signal("construction_completed"):
		component.construction_completed.connect(_on_boat_completed)

func _on_boat_completed(_name: String) -> void:
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null and stats_node.has_method("set_stat"):
		stats_node.call("set_stat", "boat_construction_stage", 3)
	var transition_node: Node = get_node_or_null("/root/scene_transition")
	if transition_node != null and transition_node.has_method("transition"):
		transition_node.call("transition", phase2_cutscene_path)
	else:
		get_tree().change_scene_to_file(phase2_cutscene_path)
