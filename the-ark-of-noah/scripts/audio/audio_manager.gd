extends Node

## ============================================================================
## AUDIO MANAGER — Central sound system for The Ark of Noah.
##
## Picks up audio cues from game_stats metadata and plays the matching sound.
##
## WORKFLOW — Replacing placeholders with real sounds:
##   1. Drop your real .wav file into  res://assets/audio/
##   2. Name it the base filename (e.g., "player_walk_grass.wav")
##   3. That's it — the AudioManager checks there first, then falls back
##      to the placeholder (_placeholder.wav) in assets/placeholders/audio/
## ============================================================================

## Maps emitted hook cue names → base filenames (no extension or _placeholder suffix).
const CUE_FILE_MAP: Dictionary = {
	# Player footsteps (player.gd emits "footstep_<surface>")
	"footstep_grass": "player_walk_grass",
	"footstep_dirt": "player_walk_dirt",
	"footstep_stone": "player_walk_stone",
	"footstep_wood": "player_walk_wood",
	"footstep_sand": "player_walk_grass",
	"footstep_water": "player_walk_grass",
	"footstep_ground": "player_walk_dirt",

	# Player actions
	"player_swing_hoe": "player_swing_hoe",
	"player_swing_axe": "player_swing_axe",
	"player_swing_pickaxe": "player_swing_pickaxe",
	"player_attack_sword": "player_sword_attack",
	"player_damage": "player_damage",

	# Mining (breakable_rock.gd emits "mining_hit" / "mining_break")
	"mining_hit": "mining_rock_hit",
	"mining_break": "mining_ore_break",

	# Item drops
	"item_drop": "mining_item_drop",
	"item_pickup": "crafting_pickup_object",
	"item_place": "crafting_place_object",

	# Farming
	"farming_till": "farming_till_soil",
	"farming_plant": "farming_plant_seed",
	"farming_water": "farming_water_crop",
	"farming_harvest": "farming_harvest",

	# Crafting
	"crafting_complete": "crafting_complete",

	# Trees
	"tree_chop": "tree_chop",
	"tree_fall": "tree_fall",
	"tree_leaves": "tree_leaves",

	# Animals
	"animal_idle": "animal_idle",
	"animal_eating": "animal_eating",

	# Menu / UI
	"menu_hover": "menu_button_hover",
	"menu_click": "menu_button_click",
	"menu_open": "menu_window_open",
	"menu_close": "menu_window_close",
	"inventory_open": "menu_inventory_open",
	"inventory_close": "menu_inventory_close",

	# Misc
	"blacksmith_trade_success": "menu_button_click",
	"blacksmith_trade_fail": "menu_window_close",
}

## How many AudioStreamPlayer nodes to pool for one-shot SFX.
const SFX_PLAYER_COUNT: int = 12

## Directory where users place their real audio files.
const USER_AUDIO_DIR: String = "res://assets/audio/"

## Directory containing _placeholder.wav fallbacks.
const PLACEHOLDER_AUDIO_DIR: String = "res://assets/placeholders/audio/"

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _audio_cache: Dictionary = {}
var _game_stats: Node = null


# ============================================================================
# LIFE CYCLE
# ============================================================================

func _ready() -> void:
	# Pool of AudioStreamPlayers for overlapping SFX
	for i in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

	_game_stats = get_node_or_null("/root/game_stats")


func _process(_delta: float) -> void:
	if _game_stats == null:
		_game_stats = get_node_or_null("/root/game_stats")
		if _game_stats == null:
			return

	# Poll for pending audio cues
	var cue: Variant = _game_stats.get_meta(&"last_audio_cue", &"")
	if cue is String and not (cue as String).is_empty():
		# Clear immediately so the next cue can be detected
		_game_stats.set_meta(&"last_audio_cue", &"")
		_play_cue(cue as String)


# ============================================================================
# PUBLIC API
# ============================================================================

## Manually play a named cue. Useful for direct calls from scripts.
func play_cue(cue_name: String) -> void:
	_play_cue(cue_name)


# ============================================================================
# INTERNAL
# ============================================================================

func _play_cue(cue: String) -> void:
	var base_name: String = CUE_FILE_MAP.get(cue, &"")
	if base_name.is_empty():
		return

	var stream: AudioStream = _resolve_stream(base_name)
	if stream == null:
		return

	var player: AudioStreamPlayer = _sfx_players[_next_player]
	_next_player = (_next_player + 1) % SFX_PLAYER_COUNT
	player.stream = stream
	player.play()


## Resolve an AudioStream for a base filename.
## Priority: user real sound → placeholder fallback → null.
func _resolve_stream(base_name: String) -> AudioStream:
	var user_path: String = USER_AUDIO_DIR + base_name + ".wav"
	if _audio_cache.has(user_path):
		return _audio_cache[user_path] as AudioStream
	if ResourceLoader.exists(user_path):
		var stream: AudioStream = load(user_path)
		if stream != null:
			_audio_cache[user_path] = stream
			return stream

	var placeholder_path: String = PLACEHOLDER_AUDIO_DIR + base_name + "_placeholder.wav"
	if _audio_cache.has(placeholder_path):
		return _audio_cache[placeholder_path] as AudioStream
	if ResourceLoader.exists(placeholder_path):
		var stream: AudioStream = load(placeholder_path)
		if stream != null:
			_audio_cache[placeholder_path] = stream
			return stream

	return null
