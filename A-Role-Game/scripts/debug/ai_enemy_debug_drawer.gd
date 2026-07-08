class_name AIEnemyDebugDrawer
extends Node2D

var ai: Variant
var _state_label: Label


func _ready() -> void:
	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.position = Vector2(-42.0, -86.0)
	_state_label.scale = Vector2(0.7, 0.7)
	add_child(_state_label)


func _process(_delta: float) -> void:
	if OS.has_feature("release"):
		set_process(false)
		visible = false
		return
	if AIDebug.should_draw() == false:
		if visible:
			visible = false
		return
	if visible == false:
		visible = true
	if _state_label != null:
		_state_label.visible = AIDebug.should_draw_state_label()
		if _state_label.visible and ai != null:
			if ai.has_method("get_state_name"):
				_state_label.text = String(ai.call("get_state_name"))
	queue_redraw()


func _draw() -> void:
	if ai == null:
		return
	var detection: float = float(ai.get("detection_range"))
	var hearing: float = float(ai.get("hearing_range"))
	var attack: float = float(ai.get("attack_range"))
	var use_projectile: bool = bool(ai.get("use_projectile_attack"))
	var ranged: float = float(ai.get("ranged_attack_range"))
	var player_node: Node2D = ai.get("player") as Node2D
	var nav_agent: NavigationAgent2D = ai.get("nav_agent") as NavigationAgent2D
	var entity_node: CharacterBody2D = ai.get("entity") as CharacterBody2D
	if AIDebug.should_draw_ranges():
		draw_arc(Vector2.ZERO, detection, 0.0, TAU, 48, Color(0.1, 0.8, 1.0, 0.25), 1.5)
		draw_arc(Vector2.ZERO, hearing, 0.0, TAU, 48, Color(0.4, 1.0, 0.4, 0.22), 1.2)
		draw_arc(Vector2.ZERO, attack, 0.0, TAU, 48, Color(1.0, 0.5, 0.2, 0.25), 1.2)
		if use_projectile:
			draw_arc(Vector2.ZERO, ranged, 0.0, TAU, 64, Color(0.8, 0.4, 1.0, 0.2), 1.0)
	if AIDebug.should_draw_los() and player_node != null and is_instance_valid(player_node):
		draw_line(Vector2.ZERO, to_local(player_node.global_position), Color(0.6, 1.0, 0.6, 0.65), 1.2)
	if AIDebug.should_draw_navigation() and nav_agent != null and is_instance_valid(nav_agent):
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		draw_line(Vector2.ZERO, to_local(next_pos), Color(0.2, 0.7, 1.0, 0.85), 1.6)
	if AIDebug.should_draw_velocity() and entity_node != null:
		draw_line(Vector2.ZERO, entity_node.velocity * 0.25, Color(1.0, 1.0, 0.2, 0.8), 1.3)
