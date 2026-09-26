extends Node3D
class_name CameraController
## CameraController.gd — smooth third-person chase camera (Section 18).

@export var target: Node3D
@export var follow_distance: float = 7.0
@export var follow_distance_fast: float = 9.5
@export var follow_height: float = 2.6
@export var look_ahead: float = 3.0
@export var position_smoothing: float = 5.0
@export var rotation_smoothing: float = 6.0
@export var base_fov: float = 70.0
@export var max_fov: float = 84.0
@export var max_speed_for_fov: float = 42.0

@onready var camera: Camera3D = $Camera3D

var shake_time: float = 0.0
var shake_strength: float = 0.0


func _ready() -> void:
	if target:
		var t: Transform3D = _desired_transform()
		global_transform = t


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var vehicle := target as VehicleController
	var speed: float = 0.0
	if vehicle:
		speed = absf(vehicle.current_speed)

	var desired: Transform3D = _desired_transform(speed)
	global_transform.origin = global_transform.origin.lerp(desired.origin, position_smoothing * delta)

	var look_target: Vector3 = target.global_position + (-target.global_transform.basis.z * look_ahead)
	look_target.y += follow_height * 0.5
	var current_basis := global_transform.basis
	global_transform = global_transform.looking_at(look_target, Vector3.UP)
	global_transform.basis = current_basis.slerp(global_transform.basis, rotation_smoothing * delta)

	if camera:
		var speed_ratio: float = clampf(speed / max_speed_for_fov, 0.0, 1.0)
		camera.fov = lerp(camera.fov, lerp(base_fov, max_fov, speed_ratio), 4.0 * delta)

	if shake_time > 0.0:
		shake_time -= delta
		var offset := Vector3(
			randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)
		) * shake_strength * clampf(shake_time, 0.0, 1.0)
		camera.h_offset = offset.x * 0.05
		camera.v_offset = offset.y * 0.05
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _desired_transform(speed: float = 0.0) -> Transform3D:
	var dist: float = lerpf(follow_distance, follow_distance_fast, clampf(speed / max_speed_for_fov, 0.0, 1.0))
	var back: Vector3 = target.global_transform.basis.z.normalized()
	var origin: Vector3 = target.global_position + back * dist + Vector3.UP * follow_height
	return Transform3D(Basis(), origin)


func shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_time = maxf(shake_time, duration)
