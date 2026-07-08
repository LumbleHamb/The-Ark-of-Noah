class_name DamageNumber
extends Node2D

## A floating damage number that rises and fades out.
## Spawned by AttackComponent when damage is dealt.

@export var rise_distance: float = 32.0
@export var rise_duration: float = 0.6
@export var fade_duration: float = 0.4

var _label: Label = null
var _amount: int = 0

static func spawn(amount: int, world_position: Vector2, parent: Node) -> void:
	"""Create a floating damage number at the given world position."""
	var dn := DamageNumber.new()
	dn._amount = amount
	dn.global_position = world_position + Vector2(0, -8)  # slight upward offset
	parent.add_child(dn)

func _ready() -> void:
	# Hover above world, unaffected by camera — we use CanvasLayer on a different approach
	# Actually, simplest: just spawn as a Node2D child of the world.
	_label = Label.new()
	_label.text = str(_amount)
	_label.modulate = Color(1.0, 0.85, 0.2, 1.0)  # gold
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(_label)

	# Rise up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", Vector2(0, -rise_distance), rise_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_label, "modulate:a", 0.0, fade_duration).set_delay(rise_duration - fade_duration)
	tween.chain()
	tween.tween_callback(queue_free)
