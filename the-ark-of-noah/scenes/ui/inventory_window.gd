class_name InventoryWindow
extends CanvasLayer

## ============================================================================
## INVENTORY WINDOW
##
## Standalone inventory UI (separate from pause book).
## Uses InventoryGrid as reusable slot UI and can bind to any InventoryComponent.
## ============================================================================

signal inventory_opened()
signal inventory_closed()

@onready var dimmer: TextureRect = %Dimmer
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var inventory_grid: InventoryGrid = %InventoryGrid
@onready var hotbar_grid: InventoryGrid = %HotbarGrid

var _bound_inventory: InventoryComponent = null
var _hotbar_visual_inventory: InventoryComponent = null
var _hotbar_refresh_queued: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0

func _process(_delta: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed("pause"):
		close_ui()

func toggle_ui() -> void:
	if visible:
		close_ui()
		return
	if _is_blocked_by_other_overlay():
		return
	open_ui()

func open_ui() -> void:
	if _is_blocked_by_other_overlay():
		return
	_bind_player_inventory()
	if _bound_inventory == null:
		return
	inventory_grid.bind_inventory(_bound_inventory)
	hotbar_grid.bind_inventory(_bound_inventory)
	_sync_hotbar_grid()
	if not _bound_inventory.items_changed.is_connected(_on_inventory_items_changed):
		_bound_inventory.items_changed.connect(_on_inventory_items_changed)
	visible = true
	dimmer.modulate.a = 0.35
	_set_player_paused(true)
	inventory_opened.emit()

func close_ui() -> void:
	if _bound_inventory != null and _bound_inventory.items_changed.is_connected(_on_inventory_items_changed):
		_bound_inventory.items_changed.disconnect(_on_inventory_items_changed)
	visible = false
	dimmer.modulate.a = 0.0
	_set_player_paused(false)
	inventory_closed.emit()

func is_open() -> bool:
	return visible

func open_for_inventory(inventory: InventoryComponent, title: String = "Inventory") -> void:
	_bound_inventory = inventory
	if _bound_inventory == null:
		return
	title_label.text = title
	inventory_grid.bind_inventory(_bound_inventory)
	hotbar_grid.bind_inventory(_bound_inventory)
	_sync_hotbar_grid()
	if not _bound_inventory.items_changed.is_connected(_on_inventory_items_changed):
		_bound_inventory.items_changed.connect(_on_inventory_items_changed)
	visible = true
	dimmer.modulate.a = 0.35
	inventory_opened.emit()

func _bind_player_inventory() -> void:
	_bound_inventory = null
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		player = tree.get_first_node_in_group(&"Player")
	if player == null:
		return
	for child: Node in player.get_children():
		if child is InventoryComponent:
			_bound_inventory = child as InventoryComponent
			break

func _set_player_paused(paused: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group(&"player")
	if player == null:
		player = tree.get_first_node_in_group(&"Player")
	if player != null and player.has_method(&"set_player_paused"):
		player.call("set_player_paused", paused)

func _on_inventory_items_changed() -> void:
	if not visible:
		return
	_sync_hotbar_grid()

func _sync_hotbar_grid() -> void:
	if _bound_inventory == null or hotbar_grid == null:
		return
	if _hotbar_refresh_queued:
		return
	_hotbar_refresh_queued = true
	call_deferred("_deferred_sync_hotbar_grid")

func _deferred_sync_hotbar_grid() -> void:
	_hotbar_refresh_queued = false
	if _bound_inventory == null or hotbar_grid == null:
		return
	if _hotbar_visual_inventory == null:
		_hotbar_visual_inventory = InventoryComponent.new()
	_hotbar_visual_inventory.items.clear()
	_hotbar_visual_inventory.item_capacity = _bound_inventory.get_hotbar_slot_count()
	for i: int in range(_hotbar_visual_inventory.item_capacity):
		var stack: ItemStack = ItemStack.new()
		stack.item_id = "hotbar_%d" % i
		stack.item_name = _bound_inventory.get_hotbar_slot_label(i)
		stack.icon = _bound_inventory.get_hotbar_texture(i)
		stack.count = 1
		stack.max_stack = 1
		stack.stackable = false
		_hotbar_visual_inventory.items.append(stack)
	hotbar_grid.bind_inventory(_hotbar_visual_inventory)

func _is_blocked_by_other_overlay() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var chest_ui: CanvasLayer = tree.root.get_node_or_null("ChestUI") as CanvasLayer
	if chest_ui != null and chest_ui.visible:
		return true
	var pause_menu: CanvasLayer = tree.root.get_node_or_null("PauseMenu") as CanvasLayer
	if pause_menu == null:
		return false
	if pause_menu.has_method(&"is_open"):
		return bool(pause_menu.call("is_open"))
	return pause_menu.visible
