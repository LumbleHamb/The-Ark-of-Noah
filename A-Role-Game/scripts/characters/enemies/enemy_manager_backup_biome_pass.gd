class_name EnemyManagerBiomeBackup
extends Node2D

@export_category("Enemy Settings")
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: Array[float] = []
@export var max_enemies: int = 20

@export_category("Spawn Settings")
@export var spawn_radius: float = 360.0
@export var min_spawn_distance_from_player: float = 180.0
@export var min_spawn_distance_from_enemies: float = 80.0
@export var starting_enemy_count: int = 8
@export var auto_respawn: bool = true
@export var respawn_delay: float = 2.5
@export var max_spawn_attempts: int = 18

@export_category("Encounter / Zone")
@export var biome_zone_name: String = "default"
@export var roster_by_zone: Dictionary = {}

var active_enemies: Array[Node2D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for _i: int in range(starting_enemy_count):
		spawn_enemy()


func spawn_enemy() -> void:
	if active_enemies.size() >= max_enemies:
		return

	var roster: Array[PackedScene] = _resolve_roster()
	if roster.is_empty():
		push_warning("EnemyManager: No enemy scenes in active roster.")
		return

	var scene_to_spawn: PackedScene = _pick_weighted_scene(roster)
	if scene_to_spawn == null:
		return

	var enemy_node: Node = scene_to_spawn.instantiate()
	if not (enemy_node is Node2D):
		return

	var enemy: Node2D = enemy_node as Node2D
	var spawn_pos: Vector2 = _find_valid_spawn_position()
	add_child(enemy)
	enemy.global_position = spawn_pos
	active_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))


func _on_enemy_removed(enemy: Node2D) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	if auto_respawn:
		_schedule_respawn()


func _schedule_respawn() -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(respawn_delay).timeout
	if get_tree() == null:
		return
	spawn_enemy()


func get_enemy_count() -> int:
	return active_enemies.size()


func clear_all_enemies() -> void:
	for enemy: Node2D in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()


func set_zone_roster(zone_name: String) -> void:
	biome_zone_name = zone_name


func _resolve_roster() -> Array[PackedScene]:
	if roster_by_zone.has(biome_zone_name):
		var zone_roster_variant: Variant = roster_by_zone[biome_zone_name]
		if zone_roster_variant is Array:
			var zone_roster: Array = zone_roster_variant as Array
			var out: Array[PackedScene] = []
			for item: Variant in zone_roster:
				if item is PackedScene:
					out.append(item as PackedScene)
			if not out.is_empty():
				return out
	return enemy_scenes


func _pick_weighted_scene(roster: Array[PackedScene]) -> PackedScene:
	if roster.is_empty():
		return null
	if enemy_weights.size() != roster.size():
		return roster.pick_random()

	var total: float = 0.0
	for weight: float in enemy_weights:
		total += maxf(0.0, weight)
	if total <= 0.001:
		return roster.pick_random()

	var roll: float = _rng.randf_range(0.0, total)
	var accumulator: float = 0.0
	for i: int in range(roster.size()):
		accumulator += maxf(0.0, enemy_weights[i])
		if roll <= accumulator:
			return roster[i]
	return roster[roster.size() - 1]


func _find_valid_spawn_position() -> Vector2:
	var fallback: Vector2 = global_position + Vector2(_rng.randf_range(-spawn_radius, spawn_radius), _rng.randf_range(-spawn_radius, spawn_radius))
	var player_node: Node2D = _find_player()

	for _attempt: int in range(max_spawn_attempts):
		var candidate: Vector2 = global_position + Vector2(_rng.randf_range(-spawn_radius, spawn_radius), _rng.randf_range(-spawn_radius, spawn_radius))
		if player_node != null and candidate.distance_to(player_node.global_position) < min_spawn_distance_from_player:
			continue
		if _too_close_to_enemies(candidate):
			continue
		if not _is_navigation_point_reachable(candidate):
			continue
		return candidate

	return fallback


func _too_close_to_enemies(candidate: Vector2) -> bool:
	for enemy: Node2D in active_enemies:
		if not is_instance_valid(enemy):
			continue
		if candidate.distance_to(enemy.global_position) < min_spawn_distance_from_enemies:
			return true
	return false


func _is_navigation_point_reachable(point: Vector2) -> bool:
	var map_rid: RID = get_world_2d().navigation_map
	if map_rid.is_valid() == false:
		return true
	if NavigationServer2D.map_get_iteration_id(map_rid) <= 0:
		return true
	var nearest: Vector2 = NavigationServer2D.map_get_closest_point(map_rid, point)
	return nearest.distance_to(point) <= 96.0


func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as Node2D
