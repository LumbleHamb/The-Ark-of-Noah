class_name BookInventoryComponent
extends Control

## ============================================================================
## BOOK INVENTORY COMPONENT — Inventory page constrained to the book page area.
##
## REUSES the existing InventoryComponent on the player — it does NOT duplicate
## inventory logic.  On open it locates the player's InventoryComponent and
## reads its tool_inventory + seed_inventory arrays to populate a slot grid.
##
## Constraints:
##   - All icons are placed inside a clip_contents container so nothing spills
##     outside the paper bounds.
##   - The grid is a ScrollContainer so it scales with inventory size.
## Implements the BookPage interface via duck-typing.
## ============================================================================

signal page_opened()
signal page_closed()

## Title displayed at the top of the page.
@export var page_title: String = "Inventory"

## Path to a node with an InventoryComponent. If empty, the player is found
## via the "player" group and its InventoryComponent child.
@export var inventory_owner_path: NodePath = NodePath("")

const SLOT_SIZE: float = 48.0
const SLOT_GAP: float = 4.0
const SLOT_COLS: int = 4

var _grid: GridContainer = null
var _scroll: ScrollContainer = null
var _empty_slot_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")
var _inventory: InventoryComponent = null
var _slot_nodes: Array[TextureRect] = []

func _ready() -> void:
	_build_ui()

func on_page_opened() -> void:
	# Re-resolve the inventory each time the page opens (player may respawn).
	_resolve_inventory()
	_refresh_slots()
	page_opened.emit()

func on_page_closed() -> void:
	page_closed.emit()

func _resolve_inventory() -> void:
	_inventory = null
	var owner: Node = null
	if inventory_owner_path != NodePath(""):
		owner = get_node_or_null(inventory_owner_path)
	if owner == null and get_tree() != null:
		owner = get_tree().get_first_node_in_group(&"player")
	if owner:
		for child: Node in owner.get_children():
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

	# Scrollable clip container — constrains icons to the page area.
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(8, 36)
	_scroll.size = Vector2(336, 440)
	_scroll.clip_contents = true
	add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = SLOT_COLS
	_grid.add_theme_constant_override("h_separation", int(SLOT_GAP))
	_grid.add_theme_constant_override("v_separation", int(SLOT_GAP))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	# Build an initial empty grid; refreshed on open.
	_refresh_slots()

func _refresh_slots() -> void:
	# Clear existing.
	for child in _grid.get_children():
		child.queue_free()
	_slot_nodes.clear()

	var tools: Array = []
	var seeds: Array = []
	if _inventory:
		tools = _inventory.tool_inventory
		seeds = _inventory.seed_inventory

	var total: int = (tools.size() if tools else 0) + (seeds.size() if seeds else 0)
	# Ensure at least a few empty slots so the page doesn't look empty.
	var min_slots: int = max(total, SLOT_COLS * 2)

	for i in range(min_slots):
		var slot: TextureRect = TextureRect.new()
		slot.name = "Slot_%02d" % i
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		if i < (tools.size() if tools else 0):
			var tool: ToolData = tools[i]
			slot.texture = tool.icon if tool.icon else _empty_slot_texture
			slot.tooltip_text = tool.tool_name
		elif i < total:
			var seed_idx: int = i - (tools.size() if tools else 0)
			var crop: CropData = seeds[seed_idx]
			slot.texture = crop.seed_sprite if crop.seed_sprite else _empty_slot_texture
			slot.tooltip_text = crop.crop_name
		else:
			slot.texture = _empty_slot_texture
		_grid.add_child(slot)
		_slot_nodes.append(slot)
