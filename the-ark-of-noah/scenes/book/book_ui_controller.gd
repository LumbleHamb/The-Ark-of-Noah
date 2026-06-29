extends CanvasLayer

## ============================================================================
## BOOK UI CONTROLLER — Orchestrates the book-style pause menu.
##
## This is the single autoload (project setting: PauseMenu) that owns the
## "spellbook" overlay.  It is a thin state machine that wires together several
## reusable components and pages:
##
##   Components (children of this node):
##     - PauseComponent          → pauses / resumes the game world.
##     - BookAnimationComponent  → plays the cover open / close animation.
##     - PageTurnComponent       → plays the page-flip animation between pages.
##
##   Pages (children of BookRoot, each a Control with a Page*Component script):
##     - Page 0: Statistics (StatisticsPageComponent) — gameplay metrics
##     - Page 1: Settings   (SettingsPageComponent)   — game options
##     - Page 2: Credits    (CreditsPageComponent)    — placeholder scrolling credits
##
## The controller is data-driven: pages are discovered at runtime by scanning
## BookRoot for children whose script implements the BookPage interface
## (on_page_opened / on_page_closed).  Add a new page by dropping another
## Control under BookRoot with a *PageComponent script — no controller edits.
##
## State machine (gatekeeps ALL input so animations never overlap):
##   CLOSED → OPENING → OPEN(current) → (turn) → OPEN(next) → CLOSING → CLOSED
##
## Input:
##   - "pause" toggles the book open / close (opens to the Settings page).
## Inventory uses a separate standalone inventory window UI.
##
## The controller runs in PROCESS_MODE_ALWAYS so it still receives input while
## the world is paused.  It owns NO gameplay logic — it delegates to components
## and the SaveManager autoload.
## ============================================================================

signal book_opened(page_index: int)
signal book_closed()

enum BookState { CLOSED, OPENING, OPEN, TURNING, CLOSING }

const PAGE_STATS: int = 0
const PAGE_SETTINGS: int = 1
const PAGE_CREDITS: int = 2

@export var dimmer_fade_duration: float = 0.3
@export var dimmer_alpha: float = 0.45

@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot
@onready var corner_prev: TextureButton = %CornerPrev
@onready var corner_next: TextureButton = %CornerNext
@onready var nav_prev: Button = %NavPrev
@onready var nav_next: Button = %NavNext
# The AnimationPlayer that owns the book_open / book_close / page-turn anims.
@onready var animation_player: AnimationPlayer = %AnimationPlayer

# Pages are discovered at runtime (duck-typed via on_page_opened/on_page_closed).
# _pages[i] is the Control for page index i (the node that carries the
# *PageComponent script).  It may be a direct child of BookRoot OR a single
# child of a "container" Control that provides clip/positioning — in that case
# we also toggle the container's visibility alongside the page.
# Page order = order of discovery among children that implement BookPage.
var _pages: Array[Control] = []

var _state: int = BookState.CLOSED
var _current_page: int = PAGE_SETTINGS
var _target_page: int = PAGE_SETTINGS
var _pending_page: int = PAGE_SETTINGS
# Components found at runtime (untyped — duck-typed via has_method/has_signal).
var _pause: Node = null
var _animation: Node = null
var _turn: Node = null
var _active_tween: Tween = null

func _ready() -> void:
	# Process always so the menu still receives input while the world is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Gather sibling components by script path (robust to class_name ordering).
	_pause = _find_component_by_script("res://components/book/pause_component.gd")
	_animation = _find_component_by_script("res://components/book/book_animation_component.gd")
	_turn = _find_component_by_script("res://components/book/page_turn_component.gd")

	# Wire the animation component's AnimationPlayer export if it has none.
	if _animation and _animation.get("animation_player") == null:
		_animation.set("animation_player", animation_player)

	# Wire component signals.
	if _animation:
		_animation.book_opened.connect(_on_book_opened)
		_animation.book_closed.connect(_on_book_closed)
	if _turn:
		_turn.turn_midpoint.connect(_on_turn_midpoint)
		_turn.turn_completed.connect(_on_turn_completed)

	# Wire nav buttons.
	corner_prev.pressed.connect(_on_corner_prev)
	corner_next.pressed.connect(_on_corner_next)
	nav_prev.pressed.connect(_on_corner_prev)
	nav_next.pressed.connect(_on_corner_next)

	# Discover pages (Home, Settings, Inventory) under BookRoot and wire signals.
	_discover_pages()
	_wire_page_signals()

	# Start hidden.
	hide()
	book_root.hide()
	dimmer.color.a = 0.0
	for page: Control in _pages:
		page.hide()
	_hide_nav()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_on_pause_input()
	# Inventory is a separate window now (not part of the pause book).

func is_open() -> bool:
	return _state != BookState.CLOSED

# ============================================================================
# PAGE DISCOVERY
# ============================================================================
func _discover_pages() -> void:
	_pages.clear()
	for child: Node in book_root.get_children():
		# A page may be a direct child of BookRoot (has on_page_opened itself)…
		if child is Control and child.has_method("on_page_opened"):
			_pages.append(child as Control)
			continue
		# …or a single script-bearing child of a plain "container" Control.
		if child is Control:
			for grandchild: Node in child.get_children():
				if grandchild is Control and grandchild.has_method("on_page_opened"):
					_pages.append(grandchild as Control)
					break

func _wire_page_signals() -> void:
	for page: Control in _pages:
		if page.has_signal("resume_requested"):
			page.resume_requested.connect(close_book)
		if page.has_signal("save_requested"):
			page.save_requested.connect(_on_save_requested)
		if page.has_signal("exit_requested"):
			page.exit_requested.connect(_on_exit_requested)
func _show_page(page_index: int, show_it: bool) -> void:
	if page_index < 0 or page_index >= _pages.size():
		return
	var page: Control = _pages[page_index]
	if not is_instance_valid(page):
		return
	# Toggle the page and, if it lives inside a container, the container too.
	page.visible = show_it
	var container: Node = page.get_parent()
	if container is Control and container != book_root:
		container.visible = show_it
	if show_it and page.has_method("on_page_opened"):
		page.on_page_opened()
	elif not show_it and page.has_method("on_page_closed"):
		page.on_page_closed()

# ============================================================================
# INPUT
# ============================================================================
func _on_pause_input() -> void:
	# If another overlay is open, close it first so pause behaves consistently.
	_close_other_overlays()
	match _state:
		BookState.CLOSED:
			open_book(PAGE_SETTINGS)
		BookState.OPEN:
			close_book()
		BookState.OPENING:
			# If pause is pressed during opening, close as soon as opening completes.
			_target_page = _current_page
			_pending_page = _current_page
			_state = BookState.OPEN
			close_book()
		BookState.TURNING:
			# Ignore while page is actively turning.
			pass
		BookState.CLOSING:
			# Already closing; ignore repeated input.
			pass


# ============================================================================
# OPEN / CLOSE
# ============================================================================
func open_book(target_page: int) -> void:
	if _state != BookState.CLOSED:
		return
	if _pages.is_empty():
		return
	_target_page = clampi(target_page, 0, _pages.size() - 1)
	# Always animate from the Settings page, then auto-turn to requested page.
	_current_page = PAGE_SETTINGS
	_state = BookState.OPENING
	show()
	if _pause:
		_pause.pause_world()

	# Show the book, reveal the Home page, hide every other page, hide nav.
	book_root.show()
	for i in range(_pages.size()):
		_show_page(i, i == PAGE_SETTINGS)
	_hide_nav()

	# Fade in the dimmer overlay.
	_tween_dimmer(dimmer_alpha)

	# Play the cover-open animation (falls back to instant if none).
	if _animation:
		_animation.play_open()
	else:
		_on_book_opened()

func close_book() -> void:
	if _state != BookState.OPEN:
		return
	_state = BookState.CLOSING
	_hide_nav()
	for i in range(_pages.size()):
		_show_page(i, false)
	_tween_dimmer(0.0)
	# Resume the world and hide the book instantly.
	if _pause:
		_pause.resume_world()
	_on_book_closed()

func _on_book_opened() -> void:
	# After opening, show the Home page, then auto-turn if a different page was
	# requested (e.g. the Inventory key opens straight to the inventory page).
	_state = BookState.OPEN
	_current_page = PAGE_SETTINGS
	_show_page(PAGE_SETTINGS, true)
	_show_nav()
	book_opened.emit(_current_page)
	if _target_page != PAGE_SETTINGS:
		turn_to_page(_target_page)

func _on_book_closed() -> void:
	book_root.hide()
	hide()
	dimmer.color.a = 0.0
	_state = BookState.CLOSED
	if _pause:
		_pause.resume_world()
	book_closed.emit()

func _close_other_overlays() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var inventory_ui: CanvasLayer = tree.root.get_node_or_null("InventoryUI") as CanvasLayer
	if inventory_ui != null and inventory_ui.visible and inventory_ui.has_method(&"close_ui"):
		inventory_ui.call("close_ui")
	var chest_ui: CanvasLayer = tree.root.get_node_or_null("ChestUI") as CanvasLayer
	if chest_ui != null and chest_ui.visible and chest_ui.has_method(&"close_ui"):
		chest_ui.call("close_ui")

# ============================================================================
# PAGE TURNING
# ============================================================================
func turn_to_page(target: int) -> void:
	if _state != BookState.OPEN:
		return
	if target == _current_page:
		return
	if target < 0 or target >= _pages.size():
		return
	var direction: int = 1 if target > _current_page else -1
	_state = BookState.TURNING
	_hide_nav()
	_pending_page = target
	if _turn:
		if direction > 0:
			_turn.turn_forward()
		else:
			_turn.turn_backward()
	else:
		# No turn animation — swap immediately.
		_show_page(_current_page, false)
		_current_page = target
		_show_page(target, true)
		_state = BookState.OPEN
		_show_nav()

func _on_turn_midpoint() -> void:
	# Best moment (page edge-on) to swap content invisibly.
	_show_page(_current_page, false)
	_current_page = _pending_page
	_show_page(_pending_page, true)

func _on_turn_completed(_direction: int) -> void:
	if _state != BookState.TURNING:
		return
	_state = BookState.OPEN
	_show_nav()

# ============================================================================
# NAV BUTTONS
# ============================================================================
func _on_corner_prev() -> void:
	turn_to_page(_current_page - 1)

func _on_corner_next() -> void:
	turn_to_page(_current_page + 1)

func _show_nav() -> void:
	nav_prev.show()
	nav_next.show()
	corner_prev.show()
	corner_next.show()
	# Prev disabled on the first page; Next disabled on the last page.
	nav_prev.disabled = _current_page <= 0
	nav_next.disabled = _current_page >= _pages.size() - 1

func _hide_nav() -> void:
	nav_prev.hide()
	nav_next.hide()
	corner_prev.hide()
	corner_next.hide()

# ============================================================================
# HOME PAGE ACTIONS
# ============================================================================
func _on_save_requested() -> void:
	# Delegate to the save_manager autoload — the controller owns no save logic.
	# The autoload singleton is named "save_manager" in project.godot.
	var save_manager_node: Node = get_node_or_null("/root/save_manager")
	if save_manager_node != null and save_manager_node.has_method("save_game"):
		save_manager_node.call("save_game")
		print("[BookUI] Game saved from the Home page.")

func _on_exit_requested() -> void:
	# Quit the application.  (Swap for a confirmation dialog if desired later.)
	get_tree().quit()

# ============================================================================
# HELPERS
# ============================================================================
func _tween_dimmer(target_alpha: float) -> void:
	if _active_tween and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(dimmer, "color:a", target_alpha, dimmer_fade_duration)

func _find_component_by_script(script_path: String) -> Node:
	var target_script: Script = load(script_path) as Script
	if target_script == null:
		return null
	for child: Node in get_children():
		if child.get_script() == target_script:
			return child
		# Also check grandchildren (components may be nested under BookRoot).
		for grandchild: Node in child.get_children():
			if grandchild.get_script() == target_script:
				return grandchild
	return null
