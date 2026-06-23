extends CanvasLayer

@onready var book := get_node_or_null("Book/BookSprite")
@onready var page_turn := get_node_or_null("Book/PageTurn")

@onready var corner_next := get_node_or_null("Book/UI/PageSystem/PageRight/CornerNext")
@onready var corner_prev := get_node_or_null("Book/UI/PageSystem/PageLeft/CornerPrev")

var open := false
var busy := false


# ---------------- READY ----------------
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_validate_nodes()


# ---------------- INPUT ----------------
func _unhandled_input(event):
	if event.is_action_pressed("pause") and not busy:
		if open:
			close_book()
		else:
			open_book()


# ---------------- OPEN BOOK ----------------
func open_book():
	busy = true
	open = true

	visible = true
	get_tree().paused = true

	_apply_layout()

	# STEP 1: PLAY BOOK OPENING
	if book:
		book.visible = true
		book.stop()
		book.frame = 0
		book.play("book_opening")

	# WAIT FOR BOOK ANIMATION TO FINISH
	await book.animation_finished

	# STEP 2: HIDE BOOK
	book.visible = false

	# STEP 3: SHOW PAGE TURN
	if page_turn:
		page_turn.visible = true
		page_turn.z_index = 100
		page_turn.stop()
		page_turn.frame = 0
		page_turn.play("next_page")

	# ENABLE CORNERS AFTER TRANSITION
	_set_corners(true)

	busy = false


# ---------------- CLOSE BOOK ----------------
func close_book():
	busy = true

	_set_corners(false)

	# STEP 1: PLAY PAGE TURN BACKWARD
	if page_turn:
		page_turn.play("previous_page")
		await page_turn.animation_finished
		page_turn.visible = false

	# STEP 2: SHOW BOOK AGAIN
	if book:
		book.visible = true
		book.stop()
		book.frame = 0
		book.play("book_opening")

	# WAIT FOR BOOK TO CLOSE ANIMATION
	await book.animation_finished

	get_tree().paused = false

	visible = false
	open = false
	busy = false


# ---------------- LAYOUT ----------------
func _apply_layout():
	var center = get_viewport().get_visible_rect().size * 0.5

	if book:
		book.position = center

	if page_turn:
		page_turn.position = center
		page_turn.visible = false


# ---------------- CORNERS ----------------
func _set_corners(enabled: bool):
	if corner_next:
		corner_next.visible = enabled
		corner_next.disabled = not enabled

	if corner_prev:
		corner_prev.visible = enabled
		corner_prev.disabled = not enabled


# ---------------- VALIDATION ----------------
func _validate_nodes():
	if not book:
		push_error("Missing BookSprite node")

	if not page_turn:
		push_error("Missing PageTurn node")

	if not corner_next:
		push_error("Missing CornerNext node")

	if not corner_prev:
		push_error("Missing CornerPrev node")
