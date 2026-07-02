# ============================================================================
# VIRTUAL JOYSTICK
# ============================================================================
# A clean, modern on-screen joystick for mobile-style analog movement.
#
# Features
# --------
#  * Touch (mobile) + left-mouse (desktop emulation) input
#  * Single-pointer enforcement (extra touches / mouse buttons are ignored)
#  * Circular radius clamp
#  * Dead-zone (~0.15) with smooth response curve
#  * Smooth fade-in / fade-out visibility
#  * Knob spring-back to centre on release
#  * Direction + strength output (consumed by Player)
#  * Optional visual debug overlay (vector + values)
#  * Failsafe reset if input is lost (e.g. window focus dropped)
#
# Output
# ------
#  direction : Vector2  (unit vector, 0 when idle / inside dead-zone)
#  strength  : float    (0.0 .. 1.0; 0 when inside dead-zone)
#
# Integration
# -----------
#  The joystick is a CanvasLayer autoload; access it from any script as:
#      MobileJoystick.direction
#      MobileJoystick.strength
#  Or by autoload name "virtual_joystick".
# ============================================================================
class_name MobileJoystick
extends CanvasLayer

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal joystick_pressed
signal joystick_released
signal direction_changed(new_direction: Vector2)
signal strength_changed(new_strength: float)

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------
@export_group("Geometry")
## Max distance the knob can travel from the joystick's base centre.
@export_range(16.0, 256.0, 1.0) var radius: float = 80.0
## Visual size (diameter) of the rendered knob.
@export_range(8.0, 128.0, 1.0) var knob_size: float = 48.0
## Visual size (diameter) of the base ring.
@export_range(16.0, 256.0, 1.0) var base_size: float = 140.0

@export_group("Behaviour")
## Fraction of the radius where input is ignored (0.0 - 0.5).
@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.15
## Smoothing factor for the knob's visual position (0 = no smoothing, 1 = no movement).
@export_range(0.0, 0.95, 0.01) var knob_smoothing: float = 0.35
## How fast the knob springs back to centre on release (units per second).
@export_range(100.0, 2000.0, 10.0) var return_speed: float = 1200.0
## Seconds to fully fade in / out.
@export_range(0.0, 1.0, 0.01) var fade_duration: float = 0.18

@export_group("Debug")
## When true, draws a vector arrow + numeric readout on the joystick.
@export var debug_overlay: bool = false

@export_group("Colours")
@export var col_base_fill: Color = Color(0.10, 0.10, 0.18, 0.45)
@export var col_base_ring: Color = Color(0.60, 0.65, 0.85, 0.55)
@export var col_dead_zone: Color = Color(0.80, 0.85, 1.00, 0.18)
@export var col_knob_fill: Color = Color(0.94, 0.95, 1.00, 0.92)
@export var col_knob_outline: Color = Color(1.00, 1.00, 1.00, 0.75)
@export var col_knob_glow: Color = Color(0.50, 0.70, 1.00, 0.40)
@export var col_indicator: Color = Color(1.00, 1.00, 1.00, 0.55)
@export var col_debug: Color = Color(1.00, 1.00, 0.40, 0.95)
@export var col_shadow: Color = Color(0.00, 0.00, 0.00, 0.30)

# ---------------------------------------------------------------------------
# PUBLIC OUTPUT (consumed by Player)
# ---------------------------------------------------------------------------
var direction: Vector2 = Vector2.ZERO
var strength: float = 0.0

# ---------------------------------------------------------------------------
# INTERNAL STATE
# ---------------------------------------------------------------------------
var _active: bool = false
var _active_pointer_index: int = -1       # -1 = mouse
var _is_touch: bool = false

var _base_center: Vector2 = Vector2.ZERO  # Origin of the joystick
var _knob_pos: Vector2 = Vector2.ZERO     # Current visual knob position
var _knob_target: Vector2 = Vector2.ZERO  # Target knob position (clamped)

var _alpha: float = 0.0                   # 0 = hidden, 1 = fully visible
var _alpha_target: float = 0.0

var _area: Control = null

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_area = get_node_or_null("JoystickArea")
	if _area == null:
		_area = Control.new()
		_area.name = "JoystickArea"
		_area.anchors_preset = Control.PRESET_FULL_RECT
		_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_area)

	_area.draw.connect(_on_draw)
	_area.resized.connect(_on_area_resized)
	_on_area_resized()


func _process(delta: float) -> void:
	# --- Fade alpha ---
	if not is_equal_approx(_alpha, _alpha_target):
		var step: float = delta / maxf(fade_duration, 0.01)
		_alpha = move_toward(_alpha, _alpha_target, step)
		_area.queue_redraw()

	# --- Spring-back when not active ---
	if not _active:
		if _knob_target.length_squared() > 0.5:
			_knob_target = _knob_target.move_toward(Vector2.ZERO, return_speed * delta)
			_update_output()
			_area.queue_redraw()
		elif not _knob_target.is_zero_approx():
			_knob_target = Vector2.ZERO
			_update_output()
			_area.queue_redraw()

	# --- Smooth visual knob toward target ---
	if not _knob_pos.is_equal_approx(_knob_target):
		_knob_pos = _knob_pos.lerp(_knob_target, 1.0 - knob_smoothing)
		_area.queue_redraw()


func _exit_tree() -> void:
	_release_actions()


# ---------------------------------------------------------------------------
# INPUT HANDLING
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	# Ignore input when the game is paused — only the book UI should respond
	if get_tree() != null and get_tree().paused:
		return

	# --- Mobile touch ---
	if event is InputEventScreenTouch:
		_handle_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_drag(event)
		return

	# --- Desktop mouse emulation ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# First valid touch wins; ignore extras
		if _active:
			return
		_press(event.position, event.index, true)
	else:
		# Only release if this touch was the active one
		if _active and _is_touch and event.index == _active_pointer_index:
			_release()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if _active and _is_touch and event.index == _active_pointer_index:
		_drag(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		# First valid press wins; ignore additional mouse buttons
		if _active:
			return
		_press(event.position, -1, false)
	else:
		if _active and not _is_touch and _active_pointer_index == -1:
			_release()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _active and not _is_touch and _active_pointer_index == -1:
		_drag(event.position)


# ---------------------------------------------------------------------------
# JOYSTICK STATE
# ---------------------------------------------------------------------------
func _press(pos: Vector2, pointer_index: int, is_touch: bool) -> void:
	_active = true
	_active_pointer_index = pointer_index
	_is_touch = is_touch
	_base_center = pos
	_knob_pos = pos
	_knob_target = pos
	_alpha_target = 1.0
	_update_output()
	_area.queue_redraw()
	joystick_pressed.emit()


func _drag(pos: Vector2) -> void:
	var knob_offset: Vector2 = pos - _base_center
	var dist: float = knob_offset.length()
	if dist > radius:
		knob_offset = knob_offset / dist * radius
	_knob_target = _base_center + knob_offset
	_update_output()
	_area.queue_redraw()


func _release() -> void:
	if not _active:
		return
	_active = false
	_active_pointer_index = -1
	_is_touch = false
	_alpha_target = 0.0
	_release_actions()
	joystick_released.emit()
	_area.queue_redraw()


## Failsafe / debug: forcibly resets the joystick. Use if it gets stuck.
func reset() -> void:
	_release()
	_knob_pos = Vector2.ZERO
	_knob_target = Vector2.ZERO
	_alpha = 0.0
	_alpha_target = 0.0
	direction = Vector2.ZERO
	strength = 0.0
	if _area:
		_area.queue_redraw()


func is_active() -> bool:
	return _active


# ---------------------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------------------
func _update_output() -> void:
	# Offset of the knob from the base, in pixels
	var knob_offset_v: Vector2 = _knob_target - _base_center
	var raw_length: float = knob_offset_v.length()
	var raw_dir: Vector2 = Vector2.ZERO if raw_length < 0.0001 else knob_offset_v / raw_length
	var normalized: float = clampf(raw_length / radius, 0.0, 1.0)

	if normalized < dead_zone:
		if direction != Vector2.ZERO or strength != 0.0:
			direction = Vector2.ZERO
			strength = 0.0
			direction_changed.emit(direction)
			strength_changed.emit(strength)
		return

	# Re-scale so dead_zone -> 0, edge -> 1
	var scaled: float = (normalized - dead_zone) / (1.0 - dead_zone)
	scaled = clampf(scaled, 0.0, 1.0)

	# Smooth curve (squared for a more natural analog feel)
	var shaped: float = scaled * scaled * (3.0 - 2.0 * scaled)  # smoothstep

	if direction != raw_dir:
		direction = raw_dir
		direction_changed.emit(direction)
	if not is_equal_approx(strength, shaped):
		strength = shaped
		strength_changed.emit(strength)


# ---------------------------------------------------------------------------
# INPUT MAP INJECTION
# ---------------------------------------------------------------------------
# Optionally translate joystick output into the project's input actions
# (left/right/up/down/run). This keeps the player script input-agnostic.
# Toggle on/off with set_inject_actions().
# ---------------------------------------------------------------------------
const ACTION_LEFT: StringName = &"left"
const ACTION_RIGHT: StringName = &"right"
const ACTION_UP: StringName = &"up"
const ACTION_DOWN: StringName = &"down"
const ACTION_RUN: StringName = &"run"

var _inject_actions: bool = false

func set_inject_actions(enabled: bool) -> void:
	if enabled == _inject_actions:
		return
	_inject_actions = enabled
	if not enabled:
		_release_actions()


func _release_actions() -> void:
	if not _inject_actions:
		return
	Input.action_release(ACTION_LEFT)
	Input.action_release(ACTION_RIGHT)
	Input.action_release(ACTION_UP)
	Input.action_release(ACTION_DOWN)


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _is_touch_index_held(_index: int) -> bool:
	# Godot doesn't expose a direct query for touch state by index; the
	# release event will normally arrive, so this is just a coarse failsafe.
	return Input.is_action_pressed(&"ui_touch")


func _on_area_resized() -> void:
	if _area:
		_area.queue_redraw()


# ---------------------------------------------------------------------------
# RENDERING
# ---------------------------------------------------------------------------
func _on_draw() -> void:
	if _alpha <= 0.001 and not _active:
		return

	var a: float = _alpha
	var base_radius: float = base_size * 0.5
	var knob_radius: float = knob_size * 0.5

	# --- Drop shadow ---
	var sh: Color = Color(col_shadow.r, col_shadow.g, col_shadow.b, col_shadow.a * a)
	_area.draw_circle(_base_center + Vector2(0, 4), base_radius, sh)
	_area.draw_circle(_knob_pos + Vector2(0, 3), knob_radius, sh)

	# --- Base fill ---
	var bf: Color = Color(col_base_fill.r, col_base_fill.g, col_base_fill.b, col_base_fill.a * a)
	_area.draw_circle(_base_center, base_radius, bf)

	# --- Base ring ---
	var br: Color = Color(col_base_ring.r, col_base_ring.g, col_base_ring.b, col_base_ring.a * a)
	_area.draw_arc(_base_center, base_radius, 0.0, TAU, 64, br, 2.0)

	# --- Cross hairs (faint) ---
	var ch: Color = Color(1.0, 1.0, 1.0, 0.08 * a)
	_area.draw_line(
		_base_center + Vector2(-base_radius, 0),
		_base_center + Vector2(base_radius, 0),
		ch, 1.0
	)
	_area.draw_line(
		_base_center + Vector2(0, -base_radius),
		_base_center + Vector2(0, base_radius),
		ch, 1.0
	)

	# --- Dead-zone indicator (only when active) ---
	if _active:
		var dz_r: float = radius * dead_zone
		var dz: Color = Color(col_dead_zone.r, col_dead_zone.g, col_dead_zone.b, col_dead_zone.a * a)
		_area.draw_arc(_base_center, dz_r, 0.0, TAU, 48, dz, 1.5)

	# --- Direction indicator (subtle arrow from centre) ---
	if _active and strength > 0.01:
		var arrow_len: float = base_radius * 0.45
		var tip: Vector2 = _base_center + direction * arrow_len
		var tail: Vector2 = _base_center + direction * (arrow_len * 0.25)
		var perp: Vector2 = Vector2(-direction.y, direction.x).normalized() * 6.0
		var ic: Color = Color(col_indicator.r, col_indicator.g, col_indicator.b, col_indicator.a * a)
		var pts: PackedVector2Array = [tip, tail + perp, tail - perp]
		_area.draw_colored_polygon(pts, ic)

	# --- Knob glow ---
	var glow: Color = Color(col_knob_glow.r, col_knob_glow.g, col_knob_glow.b, col_knob_glow.a * a)
	_area.draw_circle(_knob_pos, knob_radius * 1.35, glow)

	# --- Knob fill ---
	var kf: Color = Color(col_knob_fill.r, col_knob_fill.g, col_knob_fill.b, col_knob_fill.a * a)
	_area.draw_circle(_knob_pos, knob_radius, kf)

	# --- Knob outline ---
	var ko: Color = Color(col_knob_outline.r, col_knob_outline.g, col_knob_outline.b, col_knob_outline.a * a)
	_area.draw_arc(_knob_pos, knob_radius, 0.0, TAU, 32, ko, 1.5)

	# --- Knob inner highlight ---
	var hi: Color = Color(1.0, 1.0, 1.0, 0.30 * a)
	_area.draw_circle(_knob_pos + Vector2(-knob_radius * 0.25, -knob_radius * 0.25), knob_radius * 0.35, hi)

	# --- Debug overlay ---
	if debug_overlay and _active:
		var dc: Color = Color(col_debug.r, col_debug.g, col_debug.b, col_debug.a * a)
		var label_pos: Vector2 = _base_center + Vector2(base_radius + 12, -base_radius - 4)
		var text: String = "dir:(%.2f, %.2f)\nstr:%.2f" % [direction.x, direction.y, strength]
		_area.draw_string(
			ThemeDB.fallback_font,
			label_pos,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			dc
		)
