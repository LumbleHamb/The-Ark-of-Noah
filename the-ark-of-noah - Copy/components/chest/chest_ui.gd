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

@onready var dimmer: ColorRect = %Dimmer
@onready var panel: PanelContainer = %Panel
@onready var player_label: Label = %PlayerLabel
@onready var chest_label: Label = %ChestLabel
@onready var player_grid: InventoryGrid = %PlayerGrid
@onready var chest_grid: InventoryGrid = %ChestGrid
@onready var close_button: Button = %CloseButton

var _chest: ChestComponent = null
var _player_inventory: InventoryComponent = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.color.a = 0.0
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
	_chest = chest
	_resolve_player_inventory()
	if _player_inventory == null:
		push_warning("ChestUI: no player inventory found; cannot show chest UI.")
		return
	player_grid.bind_inventory(_player_inventory)
	chest_grid.bind_inventory(chest.get_storage())
	chest_label.text = "Chest (%d slots)" % chest.chest_capacity
	player_label.text = "Your Inventory"
	dimmer.color.a = 0.35
	visible = true
	chest_ui_opened.emit(chest)

func close_ui() -> void:
	if _chest and _chest.is_open():
		_chest.close()
	_chest = null
	dimmer.color.a = 0.0
	visible = false
	chest_ui_closed.emit()

func _resolve_player_inventory() -> void:
	_player_inventory = null
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player")
	if player:
		for child: Node in player.get_children():
			if child is InventoryComponent:
				_player_inventory = child as InventoryComponent
				break
