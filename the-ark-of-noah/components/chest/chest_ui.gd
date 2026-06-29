extends CanvasLayer

## ============================================================================
## CHEST UI CONTROLLER — The dual-inventory overlay shown when opening a chest.
##
## Registered as the "ChestUI" autoload singleton so it is always available.
## Hidden by default.  When the player opens a ChestComponent, the player calls
## ChestUI.show_for(chest); this controller:
##   1. Binds the LEFT grid to the player's InventoryComponent.
##   2. Binds the RIGHT grid to the chest's storage InventoryComponent.
##   3. Shows the overlay (and dims / pauses input appropriately).
##
## The two InventoryGrids handle drag/drop and cross-grid transfers on their
## own (see InventoryGrid._end_drag → transfer_to).  Closing is done by
## pressing E again, ESC, or the Close button — all call hide().
##
## The controller runs in PROCESS_MODE_ALWAYS so it works even if the world is
## paused (e.g. the player opens the book, then a chest — unusual but safe).
## ============================================================================

signal chest_ui_opened(chest: ChestComponent)
signal chest_ui_closed()

@onready var dimmer: TextureRect = %Dimmer
@onready var panel: PanelContainer = %Panel
@onready var player_label: Label = %PlayerLabel
@onready var chest_label: Label = %ChestLabel
@onready var player_grid: InventoryGrid = %PlayerGrid
@onready var chest_grid: InventoryGrid = %ChestGrid
@onready var close_button: BaseButton = %CloseButton

var _chest: ChestComponent = null
var _player_inventory: InventoryComponent = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	close_button.pressed.connect(close_ui)

func _process(_delta: float) -> void:
	# Close on ESC or E (interact) while open.
	if visible:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pause"):
			close_ui()

## Shows the chest UI bound to the given chest.  Resolves the player inventory
## from the "player" group.
func show_for(chest: ChestComponent) -> void:
	if chest == null:
		return
	show_for_inventories(_resolve_player_inventory_for_return(), chest.get_storage(), "Your Inventory", "Chest (%d slots)" % chest.chest_capacity)
	_chest = chest
	chest_ui_opened.emit(chest)

func show_for_inventories(left_inventory: InventoryComponent, right_inventory: InventoryComponent, left_title: String = "Inventory", right_title: String = "Storage") -> void:
	if left_inventory == null or right_inventory == null:
		push_warning("ChestUI: cannot show dual inventory; one side is null")
		return
	_player_inventory = left_inventory
	player_grid.bind_inventory(left_inventory)
	chest_grid.bind_inventory(right_inventory)
	player_label.text = left_title
	chest_label.text = right_title
	dimmer.modulate.a = 0.35
	visible = true

func close_ui() -> void:
	if _chest and _chest.is_open():
		_chest.close()
	# Re-enable player input after closing chest.
	if _player_inventory != null:
		var owner_node: Node = _player_inventory.get_parent()
		if owner_node != null and owner_node.has_method(&"set_player_paused"):
			owner_node.call("set_player_paused", false)
	_chest = null
	dimmer.modulate.a = 0.0
	visible = false
	chest_ui_closed.emit()

func _resolve_player_inventory() -> void:
	_player_inventory = _resolve_player_inventory_for_return()

func _resolve_player_inventory_for_return() -> InventoryComponent:
	if get_tree() == null:
		return null
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player")
	if player:
		for child: Node in player.get_children():
			if child is InventoryComponent:
				return child as InventoryComponent
	return null
