class_name BlockComponent
extends Component

## Universal block/guard component.
##
## Used by:
## - Player
## - Enemies that can block
##
## Handles block state, toggle, and CD.
## Emits signals so the owning entity can react (play animation, reduce damage, etc).


signal block_started()

signal block_ended()



@export_category("Block Settings")

## Duration (seconds) the entity stays blocking before auto-expiry.
## 0 = indefinite (toggle off manually).
@export var block_duration: float = 0.0



var is_blocking: bool = false:
	set(v):

		if v == is_blocking:

			return


		is_blocking = v


		if is_blocking:

			block_started.emit()

		else:

			block_ended.emit()



var _block_timer: float = 0.0



# ==================================================
# PUBLIC API
# ==================================================

## Start blocking. If already blocking, has no effect.
func start_block() -> void:

	if not active:

		return


	is_blocking = true


	if block_duration > 0.0:

		_block_timer = block_duration


## Stop blocking.
func end_block() -> void:

	is_blocking = false

	_block_timer = 0.0


## Toggle block on/off.
func toggle_block() -> void:

	if is_blocking:

		end_block()

	else:

		start_block()


## Returns true while the entity is actively blocking.
func get_is_blocking() -> bool:

	return is_blocking



# ==================================================
# INTERNAL
# ==================================================

func _process(delta: float) -> void:

	if not is_blocking:

		return


	if block_duration <= 0.0:

		return


	_block_timer -= delta


	if _block_timer <= 0.0:

		end_block()
