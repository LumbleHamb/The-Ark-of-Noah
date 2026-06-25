# ============================================================================
# ACTION BAR
# ============================================================================
# Touch / mouse-friendly button bar that fires input actions.
# (refreshed)
#
# Layout (scene tree)
# ------
#   CanvasLayer              (root; keeps UI on top of the game world)
#   └─ MarginContainer       (padding from screen edges; anchors = bottom-left)
#      └─ HBoxContainer      (side-by-side layout)
#         ├─ TextureButton   (HP orb → "attack")
#         └─ TextureButton   (MP orb → "interact")
#
# How it works
# ------------
# The buttons call Input.action_press() / Input.action_release(), so any
# script that already checks Input.is_action_just_pressed("attack") or
# Input.is_action_just_pressed("interact") will react exactly the same as
# if the player pressed Space / E on the keyboard.
#
# Godot's TextureButton automatically handles both mouse clicks and touch
# input — touch events are transparently translated into the GUI mouse-button
# system, so no extra code is needed.
# ============================================================================
class_name ResourceOrbBar
extends CanvasLayer


# ---------------------------------------------------------------------------
# NODE REFERENCES (matched to the scene tree by name)
# ---------------------------------------------------------------------------
@onready var hp_button: TextureButton = %HPButton   # → fires "attack"
@onready var mp_button: TextureButton = %MPButton   # → fires "interact"


# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
const ACTION_ATTACK: StringName = &"attack"
const ACTION_INTERACT: StringName = &"interact"


# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Connect pressed / released signals.
	# TextureButton works the same for both mouse-click and touch — Godot
	# translates touch events into the GUI mouse-button system automatically.
	hp_button.pressed.connect(_on_hp_pressed)
	hp_button.button_down.connect(_on_hp_button_down)
	hp_button.button_up.connect(_on_hp_button_up)

	mp_button.pressed.connect(_on_mp_pressed)
	mp_button.button_down.connect(_on_mp_button_down)
	mp_button.button_up.connect(_on_mp_button_up)


# ---------------------------------------------------------------------------
# HP BUTTON → "attack"
# ---------------------------------------------------------------------------
func _on_hp_pressed() -> void:
	Input.action_press(ACTION_ATTACK)


func _on_hp_button_down() -> void:
	Input.action_press(ACTION_ATTACK)


func _on_hp_button_up() -> void:
	Input.action_release(ACTION_ATTACK)


# ---------------------------------------------------------------------------
# MP BUTTON → "interact"
# ---------------------------------------------------------------------------
func _on_mp_pressed() -> void:
	Input.action_press(ACTION_INTERACT)


func _on_mp_button_down() -> void:
	Input.action_press(ACTION_INTERACT)


func _on_mp_button_up() -> void:
	Input.action_release(ACTION_INTERACT)
