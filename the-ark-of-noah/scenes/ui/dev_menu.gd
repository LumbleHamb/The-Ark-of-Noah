class_name DevMenu
extends CanvasLayer

## ============================================================================
## DEVELOPER MENU — Infinite item palette for debugging.
##
## Opens as an overlay (toggled with F12) showing every registered item in a
## scrollable grid.  Drag any item from the palette into the player's inventory
## (right panel) — the palette is an infinite source, so items are copied, not
## moved.
##
## Layout (mirrors ChestUI for consistency):
##   ┌─────────────────────────────────────────────┐
##   │  ⚒ Dev Menu                     [Close]     │
##   ├──────────────────────┬──────────────────────┤
##   │  Item Palette        │  Player Inventory    │
##   │  ┌──┬──┬──┬──┬──┐   │  ┌──┬──┬──┬──┬──┐   │
##   │  │  │  │  │  │  │   │  │  │  │  │  │  │   │
##   │  │  │  │  │  │  │   │  │  │  │  │  │  │   │
##   │  └──┴──┴──┴──┴──┘   │  └──┴──┴──┴──┴──┘   │
##   └──────────────────────┴──────────────────────┘
##
## Drag FROM palette TO player inventory to give yourself items.
## ============================================================================

signal dev_menu_opened()
signal dev_menu_closed()

@onready var dimmer: TextureRect = %Dimmer
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var palette_grid: InventoryGrid = %PaletteGrid
@onready var player_grid: InventoryGrid = %PlayerGrid
@onready var close_button: BaseButton = %CloseButton

var _palette_inventory: DevMenuInventory = null
var _player_inventory: InventoryComponent = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	close_button.pressed.connect(close_ui)
	
	# Create the palette inventory (infinite source).
	_palette_inventory = DevMenuInventory.new()
	_palette_inventory.item_capacity = 256  # plenty of room


func _process(_delta: float) -> void:
	if not visible:
		return
	# Close on ESC.
	if Input.is_action_just_pressed("pause"):
		close_ui()


## Toggle the dev menu open/closed.
func toggle_ui() -> void:
	if visible:
		close_ui()
	else:
		open_ui()


## Opens the dev menu, resolving the player's inventory and binding both grids.
func open_ui() -> void:
	print("DevMenu: open_ui() called")
	_player_inventory = _resolve_player_inventory()
	if _player_inventory == null:
		push_warning("DevMenu: cannot find player inventory")
		return
	print("DevMenu: player inventory found, items=", _player_inventory.items.size())
	
	# Make sure palette is populated.
	_palette_inventory.refresh_items()
	print("DevMenu: palette has ", _palette_inventory.items.size(), " items, capacity=", _palette_inventory.item_capacity)
	if _palette_inventory.items.size() > 0:
		print("DevMenu: first palette item='", _palette_inventory.items[0].item_name, "' icon=", _palette_inventory.items[0].icon)
	
	# Bind grids.
	palette_grid.bind_inventory(_palette_inventory)
	player_grid.bind_inventory(_player_inventory)
	
	# Dim + show.
	dimmer.modulate.a = 0.35
	visible = true
	
	# Pause player input.
	_set_player_paused(true)
	
	dev_menu_opened.emit()


## Closes the dev menu.
func close_ui() -> void:
	visible = false
	dimmer.modulate.a = 0.0
	
	# Unpause player.
	_set_player_paused(false)
	
	dev_menu_closed.emit()


## Returns true if the dev menu is currently open.
func is_open() -> bool:
	return visible


## Resolves the player's InventoryComponent from the "player" group.
func _resolve_player_inventory() -> InventoryComponent:
	if get_tree() == null:
		return null
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player")
	if player == null:
		return null
	for child: Node in player.get_children():
		if child is InventoryComponent:
			return child as InventoryComponent
	return null


func _set_player_paused(paused: bool) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player")
	if player != null and player.has_method(&"set_player_paused"):
		player.call("set_player_paused", paused)
