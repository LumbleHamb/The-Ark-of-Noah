class_name EnemyManager
extends Node2D

const EnemyLootDatabaseScript: Script = preload("res://scripts/loot/enemy_loot_database.gd")
const EnemyLootConfigScript: Script = preload("res://scripts/loot/enemy_loot_config.gd")
const LootDropResolverScript: Script = preload("res://scripts/loot/loot_drop_resolver.gd")

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
@export var biome_system_path: NodePath
@export var difficulty_level: float = 1.0
@export var loot_database: Resource

@export_category("Performance")
@export var enable_spatial_cache: bool = true
@export var spatial_cell_size: float = 192.0
@export var spatial_refresh_interval: float = 0.25
@export var player_refresh_interval: float = 0.4

var active_enemies: Array[Node2D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _biome_system: BiomeSystem
var _cached_player: Node2D
var _player_refresh_timer: float = 0.0
var _spatial_refresh_timer: float = 0.0
var _spatial_cells: Dictionary = {}
var _enemy_scene_by_node: Dictionary = {}
var _loot_spawned_for_enemy: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	if biome_system_path.is_empty() == false:
		_biome_system = get_node_or_null(biome_system_path) as BiomeSystem
	for _i: int in range(starting_enemy_count):
		spawn_enemy()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_player_refresh_timer -= delta
	_spatial_refresh_timer -= delta
	if _player_refresh_timer <= 0.0:
		_player_refresh_timer = player_refresh_interval
		_cached_player = _find_player_uncached()
	if enable_spatial_cache and _spatial_refresh_timer <= 0.0:
		_spatial_refresh_timer = spatial_refresh_interval
		_rebuild_spatial_cache()


func spawn_enemy() -> void:
	if active_enemies.size() >= max_enemies:
		return

	var spawn_data: Dictionary = _resolve_spawn_candidates()
	var roster: Array[PackedScene] = spawn_data.get("roster", []) as Array[PackedScene]
	var weights: Array[float] = spawn_data.get("weights", []) as Array[float]
	if roster.is_empty():
		push_warning("EnemyManager: No enemy scenes in active roster.")
		return

	var scene_to_spawn: PackedScene = _pick_weighted_scene(roster, weights)
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
	_enemy_scene_by_node[enemy] = scene_to_spawn
	enemy.tree_exited.connect(_on_enemy_removed.bind(enemy))
	_connect_enemy_death(enemy)


func _connect_enemy_death(enemy: Node2D) -> void:
	var health_component: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		return
	if not health_component.died.is_connected(_on_enemy_died):
		health_component.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)


func _on_enemy_died(enemy: Node2D) -> void:
	if _loot_spawned_for_enemy.has(enemy):
		return
	_loot_spawned_for_enemy[enemy] = true
	if loot_database == null:
		return
	var scene_ref: PackedScene = _enemy_scene_by_node.get(enemy, null) as PackedScene
	if loot_database == null or loot_database.get_script() != EnemyLootDatabaseScript:
		return
	var loot_config_variant: Variant = loot_database.call("get_config_for_scene", scene_ref)
	if not (loot_config_variant is Resource) or (loot_config_variant as Resource).get_script() != EnemyLootConfigScript:
		return
	var loot_config: Resource = loot_config_variant as Resource
	var biome_id: String = "default"
	if _biome_system != null:
		biome_id = _biome_system.get_biome_id_at_global_position(enemy.global_position)
	LootDropResolverScript.call("spawn_enemy_drops", enemy, loot_config, biome_id, difficulty_level)


func _on_enemy_removed(enemy: Node2D) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)
	_enemy_scene_by_node.erase(enemy)
	_loot_spawned_for_enemy.erase(enemy)
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
	_enemy_scene_by_node.clear()
	_loot_spawned_for_enemy.clear()


func set_zone_roster(zone_name: String) -> void:
	biome_zone_name = zone_name


func _resolve_spawn_candidates() -> Dictionary:
	var roster: Array[PackedScene] = []
	var weights: Array[float] = []

	if _biome_system != null:
		var player_node: Node2D = _find_player()
		var lookup_pos: Vector2 = player_node.global_position if player_node != null else global_position
		var biome: BiomeDefinition = _biome_system.get_biome_at_global_position(lookup_pos)
		if biome != null:
			for entry: BiomeEnemyEntry in biome.enemy_entries:
				if entry == null or entry.enemy_scene == null:
					continue
				if difficulty_level < entry.min_difficulty or difficulty_level > entry.max_difficulty:
					continue
				roster.append(entry.enemy_scene)
				weights.append(maxf(0.01, entry.weight * biome.difficulty_multiplier))

	if roster.is_empty():
		roster = _resolve_roster()
		if enemy_weights.size() == roster.size():
			weights.assign(enemy_weights)
		else:
			for _i: int in range(roster.size()):
				weights.append(1.0)

	return {"roster": roster, "weights": weights}


func _resolve_roster() -> Array[PackedScene]:
	if roster_by_zone.has(biome_zone_name):
		var zone_roster_variant: Variant = roster_by_zone[biome_zone_name]
		if zone_roster_variant is Array:
			var zone_roster: Array = zone_roster_variant as Array
			var out: Array[PackedScene] = []
			for item: Variant in zone_roster:
				if item is PackedScene:
					out.append(item as PackedScene)
			if out.is_empty() == false:
				return out
	return enemy_scenes


func _pick_weighted_scene(roster: Array[PackedScene], weights: Array[float]) -> PackedScene:
	if roster.is_empty():
		return null
	if weights.size() != roster.size():
		return roster.pick_random()

	var total: float = 0.0
	for weight: float in weights:
		total += maxf(0.0, weight)
	if total <= 0.001:
		return roster.pick_random()

	var roll: float = _rng.randf_range(0.0, total)
	var accumulator: float = 0.0
	for i: int in range(roster.size()):
		accumulator += maxf(0.0, weights[i])
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
		if _is_navigation_point_reachable(candidate) == false:
			continue
		return candidate

	return fallback


func _too_close_to_enemies(candidate: Vector2) -> bool:
	if enable_spatial_cache and _spatial_cells.is_empty() == false:
		var cell: Vector2i = _to_cell(candidate)
		for y_offset: int in range(-1, 2):
			for x_offset: int in range(-1, 2):
				var key: Vector2i = Vector2i(cell.x + x_offset, cell.y + y_offset)
				var bucket_variant: Variant = _spatial_cells.get(key, null)
				if not (bucket_variant is Array):
					continue
				var bucket: Array = bucket_variant as Array
				for enemy_variant: Variant in bucket:
					if not (enemy_variant is Node2D):
						continue
					var enemy: Node2D = enemy_variant as Node2D
					if is_instance_valid(enemy) == false:
						continue
					if candidate.distance_to(enemy.global_position) < min_spawn_distance_from_enemies:
						return true
		return false

	for enemy: Node2D in active_enemies:
		if is_instance_valid(enemy) == false:
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
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	_cached_player = _find_player_uncached()
	return _cached_player


func _find_player_uncached() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _rebuild_spatial_cache() -> void:
	_spatial_cells.clear()
	for enemy: Node2D in active_enemies:
		if is_instance_valid(enemy) == false:
			continue
		var key: Vector2i = _to_cell(enemy.global_position)
		var bucket_variant: Variant = _spatial_cells.get(key, null)
		var bucket: Array = []
		if bucket_variant is Array:
			bucket = bucket_variant as Array
		bucket.append(enemy)
		_spatial_cells[key] = bucket


func _to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / spatial_cell_size), floori(world_pos.y / spatial_cell_size))
