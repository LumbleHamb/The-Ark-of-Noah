class_name EncounterDirector
extends Node

@export var enemy_manager_path: NodePath
@export var base_difficulty: float = 1.0
@export var max_difficulty: float = 4.0
@export var escalation_per_minute: float = 0.08
@export var calm_player_distance_threshold: float = 300.0
@export var calm_difficulty_multiplier: float = 0.92
@export var pressure_floor: float = 0.75

var _enemy_manager: EnemyManager
var _difficulty: float = 1.0
var _time_accumulator: float = 0.0

func _ready() -> void:
	_difficulty = base_difficulty
	_enemy_manager = get_node_or_null(enemy_manager_path) as EnemyManager
	set_process(_enemy_manager != null)

func _process(delta: float) -> void:
	if _enemy_manager == null:
		return
	_time_accumulator += delta
	if _time_accumulator < 1.0:
		return
	_time_accumulator = 0.0
	_update_difficulty()
	_enemy_manager.difficulty_level = _difficulty

func _update_difficulty() -> void:
	var next_difficulty: float = _difficulty + escalation_per_minute / 60.0
	var player_node: Node2D = _enemy_manager.call("_find_player") as Node2D
	if player_node != null:
		var dist: float = player_node.global_position.distance_to(_enemy_manager.global_position)
		if dist > calm_player_distance_threshold:
			next_difficulty *= calm_difficulty_multiplier
	next_difficulty = maxf(pressure_floor, next_difficulty)
	_difficulty = clampf(next_difficulty, 0.2, max_difficulty)
