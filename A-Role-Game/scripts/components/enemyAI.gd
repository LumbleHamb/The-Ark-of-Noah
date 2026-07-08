class_name EnemyAIComponent
extends Component


enum State {
	IDLE,
	PATROL,
	INVESTIGATE,
	SEARCH,
	COMBAT,
	ATTACK,
	SPECIAL_ATTACK,
	RETREAT,
	RECOVER,
	HURT,
	DEAD
}

@export_category("References")
@export var sprite: AnimatedSprite2D

@export_category("Movement")
@export var move_speed: float = 55.0
@export var combat_speed_multiplier: float = 1.05
@export var retreat_speed_multiplier: float = 1.25
@export var detection_range: float = 240.0
@export var hearing_range: float = 190.0
@export var personal_space: float = 30.0
@export var push_away_strength: float = 70.0
@export var orbit_radius: float = 52.0
@export var desired_ring_radius: float = 62.0
@export var flanking_bias: float = 0.5
@export var separation_radius: float = 46.0
@export var separation_strength: float = 140.0
@export var teammate_block_avoidance_strength: float = 75.0
@export var repath_interval: float = 0.25
@export var chase_idle_interval: float = 3.0
@export var chase_idle_duration: float = 1.0

@export_category("Line of Sight")
@export var los_enabled: bool = true
@export var los_collision_mask: int = 1
@export var max_breadcrumb_steps: int = 6
@export var breadcrumb_search_range: float = 0.0

@export_category("Combat")
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 1.0
@export var melee_windup_time: float = 0.12
@export var melee_recover_time: float = 0.22
@export var low_health_retreat_threshold: float = 0.22
@export var recover_duration: float = 1.2
@export var decision_interval: float = 0.12

@export_category("Special Attack")
@export var special_attack_enabled: bool = false
@export var special_attack_chance: float = 0.3
@export var special_prep_animation: String = ""
@export var special_spin_animation: String = ""
@export var special_end_animation: String = ""
@export var special_charge_speed: float = 140.0
@export var special_prep_duration: float = 0.6
@export var special_spin_duration: float = 0.8
@export var special_end_duration: float = 0.35
@export var hitbox_spin_path: NodePath = NodePath("")
@export var spin_attack_damage: int = 2

@export_category("Projectile")
@export var projectile_scene: PackedScene = preload("res://scenes/characters/projectile/projectile.tscn")
@export var use_projectile_attack: bool = false
@export var projectile_attack_animation: String = ""
@export var projectile_spawn_offset: Vector2 = Vector2(36, 0)
@export var projectile_damage: int = 1
@export var projectile_speed: float = 170.0
@export var projectile_lifetime: float = 2.0
@export var ranged_attack_range: float = 190.0
@export var ranged_attack_min_range: float = 54.0
@export var ranged_attack_cooldown: float = 2.0
@export var melee_attack_cooldown: float = 1.0
@export var ranged_windup_time: float = 0.35
@export var ranged_recover_time: float = 0.30
@export var projectile_explode_animation: String = ""
@export var projectile_splash_radius: float = 0.0
@export var projectile_splash_damage: int = 0
@export var one_projectile_at_a_time: bool = false

# Legacy exported fields kept for scene compatibility
@export var projectile_fx_animation: String = ""
@export var projectile_custom_prep: String = ""
@export var projectile_hitbox_size: Vector2 = Vector2(64, 64)

@export_category("Animations")
@export var idle_animation: String = "orc 1 idle"
@export var walk_animation: String = "orc 1 walk"
@export var attack_animation: String = "orc 1 attack"
@export var hurt_animation: String = "orc 1 hurt"
@export var death_animation: String = "orc 1 death"

@export_category("Debug")
@export var debug_draw_los: bool = false

var entity: CharacterBody2D
var attack_component: AttackComponent
var health_component: HealthComponent
var player: Node2D
var nav_agent: NavigationAgent2D
var hitbox_spin: Area2D

var state: State = State.IDLE
var attack_timer: float = 0.0
var decision_timer: float = 0.0
var hurt_timer: float = 0.0
var recover_timer: float = 0.0
var repath_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _personality: Vector2 = Vector2.ZERO

var _last_known_player_pos: Vector2 = Vector2.ZERO
var _search_center: Vector2 = Vector2.ZERO
var _search_timer: float = 0.0
var _search_duration: float = 2.4
var _los_lost_time: float = 0.0

var _breadcrumb_target_index: int = -1
var _breadcrumb_steps_taken: int = 0
var _breadcrumb_update_timer: float = 0.0
const BREADCRUMB_UPDATE_INTERVAL: float = 0.25

var _spin_hit_targets: Array[Node] = []
var _special_phase: String = ""
var _special_timer: float = 0.0

var _pending_attack_damage: int = -1
var _attack_windup_timer: float = 0.0
var _attack_recover_timer: float = 0.0
var _active_projectile: Projectile = null
var _facing_x_sign: int = 1

var _debug_los_line: Line2D
var _debug_drawer: AIEnemyDebugDrawer


func _component_ready() -> void:
	entity = get_entity() as CharacterBody2D
	if entity == null:
		return

	entity.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if not entity.is_in_group(&"enemy"):
		entity.add_to_group(&"enemy")

	if sprite == null:
		sprite = _find_sprite()
	if sprite != null:
		sprite.centered = true

	attack_component = get_sibling_component(AttackComponent) as AttackComponent
	health_component = get_sibling_component(HealthComponent) as HealthComponent

	if health_component != null:
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)

	if attack_component != null:
		attack_component.attack_started.connect(_on_attack_started)
		attack_component.attack_finished.connect(_on_attack_finished)

	if not hitbox_spin_path.is_empty():
		var spin_node: Node = get_node_or_null(hitbox_spin_path)
		if spin_node is Area2D:
			hitbox_spin = spin_node as Area2D
			hitbox_spin.monitoring = false
			hitbox_spin.body_entered.connect(_on_spin_hitbox_entered)

	nav_agent = entity.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if nav_agent == null:
		nav_agent = NavigationAgent2D.new()
		nav_agent.name = &"NavigationAgent2D"
		nav_agent.path_desired_distance = 8.0
		nav_agent.target_desired_distance = 10.0
		nav_agent.avoidance_enabled = true
		nav_agent.radius = maxf(10.0, personal_space * 0.5)
		nav_agent.max_speed = move_speed * retreat_speed_multiplier
		entity.add_child.call_deferred(nav_agent)

	_rng.seed = hash(entity.name) + entity.get_instance_id()
	_personality = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	decision_timer = _rng.randf_range(0.01, decision_interval)
	repath_timer = _rng.randf_range(0.0, repath_interval)

	if debug_draw_los:
		_debug_los_line = Line2D.new()
		_debug_los_line.name = "DebugLOSLine"
		_debug_los_line.width = 2.0
		_debug_los_line.default_color = Color.GREEN
		entity.add_child.call_deferred(_debug_los_line)

	if OS.has_feature("release") == false:
		_debug_drawer = AIEnemyDebugDrawer.new()
		_debug_drawer.name = "AIDebugDrawer"
		_debug_drawer.ai = self
		entity.add_child.call_deferred(_debug_drawer)

	play_animation(idle_animation)


func _physics_process(delta: float) -> void:
	if not active or entity == null:
		return

	if state == State.DEAD:
		entity.velocity = Vector2.ZERO
		entity.move_and_slide()
		return

	if attack_timer > 0.0:
		attack_timer -= delta
	decision_timer -= delta
	repath_timer -= delta

	if player == null or not is_instance_valid(player):
		find_player()

	if decision_timer <= 0.0:
		decision_timer = decision_interval + _rng.randf_range(0.0, 0.05)
		_update_decision()

	match state:
		State.IDLE:
			_process_idle()
		State.INVESTIGATE:
			_process_investigate(delta)
		State.SEARCH:
			_process_search(delta)
		State.COMBAT:
			_process_combat(delta)
		State.ATTACK:
			_process_attack(delta)
		State.SPECIAL_ATTACK:
			_process_special_attack(delta)
		State.RETREAT:
			_process_retreat(delta)
		State.RECOVER:
			_process_recover(delta)
		State.HURT:
			_process_hurt(delta)
		_:
			_process_idle()

	entity.move_and_slide()


func _update_decision() -> void:
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		if state != State.DEAD:
			state = State.IDLE
			entity.velocity = Vector2.ZERO
		return

	var player_dist: float = entity.global_position.distance_to(player.global_position)
	var sees_player: bool = _can_see_player()
	var hears_player: bool = player_dist <= hearing_range

	if sees_player:
		_last_known_player_pos = player.global_position
		_los_lost_time = 0.0
	else:
		_los_lost_time += decision_interval

	if _is_low_health() and state != State.RETREAT and state != State.RECOVER and state != State.SPECIAL_ATTACK:
		state = State.RETREAT
		return

	if sees_player or hears_player:
		if state == State.IDLE or state == State.SEARCH or state == State.INVESTIGATE:
			state = State.COMBAT
		return

	if state == State.COMBAT and _los_lost_time > 0.2:
		_search_center = _last_known_player_pos
		state = State.INVESTIGATE
		return

	if state == State.INVESTIGATE and _los_lost_time > 1.6:
		state = State.SEARCH
		_search_timer = _search_duration
		return

	if state == State.SEARCH and _search_timer <= 0.0:
		state = State.IDLE


func _process_idle() -> void:
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, 180.0 * entity.get_physics_process_delta_time())
	play_animation(idle_animation)


func _process_investigate(_delta: float) -> void:
	if _last_known_player_pos == Vector2.ZERO:
		state = State.SEARCH
		return
	_move_to_target(_last_known_player_pos, move_speed)


func _process_search(delta: float) -> void:
	_search_timer -= delta
	var probe: Vector2 = _search_center + Vector2(_rng.randf_range(-64.0, 64.0), _rng.randf_range(-64.0, 64.0))
	if _try_breadcrumb_chase():
		return
	_move_to_target(probe, move_speed * 0.72)


func _process_combat(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		state = State.IDLE
		entity.velocity = Vector2.ZERO
		play_animation(idle_animation)
		return

	var to_player: Vector2 = player.global_position - entity.global_position
	var distance: float = to_player.length()
	if distance <= 0.001:
		return

	var facing_dir: Vector2 = to_player.normalized()
	var ally_avoid: Vector2 = _compute_separation_force()
	var ring_target: Vector2 = _compute_ring_target(player.global_position)

	if distance <= attack_range + 8.0:
		entity.velocity = (-facing_dir * push_away_strength) + ally_avoid
		update_facing(facing_dir)
		play_animation(idle_animation)
		_try_attack(false)
		return

	var can_ranged: bool = (
		(use_projectile_attack or not projectile_fx_animation.is_empty())
		and distance >= ranged_attack_min_range
		and distance <= ranged_attack_range
		and _has_clear_shot()
	)
	if can_ranged:
		if one_projectile_at_a_time and _active_projectile != null and is_instance_valid(_active_projectile):
			var strafe: Vector2 = Vector2(-facing_dir.y, facing_dir.x)
			entity.velocity = strafe * (move_speed * 0.55) + ally_avoid
			update_facing(entity.velocity)
			play_animation(walk_animation)
			return
		entity.velocity = ally_avoid
		update_facing(facing_dir)
		play_animation(idle_animation)
		_try_attack(true)
		return

	var desired_move: Vector2 = (ring_target - entity.global_position).normalized()
	var movement_bias: float = clampf(flanking_bias + _personality.x * 0.2, 0.15, 0.9)
	var orbit_dir: Vector2 = Vector2(-facing_dir.y, facing_dir.x) * movement_bias
	var blended: Vector2 = (desired_move * 0.7 + orbit_dir * 0.3).normalized()
	var speed: float = move_speed * combat_speed_multiplier
	entity.velocity = blended * speed + ally_avoid
	update_facing(entity.velocity)
	play_animation(walk_animation)


func _process_attack(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		state = State.IDLE
		_pending_attack_damage = -1
		entity.velocity = Vector2.ZERO
		play_animation(idle_animation)
		return
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, 220.0 * delta)

	if _attack_windup_timer > 0.0:
		_attack_windup_timer -= delta
		if _attack_windup_timer <= 0.0:
			if _pending_attack_damage >= 0:
				_fire_projectile()
				_pending_attack_damage = -1
			elif attack_component != null:
				var direction: String = get_attack_direction()
				attack_component.start_attack(direction)
		return

	if _pending_attack_damage < 0 and attack_component != null and attack_component.is_attacking_now():
		return

	if _attack_recover_timer > 0.0:
		_attack_recover_timer -= delta
		return

	state = State.COMBAT


func _process_special_attack(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		state = State.IDLE
		entity.velocity = Vector2.ZERO
		if hitbox_spin != null:
			hitbox_spin.monitoring = false
		return

	_special_timer -= delta
	match _special_phase:
		"prep":
			entity.velocity = Vector2.ZERO
			if _special_timer <= 0.0:
				_special_phase = "spin"
				_special_timer = special_spin_duration
				if use_projectile_attack:
					_fire_projectile()
				elif hitbox_spin != null:
					hitbox_spin.monitoring = true
					if sprite != null and not special_spin_animation.is_empty():
						sprite.play(special_spin_animation)
		"spin":
			if use_projectile_attack:
				entity.velocity = Vector2.ZERO
			else:
				var spin_dir: Vector2 = (player.global_position - entity.global_position).normalized()
				entity.velocity = spin_dir * special_charge_speed
				update_facing(spin_dir)
			if _special_timer <= 0.0:
				_special_phase = "end"
				_special_timer = special_end_duration
				if hitbox_spin != null:
					hitbox_spin.monitoring = false
				if sprite != null and not special_end_animation.is_empty():
					sprite.play(special_end_animation)
		"end":
			entity.velocity = entity.velocity.move_toward(Vector2.ZERO, special_charge_speed * delta * 2.2)
			if _special_timer <= 0.0:
				attack_timer = attack_cooldown
				state = State.COMBAT


func _process_retreat(_delta: float) -> void:
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		state = State.IDLE
		entity.velocity = Vector2.ZERO
		play_animation(idle_animation)
		return
	var away: Vector2 = (entity.global_position - player.global_position).normalized()
	entity.velocity = away * move_speed * retreat_speed_multiplier + _compute_separation_force()
	update_facing(-away)
	play_animation(walk_animation)
	if entity.global_position.distance_to(player.global_position) > detection_range * 0.9:
		recover_timer = recover_duration
		state = State.RECOVER


func _process_recover(delta: float) -> void:
	recover_timer -= delta
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, 170.0 * delta)
	play_animation(idle_animation)
	if recover_timer <= 0.0:
		state = State.IDLE


func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, 220.0 * delta)
	if hurt_timer <= 0.0:
		state = State.COMBAT if _is_player_alive() else State.IDLE


func _try_attack(ranged: bool) -> void:
	if attack_timer > 0.0 or state == State.SPECIAL_ATTACK or state == State.ATTACK:
		return
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		return
	if ranged and one_projectile_at_a_time and _active_projectile != null and is_instance_valid(_active_projectile):
		return

	if special_attack_enabled and _rng.randf() < special_attack_chance:
		_start_special_attack()
		return

	state = State.ATTACK
	if ranged:
		_attack_windup_timer = ranged_windup_time
		_attack_recover_timer = ranged_recover_time
		_pending_attack_damage = projectile_damage
		if sprite != null:
			if not projectile_custom_prep.is_empty() and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(projectile_custom_prep):
				sprite.play(projectile_custom_prep)
			elif not projectile_attack_animation.is_empty() and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(projectile_attack_animation):
				sprite.play(projectile_attack_animation)
			else:
				play_animation(attack_animation)
		attack_timer = ranged_attack_cooldown
	else:
		_attack_windup_timer = melee_windup_time
		_attack_recover_timer = melee_recover_time
		_pending_attack_damage = -1
		play_animation(attack_animation)
		attack_timer = melee_attack_cooldown


func _start_special_attack() -> void:
	state = State.SPECIAL_ATTACK
	_special_phase = "prep"
	_special_timer = special_prep_duration
	_spin_hit_targets.clear()
	if hitbox_spin != null:
		hitbox_spin.monitoring = false
	if sprite != null and not special_prep_animation.is_empty():
		sprite.play(special_prep_animation)


func _fire_projectile() -> void:
	if projectile_scene == null:
		return
	if player == null or not is_instance_valid(player) or not _is_player_alive():
		return
	if one_projectile_at_a_time and _active_projectile != null and is_instance_valid(_active_projectile):
		return
	var projectile_node: Node = projectile_scene.instantiate()
	if projectile_node == null:
		return
	var dir: Vector2 = (player.global_position - entity.global_position).normalized()
	entity.get_parent().add_child(projectile_node)
	(projectile_node as Node2D).global_position = entity.global_position + projectile_spawn_offset.rotated(dir.angle())
	if projectile_node is Projectile:
		var projectile: Projectile = projectile_node as Projectile
		projectile.damage = projectile_damage
		projectile.speed = projectile_speed
		projectile.lifetime = projectile_lifetime
		projectile.splash_radius = projectile_splash_radius
		projectile.splash_damage = projectile_splash_damage
		projectile.explode_animation = projectile_explode_animation
		if sprite != null and sprite.sprite_frames != null:
			if not projectile_fx_animation.is_empty() and sprite.sprite_frames.has_animation(projectile_fx_animation):
				projectile.set_flight_animation(sprite.sprite_frames, projectile_fx_animation)
			if not projectile_explode_animation.is_empty() and sprite.sprite_frames.has_animation(projectile_explode_animation):
				projectile.set_explode_frames(sprite.sprite_frames)
		projectile.init(dir, entity)
		_active_projectile = projectile
		projectile.tree_exited.connect(_on_active_projectile_tree_exited)


func _compute_ring_target(center: Vector2) -> Vector2:
	var id_seed: float = float(entity.get_instance_id() % 997)
	var base_angle: float = (id_seed / 997.0) * TAU
	var jitter: float = _personality.x * 0.65
	var player_vel: Vector2 = player.velocity if player is CharacterBody2D else Vector2.ZERO
	var lead: Vector2 = player_vel * 0.18
	var radius: float = desired_ring_radius + (_personality.y * orbit_radius * 0.25)
	return center + Vector2.RIGHT.rotated(base_angle + jitter) * radius + lead


func _compute_separation_force() -> Vector2:
	var neighbors: Array[Node] = get_tree().get_nodes_in_group(&"enemy")
	var force: Vector2 = Vector2.ZERO
	var count: int = 0
	for node: Node in neighbors:
		if node == entity or not (node is CharacterBody2D):
			continue
		var other: CharacterBody2D = node as CharacterBody2D
		var delta: Vector2 = entity.global_position - other.global_position
		var d2: float = delta.length_squared()
		if d2 <= 0.0001:
			continue
		if d2 < separation_radius * separation_radius:
			force += delta.normalized() * (separation_strength / maxf(8.0, sqrt(d2)))
			count += 1
	if count > 0:
		force /= float(count)
	return force


func _move_to_target(target: Vector2, speed: float) -> void:
	var dir: Vector2 = (target - entity.global_position).normalized()
	if nav_agent != null and is_instance_valid(nav_agent):
		if repath_timer <= 0.0:
			nav_agent.target_position = target
			repath_timer = repath_interval + _rng.randf_range(0.0, 0.1)
		if not nav_agent.is_navigation_finished():
			var next_pos: Vector2 = nav_agent.get_next_path_position()
			dir = (next_pos - entity.global_position).normalized()
	entity.velocity = dir * speed + _compute_separation_force()
	update_facing(dir)
	play_animation(walk_animation)


func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not los_enabled:
		return entity.global_position.distance_to(player.global_position) <= detection_range
	if entity.global_position.distance_to(player.global_position) > detection_range:
		return false
	return has_los_to(player.global_position)


func _has_clear_shot() -> bool:
	if player == null:
		return false
	if not los_enabled:
		return true
	if not has_los_to(player.global_position):
		return false
	var allies: Array[Node] = get_tree().get_nodes_in_group(&"enemy")
	var to_player: Vector2 = (player.global_position - entity.global_position)
	var to_player_len: float = maxf(1.0, to_player.length())
	var to_player_dir: Vector2 = to_player / to_player_len
	for node: Node in allies:
		if node == entity or not (node is Node2D):
			continue
		var other_pos: Vector2 = (node as Node2D).global_position
		var rel: Vector2 = other_pos - entity.global_position
		var proj: float = rel.dot(to_player_dir)
		if proj <= 8.0 or proj >= to_player_len - 8.0:
			continue
		var perp: float = absf(rel.cross(to_player_dir))
		if perp < 18.0:
			return false
	return true


func _try_breadcrumb_chase() -> bool:
	var manager: Node = get_node_or_null("/root/BreadcrumbManager")
	if manager == null:
		return false
	if not manager.has_method("get_trail"):
		return false
	var trail: Array[Vector2] = manager.call("get_trail") as Array[Vector2]
	if trail.is_empty():
		return false

	_breadcrumb_update_timer -= entity.get_physics_process_delta_time()
	var should_update: bool = _breadcrumb_update_timer <= 0.0
	if _breadcrumb_target_index >= 0 and _breadcrumb_target_index < trail.size():
		var target: Vector2 = trail[_breadcrumb_target_index]
		if should_update:
			_breadcrumb_update_timer = BREADCRUMB_UPDATE_INTERVAL
			if entity.global_position.distance_to(target) <= 18.0:
				_breadcrumb_steps_taken += 1
				if _breadcrumb_steps_taken > max_breadcrumb_steps:
					_breadcrumb_target_index = -1
					_breadcrumb_steps_taken = 0
					return false
				_breadcrumb_target_index = mini(_breadcrumb_target_index + 1, trail.size() - 1)
		_move_to_target(trail[_breadcrumb_target_index], move_speed * 0.9)
		return true

	if should_update:
		_breadcrumb_update_timer = BREADCRUMB_UPDATE_INTERVAL
		var search_range: float = breadcrumb_search_range if breadcrumb_search_range > 0.0 else detection_range
		for i: int in range(trail.size() - 1, -1, -1):
			var crumb: Vector2 = trail[i]
			if entity.global_position.distance_to(crumb) <= search_range and has_los_to(crumb):
				_breadcrumb_target_index = i
				_breadcrumb_steps_taken = 0
				_move_to_target(crumb, move_speed * 0.9)
				return true
	return false


func has_los_to(target_pos: Vector2) -> bool:
	if entity == null:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(entity.global_position, target_pos, los_collision_mask, [entity])
	if player != null and is_instance_valid(player):
		query.exclude.append(player)
	var result: Dictionary = entity.get_world_2d().direct_space_state.intersect_ray(query)
	if debug_draw_los and _debug_los_line != null and AIDebug.should_draw_los():
		_debug_los_line.visible = true
		_debug_los_line.points = PackedVector2Array([Vector2.ZERO, entity.to_local(target_pos)])
		_debug_los_line.default_color = Color.GREEN if result.is_empty() else Color.RED
	elif _debug_los_line != null:
		_debug_los_line.visible = false
	return result.is_empty()


func find_player() -> void:
	if player != null and is_instance_valid(player):
		return
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		player = players[0] as Node2D


func _is_player_alive() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var player_health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null and player_health.is_dead:
		return false
	if not player.visible:
		return false
	return true


func _on_active_projectile_tree_exited() -> void:
	_active_projectile = null


func get_attack_direction() -> String:
	if player == null:
		return "S"
	var direction: Vector2 = (player.global_position - entity.global_position).normalized()
	if absf(direction.x) > absf(direction.y):
		return "E" if direction.x > 0.0 else "W"
	return "S" if direction.y > 0.0 else "N"


func play_animation(animation_name: String) -> void:
	if sprite == null or animation_name.is_empty():
		return
	if sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		_facing_x_sign = -1 if direction.x < 0.0 else 1
	if sprite != null and absf(direction.x) > 0.01:
		sprite.flip_h = direction.x < 0.0


func hit(attacker: Node, damage: int) -> void:
	if health_component != null:
		health_component.take_damage(damage, attacker)


func apply_knockback(direction: Vector2, force: float) -> void:
	if entity != null:
		entity.velocity += direction * force


func _on_attack_started(_direction: String) -> void:
	if state != State.SPECIAL_ATTACK:
		play_animation(attack_animation)


func _on_attack_finished() -> void:
	if state == State.DEAD or state == State.SPECIAL_ATTACK:
		return
	_attack_recover_timer = melee_recover_time


func _on_damaged(_amount: int, _remaining: int) -> void:
	if state == State.DEAD:
		return
	state = State.HURT
	hurt_timer = 0.2
	play_animation(hurt_animation)


func _on_died() -> void:
	state = State.DEAD
	entity.velocity = Vector2.ZERO
	if hitbox_spin != null:
		hitbox_spin.monitoring = false
	if _active_projectile != null and is_instance_valid(_active_projectile):
		_active_projectile.queue_free()
		_active_projectile = null
	play_animation(death_animation)
	if sprite != null:
		await sprite.animation_finished
	entity.queue_free()


func _on_spin_hitbox_entered(body: Node) -> void:
	if body == entity:
		return
	if body in _spin_hit_targets:
		return
	_spin_hit_targets.append(body)
	var target_health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
	if target_health != null:
		target_health.take_damage(spin_attack_damage, entity)
	elif body.has_method("hit"):
		body.hit(entity, spin_attack_damage)


func _is_low_health() -> bool:
	if health_component == null:
		return false
	if health_component.max_hp <= 0:
		return false
	return float(health_component.current_hp) / float(health_component.max_hp) <= low_health_retreat_threshold


func get_state_name() -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.PATROL:
			return "PATROL"
		State.INVESTIGATE:
			return "INVESTIGATE"
		State.SEARCH:
			return "SEARCH"
		State.COMBAT:
			return "COMBAT"
		State.ATTACK:
			return "ATTACK"
		State.SPECIAL_ATTACK:
			return "SPECIAL_ATTACK"
		State.RETREAT:
			return "RETREAT"
		State.RECOVER:
			return "RECOVER"
		State.HURT:
			return "HURT"
		State.DEAD:
			return "DEAD"
		_:
			return "UNKNOWN"


func _find_sprite() -> AnimatedSprite2D:
	for child: Node in entity.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
	return null
