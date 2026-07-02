class_name ChunkManager
extends Node

## Chunk-based loading/unloading system for large open-world maps.
##
## Divides the world into a grid of chunks (default 320×320 px = 10 tiles each).
## Monitors the player's position and shows/hides entities per chunk, also
## disabling their _process/_physics_process (via PROCESS_MODE_DISABLED) to
## save both rendering and CPU resources.
##
## Entities register by adding themselves to the "chunked" group OR by calling
## register_node() / unregister_node() directly (preferred for dynamically
## spawned objects such as farm crops).
##
## The TileMapLayer itself always remains visible — Godot's camera frustum
## culling already takes care of off-screen tile rendering.

# ============================================================================
# EXPORTS
# ============================================================================

## Chunk size in pixels (default: 320 = 10 tiles × 32 px).
@export var chunk_size: float = 320.0

## How many chunks to keep loaded in each cardinal direction around the player.
## Total loaded chunks = (render_distance × 2 + 1)².
@export var render_distance: int = 2

## Path to the player node.
@export var player_path: NodePath = NodePath("../player")

## If true, hidden nodes also get PROCESS_MODE_DISABLED (saves CPU).
@export var pause_processing_when_hidden: bool = true

# ============================================================================
# STATE
# ============================================================================

var player: Node2D = null
var _last_player_chunk: Vector2i = Vector2i(-99999, -99999)

## chunk_coord → Array[Node2D]
var _chunk_registry: Dictionary = {}

## Node → chunk_coord  (fast reverse lookup for unregister).
var _node_to_chunk: Dictionary = {}

## Cached set of currently-active chunk coords (as Dictionary keys for O(1) lookups).
var _active_chunks: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	player = get_node_or_null(player_path) as Node2D
	if player == null:
		# Fallback: find the Player scene instance
		var nodes_in_group: Array[Node] = get_tree().get_nodes_in_group(&"Player")
		if nodes_in_group.size() > 0:
			player = nodes_in_group[0] as Node2D

	_register_all_grouped_nodes()
	_update_chunks()

func _physics_process(_delta: float) -> void:
	_update_chunks()

# ============================================================================
# PUBLIC API
# ============================================================================

## Register a single node with the chunk system.
## Call this for dynamically spawned entities (farm crops, placed objects, etc.).
func register_node(node: Node2D) -> void:
	var chunk_coord: Vector2i = _world_to_chunk(node.global_position)
	if not _chunk_registry.has(chunk_coord):
		_chunk_registry[chunk_coord] = []
	_chunk_registry[chunk_coord].append(node)
	_node_to_chunk[node] = chunk_coord

	# Immediately apply correct visibility for this new node
	node.visible = _active_chunks.has(chunk_coord) if _active_chunks.size() > 0 else true
	if pause_processing_when_hidden and not node.visible:
		node.process_mode = PROCESS_MODE_DISABLED
	elif pause_processing_when_hidden and node.visible:
		node.process_mode = PROCESS_MODE_INHERIT

## Unregister a node (e.g. when it is removed from the world).
func unregister_node(node: Node2D) -> void:
	if not _node_to_chunk.has(node):
		return
	var chunk_coord: Vector2i = _node_to_chunk[node]
	_node_to_chunk.erase(node)
	if _chunk_registry.has(chunk_coord):
		_chunk_registry[chunk_coord].erase(node)
		if _chunk_registry[chunk_coord].is_empty():
			_chunk_registry.erase(chunk_coord)

## Convert a world position to chunk coordinates.
func world_to_chunk(world_pos: Vector2) -> Vector2i:
	return _world_to_chunk(world_pos)

## Get the chunk coordinate the player is currently in.
func get_player_chunk() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return _world_to_chunk(player.global_position)

## Force a full chunk update (e.g. after teleporting the player).
func force_update() -> void:
	_last_player_chunk = Vector2i(-99999, -99999)
	_update_chunks()

# ============================================================================
# INTERNAL
# ============================================================================

func _world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / chunk_size)),
		int(floor(pos.y / chunk_size))
	)

func _register_all_grouped_nodes() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"chunked"):
		if node is Node2D:
			register_node(node as Node2D)

func _update_chunks() -> void:
	if player == null:
		return

	var player_chunk: Vector2i = _world_to_chunk(player.global_position)
	if player_chunk == _last_player_chunk:
		return
	_last_player_chunk = player_chunk

	# Build set of active chunk coords
	var new_active: Dictionary = {}
	for dx in range(-render_distance, render_distance + 1):
		for dy in range(-render_distance, render_distance + 1):
			new_active[Vector2i(player_chunk.x + dx, player_chunk.y + dy)] = true

	_active_chunks = new_active

	# Apply visibility to every registered node
	# First, collect any freed/stale nodes to clean up (avoid erasing during iteration)
	var stale_nodes: Array = []
	for chunk_coord: Vector2i in _chunk_registry.keys():
		for node in _chunk_registry[chunk_coord]:
			if not is_instance_valid(node):
				stale_nodes.append([chunk_coord, node])

	for entry: Array in stale_nodes:
		var coord: Vector2i = entry[0]
		var freed_node = entry[1]
		_chunk_registry[coord].erase(freed_node)
		_node_to_chunk.erase(freed_node)
		if _chunk_registry[coord].is_empty():
			_chunk_registry.erase(coord)

	for chunk_coord: Vector2i in _chunk_registry.keys():
		var make_visible: bool = _active_chunks.has(chunk_coord)
		for node in _chunk_registry[chunk_coord]:
			if not is_instance_valid(node):
				continue
			if node.visible != make_visible:
				node.visible = make_visible
			if pause_processing_when_hidden:
				var desired_mode: int = PROCESS_MODE_INHERIT if make_visible else PROCESS_MODE_DISABLED
				if int(node.process_mode) != desired_mode:
					node.process_mode = desired_mode as Node.ProcessMode
