class_name EnemyManager
extends Node2D


## EnemyManager
##
## Handles spawning, tracking, and removing enemies.
##
## Enemies are dynamically created and are not manually placed
## inside the world scene.
##
## Supports multiple enemy scenes through the Inspector.
##
## Example:
## Enemy Scenes:
##   - Orc 1
##   - Orc 2
##   - Wolf



# ==================================================
# INSPECTOR SETTINGS
# ==================================================

@export_category("Enemy Settings")


## Enemy scenes that can spawn.
## Drag enemy .tscn files here.
@export var enemy_scenes: Array[PackedScene] = []


## Maximum number of active enemies allowed.
@export var max_enemies: int = 5



@export_category("Spawn Settings")


## Distance around the manager where enemies appear.
@export var spawn_radius: float = 200.0


## Number of enemies created when the manager starts.
@export var starting_enemy_count: int = 3


## Automatically create replacements when enemies die.
@export var auto_respawn: bool = true


## Time before a replacement enemy appears.
@export var respawn_delay: float = 3.0



# ==================================================
# VARIABLES
# ==================================================

var active_enemies: Array[Node] = []



# ==================================================
# READY
# ==================================================

func _ready() -> void:

	randomize()


	for i in range(starting_enemy_count):

		spawn_enemy()



# ==================================================
# SPAWNING
# ==================================================

func spawn_enemy() -> void:


	if enemy_scenes.is_empty():

		push_warning(
			"EnemyManager: No enemy scenes assigned."
		)

		return



	if active_enemies.size() >= max_enemies:

		return



	var selected_scene: PackedScene = (
		enemy_scenes.pick_random()
	)



	if selected_scene == null:

		return



	var enemy: Node = selected_scene.instantiate()



	add_child(enemy)



	enemy.global_position = (
		global_position
		+
		Vector2(
			randf_range(
				-spawn_radius,
				spawn_radius
			),

			randf_range(
				-spawn_radius,
				spawn_radius
			)
		)
	)



	active_enemies.append(enemy)



	enemy.tree_exited.connect(
		_on_enemy_removed.bind(enemy)
	)



# ==================================================
# REMOVAL
# ==================================================

func _on_enemy_removed(enemy: Node) -> void:


	if enemy in active_enemies:

		active_enemies.erase(enemy)



	if auto_respawn:

		_schedule_respawn()



# ==================================================
# RESPAWN
# ==================================================

func _schedule_respawn() -> void:


	if get_tree() == null:
		return

	await get_tree().create_timer(
		respawn_delay
	).timeout


	# Guard: manager might have been removed from tree during the await
	if get_tree() == null:
		return


	spawn_enemy()



# ==================================================
# UTILITY
# ==================================================

func get_enemy_count() -> int:

	return active_enemies.size()



func clear_all_enemies() -> void:


	for enemy in active_enemies:

		if is_instance_valid(enemy):

			enemy.queue_free()



	active_enemies.clear()
