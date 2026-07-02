class_name ChestComponent
extends Component

## ============================================================================
## CHEST COMPONENT — Reusable storage chest that the player can open.
##
## Drop this on any Node2D to turn it into an interactable chest.  It owns:
##   - An InventoryComponent (the chest's own storage, with a designer-set
##     capacity via `chest_capacity` — supports chests of any size).
##   - An Area2D interaction zone (built procedurally) so the player can detect
##     "is there a chest near me?" via the "chest" group.
##
## How the player opens it:
##   1. The player's interact handler scans the "chest" group for a chest whose
##      interaction zone currently contains the player.
##   2. The player calls chest.open_for(player) — this emits `chest_opened` and
##      the ChestUI autoload shows the chest's grid next to the player's grid.
##   3. The player drags items between the two grids; InventoryGrid.transfer_to
##      moves stacks between the two InventoryComponents.
##   4. chest.close() closes the UI and emits `chest_closed`.
##
## Save/Load: ChestComponent.get_save_data() / load_from_save() serialise the
## chest's item array so chest contents persist.  The SaveManager can iterate
## every chest in the "chest" group to save them all.
##
## Reusable: supports unlimited chest instances, each with its own capacity.
## ============================================================================

signal chest_opened(chest: ChestComponent)
signal chest_closed(chest: ChestComponent)
signal contents_changed()

## How many item slots this chest holds. Set per-chest in the Inspector.
@export var chest_capacity: int = 48

## Radius (pixels) of the interaction zone around the chest.
@export var interact_radius: float = 40.0
## Fallback distance check (pixels) used even if Area2D overlap misses.
@export var interact_distance: float = 160.0

## Optional AnimatedSprite2D child to play an "open" animation on open/close.
@export var open_animation: String = "chest_opening"

var _storage: InventoryComponent = null
var _interact_area: Area2D = null
var _anim_sprite: AnimatedSprite2D = null
var _is_open: bool = false

func _component_ready() -> void:
	# Register with the "chest" group so the player and SaveManager can find us.
	add_to_group(&"chest")
	# Build the chest's own storage inventory.
	_storage = InventoryComponent.new()
	_storage.item_capacity = chest_capacity
	_storage.items_changed.connect(_on_contents_changed)
	# Find an optional animated sprite on the entity for the open animation.
	_anim_sprite = get_entity().get_node_or_null("ChestAnimation") as AnimatedSprite2D
	# Build the interaction zone (Area2D + circle shape) on the entity.
	_build_interact_zone()

# ---------------------------------------------------------------------------
# STORAGE ACCESS
# ---------------------------------------------------------------------------
## Returns the chest's InventoryComponent (its storage).
func get_storage() -> InventoryComponent:
	return _storage

## Returns true if the player is currently standing in this chest's zone.
func is_player_in_zone() -> bool:
	if _interact_area != null:
		for body: Node2D in _interact_area.get_overlapping_bodies():
			if body.is_in_group(&"player") or body.is_in_group(&"Player"):
				return true
	# Fallback: direct distance from chest entity to player node.
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var player_node: Node2D = tree.get_first_node_in_group(&"Player") as Node2D
	if player_node == null:
		player_node = tree.get_first_node_in_group(&"player") as Node2D
	if player_node == null:
		return false
	return entity.global_position.distance_to(player_node.global_position) <= interact_distance

## Opens the chest.  Emits chest_opened; the ChestUI listens and shows the grid.
func open_for(_player: Node) -> void:
	if _is_open:
		return
	_is_open = true
	if _anim_sprite and _anim_sprite.sprite_frames:
		if _anim_sprite.sprite_frames.has_animation(open_animation):
			_anim_sprite.play(open_animation)
	chest_opened.emit(self)

## Closes the chest.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	chest_closed.emit(self)

func is_open() -> bool:
	return _is_open

func _on_contents_changed() -> void:
	contents_changed.emit()

# ---------------------------------------------------------------------------
# INTERACTION ZONE
# ---------------------------------------------------------------------------
func _build_interact_zone() -> void:
	var entity: Node2D = get_entity() as Node2D
	if entity == null:
		return
	# Reuse an existing "InteractZone" Area2D if the scene already has one.
	var existing: Area2D = entity.get_node_or_null("InteractZone") as Area2D
	if existing:
		_interact_area = existing
		return
	_interact_area = Area2D.new()
	_interact_area.name = "InteractZone"
	_interact_area.monitoring = true
	# Collide against the player's physics body (layer 1).
	_interact_area.collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = interact_radius
	shape.shape = circle
	_interact_area.add_child(shape)
	entity.add_child.call_deferred(_interact_area)

# ---------------------------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"capacity": chest_capacity,
		"items": _storage.get_save_data(),
	}

func load_from_save(data: Dictionary) -> void:
	chest_capacity = int(data.get("capacity", chest_capacity))
	_storage.item_capacity = chest_capacity
	_storage.load_from_save(data.get("items", {}))
