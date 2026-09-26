extends VehicleController
class_name AIController
## AIController.gd
## Simple waypoint-following AI (Section 26). Follows the Waypoints node
## set by RaceManager, with per-difficulty skill parameters.

enum Difficulty { EASY, NORMAL, HARD, EXPERT }

@export var difficulty: Difficulty = Difficulty.NORMAL

var waypoints: Array[Node3D] = []
var current_waypoint_index: int = 0

var skill_max_speed_mult: float = 1.0
var skill_cornering: float = 1.0
var skill_mistake_chance: float = 0.05
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng.randomize()
	match difficulty:
		Difficulty.EASY:
			skill_max_speed_mult = 0.78
			skill_cornering = 0.7
			skill_mistake_chance = 0.12
		Difficulty.NORMAL:
			skill_max_speed_mult = 0.90
			skill_cornering = 0.85
			skill_mistake_chance = 0.06
		Difficulty.HARD:
			skill_max_speed_mult = 0.98
			skill_cornering = 1.0
			skill_mistake_chance = 0.02
		Difficulty.EXPERT:
			skill_max_speed_mult = 1.05
			skill_cornering = 1.15
			skill_mistake_chance = 0.0


func set_waypoints(points: Array[Node3D]) -> void:
	waypoints = points
	current_waypoint_index = 0


func get_drive_input() -> Vector3:
	if waypoints.is_empty():
		return Vector3.ZERO

	var target: Node3D = waypoints[current_waypoint_index]
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0

	if to_target.length() < 8.0:
		current_waypoint_index = (current_waypoint_index + 1) % waypoints.size()
		target = waypoints[current_waypoint_index]
		to_target = target.global_position - global_position
		to_target.y = 0.0

	var forward: Vector3 = -global_transform.basis.z
	var angle_to_target: float = forward.signed_angle_to(to_target.normalized(), Vector3.UP)

	# Occasional believable mistakes (Section 26).
	if _rng.randf() < skill_mistake_chance * get_physics_process_delta_time():
		angle_to_target += _rng.randf_range(-0.5, 0.5)

	var steer: float = clampf(angle_to_target * 2.2 * skill_cornering, -1.0, 1.0)

	# Slow down for sharp corners, speed up on straights.
	var corner_sharpness: float = clampf(absf(angle_to_target) / 1.2, 0.0, 1.0)
	var throttle: float = lerpf(1.0, 0.45, corner_sharpness) * skill_max_speed_mult

	var handbrake: float = 1.0 if corner_sharpness > 0.75 and speed_kmh() > 40.0 else 0.0

	# AI rubber-banding hook (Section 27) can adjust skill_max_speed_mult
	# from RaceManager based on relative race position — left as a stub
	# so it stays subtle and configurable rather than hardcoded here.

	return Vector3(throttle, steer, handbrake)
