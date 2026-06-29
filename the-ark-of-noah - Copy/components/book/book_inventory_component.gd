class_name BookInventoryComponent
extends Control

## ============================================================================
## BOOK INVENTORY COMPONENT — The inventory page of the pause book.
##
## REUSES the player's InventoryComponent — it does NOT duplicate inventory
## logic.  It builds a title, an equipment panel showing the equipped tool,
## and a reusable InventoryGrid bound to the player's items.  The grid handles
## drag/drop, tooltips, and split entirely on its own; this component just
## wires it to the right inventory and refreshes it whenever the page opens.
##
## Works while the game is paused (the book runs in PROCESS_MODE_ALWAYS).
## Implements the BookPage interface (on_page_opened / on_page_closed).
## ============================================================================

signal page_opened()
signal page_closed()

@export var page_title: String = "Inventory"

@export var inventory_owner_path: NodePath = NodePath("")

var _inventory: InventoryComponent = null
var _grid: InventoryGrid = null
var _equip_label: Label = null

func _ready() -> void:
	_build_ui()

func on_page_opened() -> void:
	# Re-resolve the inventory each time the page opens (player may respawn).
	_resolve_inventory()
	if _grid and _inventory:
		_grid.bind_inventory(_inventory)
	_refresh_equipment()
	page_opened.emit()

func on_page_closed() -> void:
	page_closed.emit()

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------
func _resolve_inventory() -> void:
	_inventory = null
	var inventory_owner: Node = null
	if inventory_owner_path != NodePath(""):
		inventory_owner = get_node_or_null(inventory_owner_path)
	if inventory_owner == null and get_tree() != null:
		inventory_owner = get_tree().get_first_node_in_group(&"player")
	if inventory_owner:
		for child: Node in inventory_owner.get_children():
			if child is InventoryComponent:
				_inventory = child as InventoryComponent
				break

func _build_ui() -> void:
	# Title.
	var title: Label = Label.new()
	title.text = page_title
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.31, 0.19, 0.08, 1))
	title.position = Vector2(8, 4)
	title.size = Vector2(320, 28)
	add_child(title)

	# Equipment panel — shows the currently equipped tool.
	_equip_label = Label.new()
	_equip_label.add_theme_font_size_override("font_size", 14)
	_equip_label.add_theme_color_override("font_color", Color(0.4, 0.28, 0.12, 1))
	_equip_label.position = Vector2(8, 30)
	_equip_label.size = Vector2(320, 20)
	_equip_label.text = "Equipped: (none)"
	add_child(_equip_label)

	# Drag/drop item grid (reusable InventoryGrid), constrained to the page.
	_grid = InventoryGrid.new()
	_grid.position = Vector2(8, 56)
	_grid.size = Vector2(336, 320)
	_grid.clip_contents = true
	add_child(_grid)

func _refresh_equipment() -> void:
	if _equip_label == null:
		return
	if _inventory == null:
		_equip_label.text = "Equipped: (no inventory)"
		return
	var tool: ToolData = _inventory.get_equipped_tool()
	if tool:
		_equip_label.text = "Equipped: %s" % tool.tool_name
	elif _inventory.tool_inventory.size() > 0:
		_equip_label.text = "Equipped: (none — pick a tool slot 1-%d)" % _inventory.tool_inventory.size()
	else:
		_equip_label.text = "Equipped: (no tools)"
