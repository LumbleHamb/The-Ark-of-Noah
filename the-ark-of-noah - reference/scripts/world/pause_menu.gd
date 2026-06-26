extends CanvasLayer

# =============================================================================
# BOOK-STYLE PAUSE / INVENTORY MENU — STATE MACHINE ARCHITECTURE
# =============================================================================
# The state machine acts as a strict gatekeeper: every input (keyboard, button
# clicks, corner folds) is validated against the current state before any action
# is taken. This prevents overlapping animations and visual glitches.
#
# States:
#   CLOSED       — Book hidden, game running normally
#   OPENING      — Book-opening animation playing, dimmer fading in
#   INVENTORY    — Book open, inventory page spread active
#   SETTINGS     — Book open, settings page spread active
#   PAGE_TURNING — Page-turn animation playing between spreads
#   CLOSING      — Book-closing animation playing, dimmer fading out
#
# Transition map:
#   CLOSED       → open_book()         → OPENING
#   OPENING      → anim finished        → SETTINGS (default first spread)
#   SETTINGS     → turn_page(next)      → PAGE_TURNING → INVENTORY
#                → close_book()         → CLOSING
#                → toggle_inventory()   → PAGE_TURNING → INVENTORY
#   INVENTORY    → turn_page(prev)      → PAGE_TURNING → SETTINGS
#                → close_book()         → CLOSING
#                → toggle_inventory()   → CLOSING
#   PAGE_TURNING → anim finished        → INVENTORY or SETTINGS
#                → [ALL OTHER INPUTS IGNORED]
#   CLOSING      → anim finished        → CLOSED
#                → [ALL OTHER INPUTS IGNORED]
# =============================================================================

signal book_opened(spread_index: int)
signal book_closed()
signal state_changed(from_state: int, to_state: int)

enum BookState {
	CLOSED,       # 0 — Book not visible
	OPENING,      # 1 — Book opening animation in progress
	INVENTORY,    # 2 — Book open, inventory spread visible
	SETTINGS,     # 3 — Book open, settings spread visible
	CLOSING,      # 4 — Book closing animation in progress
	PAGE_TURNING, # 5 — Page turn animation in progress
}

const SPREAD_SETTINGS: int = 0
const SPREAD_INVENTORY: int = 1
const SPREAD_EXIT: int = 2

## How long the gold glow effect lasts on corner buttons (seconds).
const CORNER_GLOW_DURATION: float = 0.2

@export var page_spreads: Array = []
@export var dimmer_fade_duration: float = 0.3
@export var dimmer_alpha: float = 0.45
@export var default_spread: int = SPREAD_SETTINGS

@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot
@onready var book_sprite: AnimatedSprite2D = %BookSprite
@onready var book_interior: TextureRect = %BookInterior
@onready var page_turn: AnimatedSprite2D = %PageTurn
@onready var content_layer: Control = %ContentLayer
@onready var left_content: Control = %LeftContent
@onready var right_content: Control = %RightContent
@onready var corner_prev: TextureButton = %CornerPrev
@onready var corner_next: TextureButton = %CornerNext
@onready var nav_prev: Button = %NavPrev
@onready var nav_next: Button = %NavNext

## Current state machine state.
var _state: int = BookState.CLOSED
## Which spread (page pair) is currently active.
var _current_spread: int = 0
## Stores the target spread after a page turn completes.
var _pending_spread: int = -1
## Reference to the player node for pausing input.
var _player: Node = null
## Array of [left_scene, right_scene] pairs.
var _page_sources: Array = []
## Track active tweens so we can clean them up.
var _active_tweens: Array[Tween] = []
## Whether the game world is currently paused.
var _is_world_paused: bool = false


func _ready() -> void:
	_ensure_input_actions()
	_find_player()
	_setup_page_spreads()
	_navigation_visibility()

	# Start hidden
	hide()
	dimmer.color.a = 0.0
	book_root.hide()

	# Connect animation callbacks
	book_sprite.animation_finished.connect(_on_book_sprite_finished)
	page_turn.animation_finished.connect(_on_page_turn_finished)

	# Connect navigation buttons
	nav_prev.pressed.connect(_on_nav_prev_pressed)
	nav_next.pressed.connect(_on_nav_next_pressed)
	corner_prev.pressed.connect(_on_corner_prev_pressed)
	corner_next.pressed.connect(_on_corner_next_pressed)

	# Connect corner button mouse signals for glow feedback
	corner_prev.mouse_entered.connect(_on_corner_mouse_entered.bind(corner_prev))
	corner_next.mouse_entered.connect(_on_corner_mouse_entered.bind(corner_next))


func _ensure_input_actions() -> void:
	"""Ensure required input actions exist at runtime."""
	if not InputMap.has_action("pause"):
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_ESCAPE
		InputMap.add_action("pause")
		InputMap.action_add_event("pause", event)
	if not InputMap.has_action("inventory"):
		var event: InputEventKey = InputEventKey.new()
		event.keycode = KEY_Q
		InputMap.add_action("inventory")
		InputMap.action_add_event("inventory", event)


func _process(_delta: float) -> void:
	"""Check for keyboard input to toggle pause/inventory.
	The state machine gatekeeps — these calls are safe even in the wrong state."""
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	if Input.is_action_just_pressed("inventory"):
		toggle_inventory()


# =============================================================================
# PUBLIC API — GATEKEEPER FUNCTIONS
# =============================================================================

func toggle_pause() -> void:
	"""Toggle the book open/closed. Gatekeeps against invalid states."""
	match _state:
		BookState.CLOSED:
			open_book(SPREAD_SETTINGS)
		BookState.SETTINGS, BookState.INVENTORY:
			close_book()
		_:
			# PAGE_TURNING, OPENING, CLOSING — ignore input
			pass


func toggle_inventory() -> void:
	"""Toggle or navigate to the inventory spread. Gatekeeps against invalid states."""
	match _state:
		BookState.CLOSED:
			open_book(SPREAD_INVENTORY)
		BookState.INVENTORY:
			# Already on inventory — close the book
			close_book()
		BookState.SETTINGS:
			# On settings — turn page to inventory
			_turn_page(1)
		_:
			# PAGE_TURNING, OPENING, CLOSING — ignore input
			pass


func open_book(target_spread: int = -1) -> void:
	"""Open the book and transition to OPENING.
	Only valid from CLOSED state."""
	if _state != BookState.CLOSED:
		return

	if target_spread < 0:
		target_spread = default_spread
	target_spread = clampi(target_spread, 0, _page_sources.size() - 1)

	_state = BookState.OPENING
	_current_spread = target_spread
	_pending_spread = -1

	_kill_tweens()
	_pause_world(true)

	# Reset visuals
	book_root.modulate.a = 1.0
	book_root.scale = Vector2.ONE
	book_root.show()
	book_interior.hide()
	content_layer.hide()
	page_turn.hide()
	corner_prev.hide()
	corner_next.hide()
	nav_prev.hide()
	nav_next.hide()

	# Play opening animation
	book_sprite.show()
	book_sprite.modulate.a = 1.0
	book_sprite.scale = Vector2(2.125, 2.125)
	book_sprite.play("book_opening")

	# Fade in dimmer
	var t_dim: Tween = create_tween()
	t_dim.tween_property(dimmer, "color:a", dimmer_alpha, dimmer_fade_duration)
	_active_tweens.append(t_dim)

	show()
	state_changed.emit(BookState.CLOSED, BookState.OPENING)


func close_book() -> void:
	"""Close the book and transition to CLOSING.
	Only valid from SETTINGS or INVENTORY states."""
	if _state not in [BookState.SETTINGS, BookState.INVENTORY]:
		return

	var from_state: int = _state
	_state = BookState.CLOSING
	_pending_spread = -1

	_kill_tweens()

	# Hide interior UI
	nav_prev.hide()
	nav_next.hide()
	corner_prev.hide()
	corner_next.hide()
	_clear_content(left_content)
	_clear_content(right_content)
	left_content.hide()
	right_content.hide()
	content_layer.hide()
	book_interior.hide()

	# Play closing animation
	book_sprite.show()
	book_sprite.modulate.a = 1.0
	book_sprite.scale = Vector2(2.125, 2.125)
	book_sprite.play("book_closing")

	# Fade out dimmer
	var t_dim: Tween = create_tween()
	t_dim.tween_property(dimmer, "color:a", 0.0, dimmer_fade_duration)
	_active_tweens.append(t_dim)

	state_changed.emit(from_state, BookState.CLOSING)


func turn_page(direction: int) -> void:
	"""Turn to the next or previous page spread.
	Only valid from SETTINGS or INVENTORY states.
	direction: +1 = next page, -1 = previous page."""
	if _state not in [BookState.SETTINGS, BookState.INVENTORY]:
		return
	var target: int = _current_spread + direction
	if target < 0 or target >= _page_sources.size():
		return
	_turn_page(direction)


func is_in_state(state: int) -> bool:
	return _state == state


func get_current_spread() -> int:
	return _current_spread


func _turn_page(direction: int) -> void:
	"""Internal: execute the page turn animation.
	Called only after gatekeeper validation."""
	var from_state: int = _state
	var target: int = _current_spread + direction

	_state = BookState.PAGE_TURNING
	_pending_spread = target

	# Clear current content
	_clear_content(left_content)
	_clear_content(right_content)
	left_content.hide()
	right_content.hide()
	corner_prev.hide()
	corner_next.hide()
	nav_prev.hide()
	nav_next.hide()

	# Play page turn animation overlay
	page_turn.show()
	page_turn.scale = Vector2(2.0, 2.0)
	if direction > 0:
		page_turn.scale.x = 2.0
		page_turn.play("next_page")
	else:
		page_turn.scale.x = -2.0
		page_turn.play("previous_page")

	state_changed.emit(from_state, BookState.PAGE_TURNING)


# =============================================================================
# ANIMATION CALLBACKS
# =============================================================================

func _on_book_sprite_finished() -> void:
	"""Called when the book opening or closing animation finishes."""
	match _state:
		BookState.OPENING:
			book_sprite.stop()
			book_sprite.hide()
			book_interior.show()
			_show_current_content()
			# After opening, go to the appropriate content state
			_state = _content_state_for_spread(_current_spread)
			book_opened.emit(_current_spread)
			state_changed.emit(BookState.OPENING, _state)

		BookState.CLOSING:
			book_sprite.stop()
			book_sprite.hide()
			book_root.hide()
			hide()
			dimmer.color.a = 0.0
			_state = BookState.CLOSED
			_pause_world(false)
			book_closed.emit()
			state_changed.emit(BookState.CLOSING, BookState.CLOSED)

		_:  # Safety net — reset to closed if we end up in a bad state
			push_warning("Book animation finished in unexpected state: ", _state)
			_state = BookState.CLOSED
			book_root.hide()
			hide()
			dimmer.color.a = 0.0
			_pause_world(false)
			book_closed.emit()


func _on_page_turn_finished() -> void:
	"""Called when the page turn animation finishes.
	Transition to the appropriate content state."""
	if _state != BookState.PAGE_TURNING:
		return

	page_turn.hide()

	# Apply the pending spread
	if _pending_spread >= 0:
		_current_spread = _pending_spread
	_pending_spread = -1

	_state = _content_state_for_spread(_current_spread)
	_show_current_content()
	state_changed.emit(BookState.PAGE_TURNING, _state)


# =============================================================================
# INPUT HANDLERS — GATEKEPT
# =============================================================================

func _on_nav_prev_pressed() -> void:
	"""Bottom navigation 'Prev' button."""
	turn_page(-1)


func _on_nav_next_pressed() -> void:
	"""Bottom navigation 'Next' button."""
	turn_page(1)


func _on_corner_prev_pressed() -> void:
	"""Left page corner fold button pressed.
	Only triggers from valid states (gatekept by turn_page)."""
	_trigger_corner_glow(corner_prev)
	turn_page(-1)


func _on_corner_next_pressed() -> void:
	"""Right page corner fold button pressed.
	Only triggers from valid states (gatekept by turn_page)."""
	_trigger_corner_glow(corner_next)
	turn_page(1)


func _on_corner_mouse_entered(button: TextureButton) -> void:
	"""Subtle hover preview — a tiny glow pulse on hover."""
	# Small hover effect: brief 0.1s glow at 30% intensity
	var mat: Material = button.material
	if mat and mat is ShaderMaterial:
		var tween: Tween = create_tween()
		tween.tween_method(_set_glow.bind(button), 0.3, 0.0, 0.15)
		_active_tweens.append(tween)


# =============================================================================
# CORNER GLOW FEEDBACK
# =============================================================================

func _trigger_corner_glow(button: TextureButton) -> void:
	"""Flash a gold glow on the given button for CORNER_GLOW_DURATION seconds."""
	var mat: Material = button.material
	if mat and mat is ShaderMaterial:
		var tween: Tween = create_tween()
		tween.tween_method(_set_glow.bind(button), 1.0, 0.0, CORNER_GLOW_DURATION)
		_active_tweens.append(tween)


func _set_glow(value: float, button: TextureButton) -> void:
	"""Tween callback: set the glow_intensity shader parameter on the button."""
	var mat: Material = button.material
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("glow_intensity", value)


func _content_state_for_spread(spread_index: int) -> int:
	"""Map a spread index to the appropriate BookState."""
	match spread_index:
		SPREAD_INVENTORY:
			return BookState.INVENTORY
		SPREAD_SETTINGS, SPREAD_EXIT:
			return BookState.SETTINGS
		_:
			return BookState.SETTINGS


func _show_book_interior() -> void:
	"""Show the book interior and navigation after opening completes."""
	content_layer.show()
	_show_current_content()
	_navigation_visibility()
	corner_prev.show()
	corner_next.show()


func _show_current_content() -> void:
	"""Instantiate and display page content for the current spread."""
	if _current_spread < 0 or _current_spread >= _page_sources.size():
		return

	var spread: Array = _page_sources[_current_spread]
	var left_scene: PackedScene = spread[0] as PackedScene
	var right_scene: PackedScene = spread[1] as PackedScene

	_clear_content(left_content)
	_clear_content(right_content)

	if left_scene:
		var left_instance: Node = left_scene.instantiate()
		left_content.add_child(left_instance)
		if left_instance is Control:
			var ctrl: Control = left_instance
			ctrl.anchor_left = 0.0
			ctrl.anchor_top = 0.0
			ctrl.anchor_right = 1.0
			ctrl.anchor_bottom = 1.0
			ctrl.offset_left = 0.0
			ctrl.offset_top = 0.0
			ctrl.offset_right = 0.0
			ctrl.offset_bottom = 0.0
		if left_instance.has_method(&"on_page_opened"):
			left_instance.on_page_opened()
		_connect_page_signals(left_instance)

	if right_scene:
		var right_instance: Node = right_scene.instantiate()
		right_content.add_child(right_instance)
		if right_instance is Control:
			var ctrl: Control = right_instance
			ctrl.anchor_left = 0.0
			ctrl.anchor_top = 0.0
			ctrl.anchor_right = 1.0
			ctrl.anchor_bottom = 1.0
			ctrl.offset_left = 0.0
			ctrl.offset_top = 0.0
			ctrl.offset_right = 0.0
			ctrl.offset_bottom = 0.0
		if right_instance.has_method(&"on_page_opened"):
			right_instance.on_page_opened()
		_connect_page_signals(right_instance)

	left_content.show()
	right_content.show()
	_navigation_visibility()


func _connect_page_signals(page: Node) -> void:
	"""Connect signals from page instances to the pause menu."""
	if page.has_signal(&"resume_requested"):
		page.resume_requested.connect(close_book)
	if page.has_signal(&"exit_confirmed"):
		page.exit_confirmed.connect(_on_exit_confirmed)
	if page.has_signal(&"cancel_requested"):
		page.cancel_requested.connect(_on_cancel_requested)


func _clear_content(container: Control) -> void:
	"""Remove all page instances from a content container."""
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		if child.has_method(&"on_page_closed"):
			child.on_page_closed()
		child.queue_free()


func _navigation_visibility() -> void:
	"""Update navigation button visibility based on current spread."""
	if _page_sources.is_empty():
		nav_prev.hide()
		nav_next.hide()
		corner_prev.hide()
		corner_next.hide()
		return
	nav_prev.disabled = _current_spread <= 0
	nav_next.disabled = _current_spread >= _page_sources.size() - 1
	if _state in [BookState.SETTINGS, BookState.INVENTORY]:
		nav_prev.show()
		nav_next.show()
		corner_prev.show()
		corner_next.show()
	else:
		nav_prev.hide()
		nav_next.hide()
		corner_prev.hide()
		corner_next.hide()


# =============================================================================
# SETUP
# =============================================================================

func _setup_page_spreads() -> void:
	"""Load page spread definitions from exports or use defaults."""
	_page_sources = []
	for entry in page_spreads:
		if entry is Array and entry.size() >= 2:
			_page_sources.append(entry)

	if _page_sources.is_empty():
		_page_sources = [
			[load("res://scenes/world/pages/resume_page.tscn"), load("res://scenes/world/pages/settings_page.tscn")],
			[load("res://scenes/world/pages/inventory_page.tscn"), load("res://scenes/world/pages/stats_page.tscn")],
			[load("res://scenes/world/pages/exit_page.tscn"), null],
		]


func _find_player() -> void:
	"""Find the player node in the scene tree."""
	_player = get_tree().get_first_node_in_group(&"player")
	if _player == null:
		var root: Node = get_tree().root
		_player = root.find_child("player", true, false)
		if _player == null:
			_player = root.find_child("Player", true, false)


# =============================================================================
# PAUSE LOGIC — Time.timeScale INTEGRATION
# =============================================================================

func _pause_world(paused: bool) -> void:
	"""Pause or unpause the game world.
	- Sets get_tree().paused to true/false (freezes world nodes but not
	  PROCESS_MODE_ALWAYS nodes like the book UI).
	- Also tells the player to disable input processing."""
	_is_world_paused = paused

	if paused:
		get_tree().paused = true
	else:
		get_tree().paused = false

	if _player and _player.has_method(&"set_player_paused"):
		_player.set_player_paused(paused)


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_exit_confirmed() -> void:
	"""Exit the game. Called from the exit confirmation page."""
	get_tree().quit()


func _on_cancel_requested() -> void:
	"""Close the book when cancel is clicked on the exit page."""
	close_book()


# =============================================================================
# UTILITY
# =============================================================================

func _kill_tweens() -> void:
	"""Stop all active tweens."""
	for t in _active_tweens:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	_active_tweens.clear()
