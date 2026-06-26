extends CanvasLayer

## ============================================================================
## BOOK UI CONTROLLER — Orchestrates the rebuilt book pause menu.
##
## Wires together the reusable components:
##   - PauseComponent        (pauses/resumes the world)
##   - BookAnimationComponent (cover open/close)
##   - PageTurnComponent     (page-flip animation)
##   - SettingsPageComponent (first visible page)
##   - BookInventoryComponent (inventory page, reuses InventoryComponent)
##
## State machine (gatekeeps all input):
##   CLOSED → OPENING → OPEN(settings) → (page turn) → OPEN(inventory) → CLOSING → CLOSED
##
## Input:
##   - "pause"     toggles the book open/close (opens to Settings by default).
##   - "inventory" from CLOSED opens directly to the Inventory page (auto-turns
##     past Settings); from OPEN it closes the book.
##
## The controller does NOT own gameplay logic — it delegates to components.
## ============================================================================

signal book_opened(page_index: int)
signal book_closed()

enum BookState { CLOSED, OPENING, SETTINGS, INVENTORY, TURNING, CLOSING }

const PAGE_SETTINGS: int = 0
const PAGE_INVENTORY: int = 1

@export var dimmer_fade_duration: float = 0.3
@export var dimmer_alpha: float = 0.45

@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot
@onready var corner_prev: TextureButton = %CornerPrev
@onready var corner_next: TextureButton = %CornerNext
@onready var nav_prev: Button = %NavPrev
@onready var nav_next: Button = %NavNext
# Pages are untyped to avoid parse-time class_name ordering issues; we
# duck-type via has_method("on_page_opened").
@onready var settings_page: Control = %SettingsPage
@onready var inventory_page: Control = %InventoryPage
# Page containers (the clip_contents parents) resolved via unique names.
@onready var settings_container: Control = %SettingsPageContainer
@onready var inventory_container: Control = %InventoryPageContainer

var _state: int = BookState.CLOSED
var _current_page: int = PAGE_SETTINGS
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

	# Start hidden.
	hide()
	book_root.hide()
	dimmer.color.a = 0.0
	_show_page(PAGE_SETTINGS, false)

	# Hide nav initially.
	_hide_nav()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_on_pause_input()
	if Input.is_action_just_pressed("inventory"):
		_on_inventory_input()

# ============================================================================
# INPUT
# ============================================================================
func _on_pause_input() -> void:
	match _state:
		BookState.CLOSED:
			open_book(PAGE_SETTINGS)
		BookState.SETTINGS, BookState.INVENTORY:
			close_book()
		_:
			pass  # Ignore during OPENING/CLOSING/TURNING.

func _on_inventory_input() -> void:
	match _state:
		BookState.CLOSED:
			# Open directly to the inventory page (auto-turns past settings).
			open_book(PAGE_INVENTORY)
		BookState.INVENTORY:
			close_book()
		BookState.SETTINGS:
			turn_to_page(PAGE_INVENTORY)
		_:
			pass

# ============================================================================
# OPEN / CLOSE
# ============================================================================
func open_book(target_page: int) -> void:
	if _state != BookState.CLOSED:
		return
	_target_page = target_page
	_current_page = PAGE_SETTINGS  # always start at settings, then maybe turn
	_state = BookState.OPENING
	if _pause:
		_pause.pause_world()

	# Reset visuals.
	book_root.show()
	_show_page(PAGE_SETTINGS, true)
	_hide_nav()
	corner_prev.hide()
	corner_next.hide()
	nav_prev.hide()
	nav_next.hide()

	# Fade in dimmer.
	_tween_dimmer(dimmer_alpha)

	# Play the opening animation (cover lifts, pages fan).
	if _animation:
		_animation.play_open()
	else:
		_on_book_opened()  # Fallback if no animation component.

func close_book() -> void:
	if _state not in [BookState.SETTINGS, BookState.INVENTORY]:
		return
	_state = BookState.CLOSING
	_hide_nav()
	corner_prev.hide()
	corner_next.hide()
	nav_prev.hide()
	nav_next.hide()
	# Hide page content so the closing animation shows just the book.
	_show_page(PAGE_SETTINGS, false)
	_show_page(PAGE_INVENTORY, false)
	_tween_dimmer(0.0)
	if _animation:
		_animation.play_close()
	else:
		_on_book_closed()

var _target_page: int = PAGE_SETTINGS

func _on_book_opened() -> void:
	# After opening, show the settings page, then auto-turn if requested.
	_state = BookState.SETTINGS
	_show_page(PAGE_SETTINGS, true)
	_show_nav()
	book_opened.emit(_current_page)
	if _target_page == PAGE_INVENTORY:
		# Auto-turn to the inventory page.
		turn_to_page(PAGE_INVENTORY)

func _on_book_closed() -> void:
	book_root.hide()
	hide()
	dimmer.color.a = 0.0
	_state = BookState.CLOSED
	if _pause:
		_pause.resume_world()
	book_closed.emit()

# ============================================================================
# PAGE TURNING
# ============================================================================
func turn_to_page(target: int) -> void:
	if _state not in [BookState.SETTINGS, BookState.INVENTORY]:
		return
	if target == _current_page:
		return
	if target < PAGE_SETTINGS or target > PAGE_INVENTORY:
		return
	var direction: int = 1 if target > _current_page else -1
	_state = BookState.TURNING
	_hide_nav()
	corner_prev.hide()
	corner_next.hide()
	nav_prev.hide()
	nav_next.hide()
	_pending_page = target
	_pending_direction = direction
	if _turn:
		if direction > 0:
			_turn.turn_forward()
		else:
			_turn.turn_backward()
	else:
		# No turn animation — swap immediately.
		_current_page = target
		_state = _open_state_for_page(target)
		_show_page(target, true)
		_show_nav()

var _pending_page: int = PAGE_SETTINGS
var _pending_direction: int = 1

func _on_turn_midpoint() -> void:
	# Best moment (page edge-on) to swap content invisibly.
	_show_page(_current_page, false)
	_current_page = _pending_page
	_show_page(_pending_page, true)

func _on_turn_completed(_direction: int) -> void:
	if _state != BookState.TURNING:
		return
	_state = _open_state_for_page(_current_page)
	_show_nav()

func _open_state_for_page(page: int) -> int:
	if page == PAGE_INVENTORY:
		return BookState.INVENTORY
	return BookState.SETTINGS

# ============================================================================
# PAGE VISIBILITY
# ============================================================================
func _show_page(page: int, show_it: bool) -> void:
	var container: Control = null
	if page == PAGE_SETTINGS:
		container = settings_container
	elif page == PAGE_INVENTORY:
		container = inventory_container
	if container and is_instance_valid(container):
		container.visible = show_it
	if page == PAGE_INVENTORY and inventory_page:
		if show_it:
			inventory_page.on_page_opened()
		else:
			inventory_page.on_page_closed()

# ============================================================================
# NAV BUTTONS
# ============================================================================
func _on_corner_prev() -> void:
	turn_to_page(PAGE_SETTINGS)

func _on_corner_next() -> void:
	turn_to_page(PAGE_INVENTORY)

func _show_nav() -> void:
	nav_prev.show()
	nav_next.show()
	corner_prev.show()
	corner_next.show()
	# Prev disabled on settings; Next disabled on inventory.
	nav_prev.disabled = _current_page <= PAGE_SETTINGS
	nav_next.disabled = _current_page >= PAGE_INVENTORY

func _hide_nav() -> void:
	nav_prev.hide()
	nav_next.hide()
	corner_prev.hide()
	corner_next.hide()

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
