extends Node
## GameManager.gd
## Global game state: current race config, pause state, and simple
## progression stubs (credits/XP) so later systems (garage, economy,
## save/load) have a single place to plug into.

signal pause_toggled(is_paused: bool)

var is_paused: bool = false

# --- Progression stubs (Stage 12+ hooks) ---
var credits: int = 0
var xp: int = 0
var player_level: int = 1

# --- Current race context, read by RaceManager on _ready() ---
var opponent_count: int = 3
var lap_count: int = 3
var track_scene_path: String = "res://scenes/track/Track.tscn"
var is_race_input_locked: bool = true # true during countdown


func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_toggled.emit(is_paused)


func award_race_rewards(finish_position: int, stars: int) -> void:
	# Simple placeholder economy hook (Section 36/37 of the design doc).
	var base_credits := 1000
	var position_bonus := maxi(0, (opponent_count + 1 - finish_position)) * 200
	var star_bonus := stars * 300
	credits += base_credits + position_bonus + star_bonus
	xp += 250 + stars * 100
