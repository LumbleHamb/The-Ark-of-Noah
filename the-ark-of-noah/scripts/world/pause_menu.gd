class_name PauseMenu
extends CanvasLayer

## =============================================================================
## PAUSE MENU
## =============================================================================
## Book-style pause menu that fades in the world, plays a book-opening animation
## (Spellbook_Opening sprite sheet), then shows interactive pages with a spine
## and corner folds. Page navigation is animated with Spellbook_NextPage /
## Spellbook_PreviousPage sprite sheets.
##
## Pages are organised as "spreads" — each spread is [left_scene, right_scene],
## each a PackedScene that fills its respective side of the open book.
##
## The pause is "selective": only the player's input/movement is disabled; the
## world (lighting, time, crops) continues to tick.
## =============================================================================

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal book_opened()
signal book_closed()
signal page_changed(index: int)

# ---------------------------------------------------------------------------
# ENUMS
# ---------------------------------------------------------------------------
enum BookState { CLOSED, OPENING, OPEN, CLOSING }

# ---------------------------------------------------------------------------
# EXPORTS
# ---------------------------------------------------------------------------
## Optional: override the page spreads from the inspector. Each entry is
## [left_page_scene, right_page_scene]. If empty, sensible defaults are used.
@export var page_spreads: Array = []

## Duration of the dimmer fade-in / fade-out (seconds).
@export var dimmer_fade_duration: float = 0.25

## Final dimmer opacity (0..1).
@export var dimmer_alpha: float = 0.45

# ---------------------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------------------
@onready var dimmer: ColorRect = %Dimmer
@onready var book_root: Control = %BookRoot
@onready var book_sprite: AnimatedSprite2D = %BookSprite
@onready var page_turn: AnimatedSprite2D = %PageTurn
@onready var content_layer: Control = %ContentLayer
@onready var left_page_bg: ColorRect = %LeftPageBg
@onready var right_page_bg: ColorRect = %RightPageBg
@onready var book_spine: ColorRect = %BookSpine
@onready var left_content: Control = %LeftContent
@onready var right_content: Control = %RightContent
@onready var corner_prev: TextureButton = %CornerPrev
@onready var corner_next: TextureButton = %CornerNext
@onready var nav_prev: Button = %NavPrev
@onready var nav_next: Button = %NavNext

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _state: BookState = BookState.CLOSED
var _current_spread: int = 0
var _is_turning_page: bool = false
var _player: Node = null

# Default page spreads, used when page_spreads is not configured in the inspector
var _page_sources: Array = []

# Active Tweens (kept so we can kill them if state changes mid-animation)
var _active_tweens: Array[Tween] = []

# ===========================================================================
# LIFECYCLE
# ===========================================================================
func _ready() -> void:
	hide()
	dimmer.color.a = 0.0

	_find_player()
	_setup_page_spreads()
	_navigation_visibility()

	# Signal connections
	book_sprite.animation_finished.connect(_on_book_sprite_finished)
	page_turn.animation_finished.connect(_on_page_turn_finished)
	nav_prev.pressed.connect(_on_prev_page)
	nav_next.pressed.connect(_on_next_page)
	corner_prev.pressed.connect(_on_prev_page)
	corner_next.pressed.connect(_on_next_page)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()


# ===========================================================================
# PUBLIC API
# ===========================================================================
func toggle_pause() -> void:
	match _state:
		BookState.CLOSED:
			open_book()
		BookState.OPEN:
			close_book()
		_:
			# Mid-transition: ignore
			pass


func open_book() -> void:
	if _state != BookState.CLOSED:
		return
	_state = BookState.OPENING

	# Stop any in-flight tweens
	_kill_tweens()

	# Disable player input (world keeps running)
	_set_player_paused(true)

	# Reset visuals
	book_root.scale = Vector2(0.6, 0.6)
	book_root.modulate.a = 0.0
	book_root.show()
	book_sprite.show()
	book_sprite.modulate.a = 1.0
	book_sprite.scale = Vector2(2.0, 2.0)
	book_sprite.play("book_opening")
	page_turn.hide()
	content_layer.hide()
	nav_prev.hide()
	nav_next.hide()
	corner_prev.hide()
	corner_next.hide()
	left_page_bg.hide()
	right_page_bg.hide()
	book_spine.hide()
	left_content.hide()
	right_content.hide()
	show()

	# Fade in dimmer
	var t_dim: Tween = create_tween()
	t_dim.tween_property(dimmer, "color:a", dimmer_alpha, dimmer_fade_duration)
	_active_tweens.append(t_dim)

	# Pop-in scale of the whole book
	var t_scale: Tween = create_tween()
	t_scale.set_trans(Tween.TRANS_BACK)
	t_scale.set_ease(Tween.EASE_OUT)
	t_scale.tween_property(book_root, "scale", Vector2.ONE, 0.35)
	_active_tweens.append(t_scale)

	# Fade book_root in for a smoother first frame
	var t_fade: Tween = create_tween()
	t_fade.tween_property(book_root, "modulate:a", 1.0, 0.15)
	_active_tweens.append(t_fade)


func close_book() -> void:
	if _state != BookState.OPEN:
		return
	_state = BookState.CLOSING

	# Stop any in-flight tweens
	_kill_tweens()

	# Hide interactive UI immediately
	nav_prev.hide()
	nav_next.hide()
	corner_prev.hide()
	corner_next.hide()
	left_page_bg.hide()
	right_page_bg.hide()
	book_spine.hide()
	_clear_content(left_content)
	_clear_content(right_content)
	left_content.hide()
	right_content.hide()
	content_layer.hide()

	# Show the closing animation
	book_sprite.show()
	book_sprite.modulate.a = 1.0
	book_sprite.scale = Vector2(2.0, 2.0)
	book_sprite.play("book_closing")

	# Fade out dimmer
	var t_dim: Tween = create_tween()
	t_dim.tween_property(dimmer, "color:a", 0.0, dimmer_fade_duration)
	_active_tweens.append(t_dim)

	# Slight pop-out scale
	var t_scale: Tween = create_tween()
	t_scale.set_trans(Tween.TRANS_BACK)
	t_scale.set_ease(Tween.EASE_IN)
	t_scale.tween_property(book_root, "scale", Vector2(0.6, 0.6), 0.35)
	_active_tweens.append(t_scale)


func turn_page(direction: int) -> void:
	## Public API: direction 1 = forward, -1 = backward
	if _is_turning_page or _state != BookState.OPEN:
		return
	var target: int = _current_spread + direction
	if target < 0 or target >= _page_sources.size():
		return
	_turn_page(direction)


func set_page(index: int) -> void:
	## Jump directly to a specific spread index.
	if _is_turning_page or _state != BookState.OPEN:
		return
	if index < 0 or index >= _page_sources.size():
		return
	var direction: int = 1 if index > _current_spread else -1
	if direction == 0:
		return
	_current_spread = index
	_show_current_content()
	_navigation_visibility()
	page_changed.emit(_current_spread)


func is_open() -> bool:
	return _state == BookState.OPEN


# ===========================================================================
# ANIMATION CALLBACKS
# ===========================================================================
func _on_book_sprite_finished() -> void:
	match _state:
		BookState.OPENING:
			# Show the open book interior (page backgrounds, spine, content)
			book_sprite.stop()
			# Leave the sprite showing the last frame of book_opening as a backdrop
			_show_book_interior()
			_state = BookState.OPEN
			book_opened.emit()
		BookState.CLOSING:
			# Animation finished — fully hide everything and unpause
			book_sprite.stop()
			book_root.hide()
			book_root.scale = Vector2.ONE
			book_root.modulate.a = 1.0
			book_sprite.hide()
			hide()
			dimmer.color.a = 0.0
			_state = BookState.CLOSED
			_set_player_paused(false)
			book_closed.emit()


func _on_page_turn_finished() -> void:
	_is_turning_page = false
	page_turn.hide()
	_show_current_content()


# ===========================================================================
# PAGE NAVIGATION
# ===========================================================================
func _on_prev_page() -> void:
	if _is_turning_page or _state != BookState.OPEN:
		return
	if _current_spread <= 0:
		return
	_turn_page(-1)


func _on_next_page() -> void:
	if _is_turning_page or _state != BookState.OPEN:
		return
	if _current_spread >= _page_sources.size() - 1:
		return
	_turn_page(1)


func _turn_page(direction: int) -> void:
	_is_turning_page = true

	# Hide current content
	_clear_content(left_content)
	_clear_content(right_content)
	left_content.hide()
	right_content.hide()
	left_page_bg.hide()
	right_page_bg.hide()
	book_spine.hide()
	corner_prev.hide()
	corner_next.hide()
	nav_prev.hide()
	nav_next.hide()

	# Show page-turn overlay
	page_turn.show()
	page_turn.scale = Vector2(2.0, 2.0)
	page_turn.scale.x = -2.0 if direction < 0 else 2.0
	if direction > 0:
		page_turn.play("next_page")
	else:
		page_turn.play("previous_page")

	# Advance spread index now; the page-turn animation will hide the swap
	_current_spread += direction


# ===========================================================================
# BOOK INTERIOR
# ===========================================================================
func _show_book_interior() -> void:
	left_page_bg.show()
	right_page_bg.show()
	book_spine.show()
	content_layer.show()
	_show_current_content()
	nav_prev.show()
	nav_next.show()
	corner_prev.show()
	corner_next.show()
	_navigation_visibility()


func _show_current_content() -> void:
	if _current_spread < 0 or _current_spread >= _page_sources.size():
		return

	var spread: Array = _page_sources[_current_spread]
	var left_scene: PackedScene = spread[0] as PackedScene
	var right_scene: PackedScene = spread[1] as PackedScene

	# Clear any leftover content (defensive)
	_clear_content(left_content)
	_clear_content(right_content)

	# Left page
	if left_scene:
		var left_instance: Node = left_scene.instantiate()
		left_content.add_child(left_instance)
		# Make the page fill the left-content area
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
			ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if left_instance.has_method(&"on_page_opened"):
			left_instance.on_page_opened()
		_connect_page_signals(left_instance)

	# Right page
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
			ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if right_instance.has_method(&"on_page_opened"):
			right_instance.on_page_opened()
		_connect_page_signals(right_instance)

	left_content.show()
	right_content.show()

	_navigation_visibility()
	page_changed.emit(_current_spread)


func _connect_page_signals(page: Node) -> void:
	# Resume signal — both pages
	if page.has_signal(&"resume_requested"):
		page.resume_requested.connect(close_book)
	# Confirm exit
	if page.has_signal(&"exit_confirmed"):
		page.exit_confirmed.connect(_on_exit_confirmed)
	# Cancel exit — just clear the page (no-op for now; resume is also fine)
	if page.has_signal(&"cancel_requested"):
		page.cancel_requested.connect(_on_cancel_requested)


func _clear_content(container: Control) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		if child.has_method(&"on_page_closed"):
			child.on_page_closed()
		child.queue_free()


func _navigation_visibility() -> void:
	if _page_sources.is_empty():
		nav_prev.hide()
		nav_next.hide()
		corner_prev.hide()
		corner_next.hide()
		return
	nav_prev.disabled = _current_spread <= 0
	nav_next.disabled = _current_spread >= _page_sources.size() - 1
	# Only show nav buttons if the book is actually open
	if _state == BookState.OPEN:
		nav_prev.show()
		nav_next.show()
		corner_prev.show()
		corner_next.show()
	else:
		nav_prev.hide()
		nav_next.hide()
		corner_prev.hide()
		corner_next.hide()


# ===========================================================================
# EXIT / CANCEL HANDLERS
# ===========================================================================
func _on_exit_confirmed() -> void:
	get_tree().quit()


func _on_cancel_requested() -> void:
	# The cancel button on the exit page is meant to dismiss the exit prompt
	# without quitting. For now, simply close the book.
	close_book()


# ===========================================================================
# PAGE SETUP
# ===========================================================================
func _setup_page_spreads() -> void:
	# Build the page spread array from PackedScene resources
	_page_sources = []
	for entry in page_spreads:
		if entry is Array and entry.size() >= 2:
			_page_sources.append(entry)

	# Fallback: if not set via export, use defaults
	if _page_sources.is_empty():
		_page_sources = [
			[
				load("res://scenes/world/pages/resume_page.tscn"),
				load("res://scenes/world/pages/settings_page.tscn"),
			],
			[
				load("res://scenes/world/pages/inventory_page.tscn"),
				load("res://scenes/world/pages/stats_page.tscn"),
			],
			[
				load("res://scenes/world/pages/exit_page.tscn"),
				null,
			],
		]


# ===========================================================================
# PLAYER PAUSE CONTROL
# ===========================================================================
func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player")
	if _player == null:
		var root: Node = get_tree().root
		_player = root.find_child("player", true, false)
		if _player == null:
			_player = root.find_child("Player", true, false)


func _set_player_paused(paused: bool) -> void:
	if _player and _player.has_method(&"set_player_paused"):
		_player.set_player_paused(paused)


# ===========================================================================
# HELPERS
# ===========================================================================
func _kill_tweens() -> void:
	for t in _active_tweens:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	_active_tweens.clear()
