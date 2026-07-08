class_name PlayerAnimationComponent
extends Component

signal attack_animation_finished(combo_step: int)

@export_category("References")
@export var anim_sprite: AnimatedSprite2D = null

@export_category("Sprite Offsets")
@export var base_offset: Vector2 = Vector2(-64, -86)
@export var attack_offset: Vector2 = Vector2(-64, -86)
@export var dash_offset: Vector2 = Vector2(-64, -86)
@export var block_offset: Vector2 = Vector2(-64, -86)

var movement: MovementComponent = null
var current_direction: String = "S"
var is_attacking: bool = false
var is_dead: bool = false
var _walktorun_pending: bool = false
var _runtowalk_pending: bool = false

func _component_ready() -> void:
	if anim_sprite == null:
		anim_sprite = get_entity().get_node_or_null("player_animation") as AnimatedSprite2D
	movement = get_sibling_component(MovementComponent) as MovementComponent
	if anim_sprite != null:
		_ensure_player_action_direction_variants()
		anim_sprite.offset = base_offset
		if not anim_sprite.animation_finished.is_connected(_on_any_animation_finished):
			anim_sprite.animation_finished.connect(_on_any_animation_finished)
	if movement != null:
		movement.direction_changed.connect(_on_direction_changed)
		movement.movement_state_changed.connect(_on_movement_state_changed)


func _ensure_player_action_direction_variants() -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	var sf: SpriteFrames = anim_sprite.sprite_frames
	var prefixes: Array[String] = ["stab", "stab1", "stab2", "bowfire", "bowloadedidle", "bowreload"]
	var dirs: Array[String] = ["W", "N", "S", "NE", "NW", "SE", "SW"]
	for prefix: String in prefixes:
		var source_anim: StringName = StringName(prefix + "_E")
		if not sf.has_animation(source_anim):
			continue
		for dir_key: String in dirs:
			var target_anim: StringName = StringName(prefix + "_" + dir_key)
			if sf.has_animation(target_anim):
				continue
			sf.add_animation(target_anim)
			sf.set_animation_speed(target_anim, sf.get_animation_speed(source_anim))
			sf.set_animation_loop(target_anim, sf.get_animation_loop(source_anim))
			var frame_count: int = sf.get_frame_count(source_anim)
			for i: int in range(frame_count):
				sf.add_frame(target_anim, sf.get_frame_texture(source_anim, i), sf.get_frame_duration(source_anim, i), -1)

func setup(sprite: AnimatedSprite2D) -> void:
	anim_sprite = sprite
	if anim_sprite != null:
		anim_sprite.offset = base_offset

func _on_movement_state_changed(state: MovementComponent.MoveState) -> void:
	if is_attacking or is_dead:
		return
	match state:
		MovementComponent.MoveState.IDLE:
			play_idle(current_direction)
		MovementComponent.MoveState.WALK:
			play_walk(current_direction)
		MovementComponent.MoveState.RUN:
			play_run(current_direction)
		MovementComponent.MoveState.SPRINT:
			play_sprint(current_direction)
		MovementComponent.MoveState.DASH:
			if movement != null and movement.is_backdash:
				play_backdash(current_direction)
			else:
				play_dash(current_direction)
		MovementComponent.MoveState.ROLL:
			play_roll(current_direction)

func _on_direction_changed(direction: Vector2) -> void:
	current_direction = get_dir_from_vector(direction)
	if not is_attacking and not is_dead:
		_update_current_animation()

func _update_current_animation() -> void:
	if movement == null:
		return
	_on_movement_state_changed(movement.move_state)

func play_attack(dir_key: String) -> void:
	_play_action("attack_" + dir_key, true)

func play_attack2(dir_key: String) -> void:
	_play_action("attack2_" + dir_key, true)

func play_attack3(dir_key: String) -> void:
	_play_action("attack3_" + dir_key, true)

func play_stab(dir_key: String) -> void:
	_play_action("stab_" + dir_key, true)

func play_stab1(dir_key: String) -> void:
	_play_action("stab1_" + dir_key, true)

func play_stab2(dir_key: String) -> void:
	_play_action("stab2_" + dir_key, true)

func play_bow_reload(dir_key: String) -> void:
	_play_action("bowreload_" + dir_key, false)

func play_bow_loaded_idle(dir_key: String) -> void:
	_play_action("bowloadedidle_" + dir_key, false)

func play_bow_fire(dir_key: String) -> void:
	_play_action("bowfire_" + dir_key, false)

func cancel_attack() -> void:
	is_attacking = false
	if anim_sprite != null:
		anim_sprite.offset = base_offset

func _on_any_animation_finished() -> void:
	if anim_sprite == null:
		return
	var anim_name: String = anim_sprite.animation
	if anim_name.begins_with("attack") or anim_name.begins_with("stab"):
		is_attacking = false
		anim_sprite.offset = base_offset
		attack_animation_finished.emit(_combo_step_from_name(anim_name))
		return
	if anim_name.begins_with("walktorun"):
		anim_sprite.speed_scale = 1.0
		if _runtowalk_pending:
			_runtowalk_pending = false
			_update_current_animation()
			return
		_walktorun_pending = false
		_update_current_animation()
		return
	anim_sprite.offset = base_offset

func _combo_step_from_name(anim_name: String) -> int:
	if anim_name.begins_with("attack2") or anim_name.begins_with("stab1"):
		return 2
	if anim_name.begins_with("attack3") or anim_name.begins_with("stab2"):
		return 3
	return 1

func play_walktorun(dir_key: String) -> void:
	_play_if_changed("walktorun_" + dir_key)

func play_runtowalk(dir_key: String) -> void:
	if anim_sprite == null:
		return
	var anim_name: String = "walktorun_" + dir_key
	if not _has_animation(anim_name):
		anim_name = "walktorun_E"
	var frame_count: int = anim_sprite.sprite_frames.get_frame_count(anim_name) - 1
	anim_sprite.frame = frame_count
	anim_sprite.speed_scale = -1.0
	anim_sprite.play(anim_name)

func play_dash(dir_key: String) -> void:
	if anim_sprite != null:
		anim_sprite.offset = dash_offset
	_play_if_changed("dash_" + _fallback_dir(dir_key))

func play_roll(dir_key: String) -> void:
	if anim_sprite != null:
		anim_sprite.offset = dash_offset
	_play_if_changed("roll_" + _fallback_dir(dir_key))

func play_backdash(dir_key: String) -> void:
	if anim_sprite != null:
		anim_sprite.offset = dash_offset
	_play_if_changed("backdash_" + _fallback_dir(dir_key))

func play_block(dir_key: String) -> void:
	if anim_sprite != null:
		anim_sprite.offset = block_offset
	_play_if_changed("block_" + dir_key)

func _play_if_changed(animation_name: String) -> void:
	if anim_sprite == null:
		return
	if not _has_animation(animation_name):
		return
	if anim_sprite.animation != animation_name:
		anim_sprite.speed_scale = 1.0
		anim_sprite.play(animation_name)

func _play_action(animation_name: String, marks_attack: bool) -> void:
	if anim_sprite == null:
		return
	if not _has_animation(animation_name):
		return
	if marks_attack:
		is_attacking = true
	var dir_key: String = animation_name.get_slice("_", 1)
	current_direction = dir_key
	anim_sprite.offset = attack_offset
	anim_sprite.stop()
	anim_sprite.frame = 0
	anim_sprite.speed_scale = 1.0
	anim_sprite.play(animation_name)

func _has_animation(anim_name: String) -> bool:
	return anim_sprite != null and anim_sprite.sprite_frames != null and anim_sprite.sprite_frames.has_animation(anim_name)

func _fallback_dir(dir_key: String) -> String:
	if _has_animation("dash_" + dir_key):
		return dir_key
	return "E" if dir_key in ["E", "SE", "NE"] else "W"

func stop_animation() -> void:
	if anim_sprite != null:
		anim_sprite.stop()

func is_playing() -> bool:
	return anim_sprite != null and anim_sprite.is_playing()

func get_dir_from_vector(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "S"
	var angle: float = rad_to_deg(atan2(v.y, v.x))
	if angle < 0.0:
		angle += 360.0
	if angle < 22.5 or angle >= 337.5:
		return "E"
	elif angle < 67.5:
		return "SE"
	elif angle < 112.5:
		return "S"
	elif angle < 157.5:
		return "SW"
	elif angle < 202.5:
		return "W"
	elif angle < 247.5:
		return "NW"
	elif angle < 292.5:
		return "N"
	return "NE"

func play_idle(dir_key: String) -> void:
	_walktorun_pending = false
	_runtowalk_pending = false
	if anim_sprite != null:
		anim_sprite.offset = base_offset
	_play_if_changed("idle_" + dir_key)

func play_walk(dir_key: String) -> void:
	if anim_sprite == null:
		return
	_walktorun_pending = false
	var cur: String = anim_sprite.animation
	if not _runtowalk_pending and cur.begins_with("run_"):
		_runtowalk_pending = true
		play_runtowalk(dir_key)
		return
	if _runtowalk_pending:
		return
	anim_sprite.offset = base_offset
	_play_if_changed("walk_" + dir_key)

func play_run(dir_key: String) -> void:
	if anim_sprite == null:
		return
	_runtowalk_pending = false
	var cur: String = anim_sprite.animation
	if not _walktorun_pending and cur.begins_with("walk_"):
		_walktorun_pending = true
		play_walktorun(dir_key)
		return
	if _walktorun_pending:
		return
	anim_sprite.offset = base_offset
	_play_if_changed("run_" + dir_key)

func play_sprint(dir_key: String) -> void:
	_walktorun_pending = false
	_runtowalk_pending = false
	if anim_sprite != null:
		anim_sprite.offset = base_offset
	_play_if_changed("sprint_" + dir_key)

func play_death(dir_key: String = "") -> void:
	if anim_sprite == null:
		return
	is_dead = true
	if dir_key != "":
		current_direction = dir_key
	if anim_sprite != null:
		anim_sprite.offset = base_offset
	_play_if_changed("death_" + current_direction)
