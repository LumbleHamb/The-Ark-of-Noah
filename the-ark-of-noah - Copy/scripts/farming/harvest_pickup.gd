class_name HarvestPickup
extends Node2D

## ============================================================================
## HARVEST PICKUP — A floating, bobbing item dropped on the ground that the
## player auto-collects by walking close.
##
## Spawned by FarmManager when a crop is harvested.  It:
##   1. Appears at the harvest tile and rises slightly with a small pop.
##   2. Bobs gently up and down forever (a sine-wave offset on position.y).
##   3. When the player enters its collect radius, it flies toward the player,
##      plays a collect "pop", adds its ItemStack to the player's inventory,
##      and frees itself.
##
## Reusable: any system that drops a ground item (farming harvest, tree felling,
## mining) can call HarvestPickup.spawn(item_stack, world_position).
##
## It finds the player via the "player" group and the player's
## InventoryComponent child, so it has no hard dependencies — drop it anywhere.
## ============================================================================

## Radius (pixels) within which the pickup auto-collects.
@export var collect_radius: float = 28.0

## How fast the pickup flies toward the player when collecting (px/s).
@export var collect_speed: float = 420.0

## How high it bobs (pixels).
@export var bob_height: float = 4.0

## How fast it bobs (cycles per second).
@export var bob_speed: float = 2.5

var _stack: ItemStack = null
var _sprite: Sprite2D = null
var _player: Node2D = null
var _player_inventory: InventoryComponent = null
var _origin_y: float = 0.0
var _age: float = 0.0
var _collecting: bool = false
var _collected: bool = false

static var _empty_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")

## Convenience spawner: creates a pickup in the given parent at a world position.
static func spawn(stack: ItemStack, parent: Node, world_position: Vector2) -> HarvestPickup:
	var pickup_scene: PackedScene = load("res://scenes/farming/harvest_pickup.tscn") as PackedScene
	var pickup: HarvestPickup = pickup_scene.instantiate()
	parent.add_child(pickup)
	pickup.global_position = world_position
	pickup.set_stack(stack)
	return pickup

func _ready() -> void:
	_origin_y = global_position.y
	# Build a sprite to show the item icon.
	_sprite = Sprite2D.new()
	_sprite.texture = _empty_texture
	_sprite.z_index = 20
	add_child(_sprite)
	# Spawn pop: start small and scale up.
	scale = Vector2(0.2, 0.2)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	# Register so the player can find nearby pickups if needed.
	add_to_group(&"pickup")

func _process(delta: float) -> void:
	_age += delta
	# Bob gently around the origin height.
	global_position.y = _origin_y - sin(_age * bob_speed * TAU) * bob_height
	if _sprite:
		_sprite.rotation = sin(_age * 2.0) * 0.05
	_resolve_player()
	if _collected:
		return
	if _collecting and is_instance_valid(_player):
		# Fly toward the player.
		var to_player: Vector2 = _player.global_position - global_position
		var dist: float = to_player.length()
		if dist < 6.0:
			_collect()
			return
		global_position += to_player.normalized() * collect_speed * delta
		_origin_y = global_position.y
		return
	# Check if the player is within the collect radius.
	if is_instance_valid(_player):
		var d: float = global_position.distance_to(_player.global_position)
		if d <= collect_radius:
			_collecting = true

## Sets the item stack this pickup represents and updates the sprite.
func set_stack(stack: ItemStack) -> void:
	_stack = stack
	if _sprite and stack and stack.icon:
		_sprite.texture = stack.icon

func _resolve_player() -> void:
	if is_instance_valid(_player):
		return
	if get_tree() == null:
		return
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"Player") as Node2D
	if _player and _player_inventory == null:
		for child: Node in _player.get_children():
			if child is InventoryComponent:
				_player_inventory = child as InventoryComponent
				break

func _collect() -> void:
	if _collected:
		return
	_collected = true
	# Add the stack to the player's inventory (merging if possible).
	if _player_inventory and _stack:
		var leftover: int = _player_inventory.add_item(_stack)
		if leftover > 0:
			# Couldn't fit everything; leave the remainder on the ground.
			_stack.count = leftover
			_collected = false
			_collecting = false
			return
	# Collect pop animation, then free.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.06)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
