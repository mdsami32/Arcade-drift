extends CharacterBody3D
class_name VehicleController
## VehicleController.gd
##
## Arcade-style driving controller (Sections 3-13 of the design doc).
## Built on CharacterBody3D rather than VehicleBody3D so handling stays
## fully arcade-tunable instead of fighting a wheel-collider simulation.
##
## Reusable for both the player (input read from Input singleton) and
## AI (AIController overrides get_drive_input()).

signal started_drift
signal stopped_drift
signal hard_landed(impact_speed: float)
signal collided(impact_speed: float)

# --- Vehicle stats (would live in a VehicleData Resource per Section 57) ---
@export_group("Engine")
@export var max_speed: float = 42.0          # m/s (~150 km/h)
@export var reverse_max_speed: float = 10.0
@export var acceleration: float = 18.0
@export var brake_power: float = 32.0
@export var engine_brake: float = 6.0        # coast-down when no throttle

@export_group("Steering")
@export var steering_angle_max: float = 0.6   # radians at low speed
@export var steering_speed: float = 6.0       # interpolation rate
@export var high_speed_steer_reduction: float = 0.45 # min multiplier at max speed

@export_group("Grip / Drift")
@export var grip: float = 9.0                 # how fast velocity aligns to facing
@export var drift_grip: float = 2.2           # grip while handbraking
@export var drift_turn_boost: float = 1.6

@export_group("Feel")
@export var body_tilt_max_deg: float = 6.0
@export var gravity_scale: float = 1.0

var current_speed: float = 0.0          # signed, + forward / - reverse
var steer_angle: float = 0.0
var is_drifting: bool = false
var is_reversing: bool = false
var was_on_floor: bool = true
var air_time: float = 0.0

@onready var visual_body: Node3D = get_node_or_null("VisualBody")
@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

var spawn_transform: Transform3D


func _ready() -> void:
	spawn_transform = global_transform


func speed_kmh() -> float:
	return current_speed * 3.6


## Override in AIController. Returns (throttle, steer, handbrake) each -1..1 / bool.
func get_drive_input() -> Vector3:
	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var handbrake := 1.0 if Input.is_action_pressed("handbrake") else 0.0
	return Vector3(throttle, steer, handbrake)


func _physics_process(delta: float) -> void:
	if GameManager.is_paused:
		return

	if Input.is_action_just_pressed("reset_vehicle") and is_in_group("player"):
		reset_to(spawn_transform)
		return

	var input := get_drive_input()
	var throttle: float = clampf(input.x, -1.0, 1.0)
	var steer_input: float = clampf(input.y, -1.0, 1.0)
	var handbrake_held: bool = input.z > 0.5

	if GameManager.is_race_input_locked:
		# Countdown: engines can rev in place but the car may not launch (Section 19).
		throttle = 0.0

	_apply_drive(throttle, steer_input, handbrake_held, delta)
	_apply_gravity_and_move(delta)
	_update_visual_tilt(throttle, steer_input, delta)


func _apply_drive(throttle: float, steer_input: float, handbrake_held: bool, delta: float) -> void:
	# --- Acceleration / braking / reverse (Sections 5-7) ---
	var speed_ratio: float = absf(current_speed) / max_speed
	var accel_curve: float = lerpf(1.0, 0.55, clampf(speed_ratio, 0.0, 1.0)) # taper near top speed

	if throttle > 0.05:
		if current_speed < 0.0:
			# braking out of reverse
			current_speed = move_toward(current_speed, 0.0, brake_power * delta)
		else:
			current_speed = move_toward(current_speed, max_speed, acceleration * accel_curve * throttle * delta)
	elif throttle < -0.05:
		if current_speed > 0.5:
			# braking, gets stronger at higher speed (Section 6)
			var brake_strength: float = brake_power * (1.0 + speed_ratio * 0.5)
			current_speed = move_toward(current_speed, 0.0, brake_strength * delta)
		else:
			# reverse (Section 7)
			current_speed = move_toward(current_speed, -reverse_max_speed, acceleration * -throttle * delta)
	else:
		# coast: engine braking / rolling friction
		current_speed = move_toward(current_speed, 0.0, engine_brake * delta)

	is_reversing = current_speed < -0.1

	# --- Steering (Section 8) ---
	var speed_factor: float = clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var steer_reduction: float = lerpf(1.0, high_speed_steer_reduction, speed_factor)
	var target_steer: float = steer_input * steering_angle_max * steer_reduction
	steer_angle = lerp(steer_angle, target_steer, steering_speed * delta)

	# Reverse steering feels natural if we just flip sign of turn direction
	var steer_dir: float = -1.0 if is_reversing else 1.0

	# --- Drift (Section 10) ---
	var drifting_now: bool = handbrake_held and absf(current_speed) > 2.0
	if drifting_now and not is_drifting:
		started_drift.emit()
	elif not drifting_now and is_drifting:
		stopped_drift.emit()
	is_drifting = drifting_now

	var turn_multiplier: float = drift_turn_boost if is_drifting else 1.0
	var move_speed_for_turn: float = clampf(absf(current_speed) / 6.0, 0.0, 1.0) # no spinning in place

	if absf(current_speed) > 0.05:
		rotate_y(-steer_angle * steer_dir * turn_multiplier * move_speed_for_turn * delta * 2.5)

	# --- Grip / velocity blending (Section 9) ---
	var current_grip: float = drift_grip if is_drifting else grip
	var forward: Vector3 = -global_transform.basis.z
	var desired_velocity: Vector3 = forward * current_speed
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.lerp(desired_velocity, clampf(current_grip * delta, 0.0, 1.0))
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_gravity_and_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta
		air_time += delta
	else:
		if not was_on_floor and air_time > 0.35:
			hard_landed.emit(absf(velocity.y))
		velocity.y = -1.0 # keep glued to ground
		air_time = 0.0

	was_on_floor = is_on_floor()

	var pre_move_speed: float = velocity.length()
	move_and_slide()

	# crude collision feedback (Section 14 hook)
	if get_slide_collision_count() > 0 and pre_move_speed > 6.0:
		collided.emit(pre_move_speed)


func _update_visual_tilt(throttle: float, steer_input: float, delta: float) -> void:
	if visual_body == null:
		return
	# Weight transfer (Section 11): purely visual pitch/roll, no gameplay effect yet.
	var pitch_target: float = deg_to_rad(-body_tilt_max_deg) * throttle
	var roll_target: float = deg_to_rad(body_tilt_max_deg) * steer_input * clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	visual_body.rotation.x = lerp_angle(visual_body.rotation.x, pitch_target, 6.0 * delta)
	visual_body.rotation.z = lerp_angle(visual_body.rotation.z, roll_target, 6.0 * delta)


func reset_to(t: Transform3D) -> void:
	global_transform = t
	current_speed = 0.0
	velocity = Vector3.ZERO
	steer_angle = 0.0
