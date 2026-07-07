extends Node


## Tracks the player's recent movement trail as invisible breadcrumbs.
## Enemies use these to follow the player when line-of-sight is broken.
##
## Breadcrumbs are dropped at regular intervals based on distance moved,
## forming a trail of the player's last N positions.


## Maximum number of breadcrumbs to keep in the trail.
@export var max_trail_length: int = 10

## Minimum distance in pixels between breadcrumbs (avoids clumping).
@export var spacing_pixels: float = 16.0

## How often (in seconds) to check for new breadcrumb positions.
@export var update_interval: float = 0.1


## The trail of breadcrumb positions (most recent at the end).
var trail: Array[Vector2] = []

## The player node reference (found via group lookup).
var _player: Node2D = null

## Timer for periodic position checks.
var _timer: float = 0.0

## Last position where a breadcrumb was dropped.
var _last_crumb_pos: Vector2 = Vector2.ZERO

## Whether a first breadcrumb has been placed (to seed the trail).
var _has_seed: bool = false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0

	_find_player()
	if _player == null:
		return

	var pos: Vector2 = _player.global_position

	# Seed the first breadcrumb immediately.
	if not _has_seed:
		_add_crumb(pos)
		_has_seed = true
		return

	# Only add a new breadcrumb if the player has moved far enough.
	if pos.distance_squared_to(_last_crumb_pos) >= spacing_pixels * spacing_pixels:
		_add_crumb(pos)


func _add_crumb(pos: Vector2) -> void:
	trail.append(pos)
	_last_crumb_pos = pos

	# Trim excess breadcrumbs from the front (oldest first).
	while trail.size() > max_trail_length:
		trail.pop_front()


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


## Returns the full breadcrumb trail (oldest first).
func get_trail() -> Array[Vector2]:
	return trail.duplicate()


## Returns the most recent breadcrumbs up to `count`.
func get_recent(count: int) -> Array[Vector2]:
	var start: int = max(0, trail.size() - count)
	return trail.slice(start, trail.size())


## Clears all breadcrumbs.
func clear_trail() -> void:
	trail.clear()
	_has_seed = false


## Sets the maximum breadcrumb trail length (configurable at runtime).
## Returns the new value.
func set_trail_length(length: int) -> int:
	max_trail_length = max(1, length)
	while trail.size() > max_trail_length:
		trail.pop_front()
	return max_trail_length
