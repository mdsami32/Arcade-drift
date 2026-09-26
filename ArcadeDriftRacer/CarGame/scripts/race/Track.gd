extends Node3D
class_name Track
## Track.gd (Section 29) — builds a simple oval circuit procedurally so
## the first playable slice doesn't depend on hand-authored curve meshes.
## Swap this out later for real modular TrackSegment scenes (straights,
## hairpins, jumps, etc.) without touching RaceManager/AI.

@export var radius_x: float = 70.0
@export var radius_z: float = 45.0
@export var num_checkpoints: int = 10
@export var waypoints_per_checkpoint: int = 3
@export var road_width: float = 14.0

var _checkpoints: Array[Checkpoint] = []
var _waypoints: Array[Node3D] = []
var _spawn_points: Array[Marker3D] = []


func _ready() -> void:
	_build_ground()
	_build_loop()


func get_checkpoints() -> Array[Checkpoint]:
	return _checkpoints


func get_waypoints() -> Array[Node3D]:
	return _waypoints


func get_spawn_points() -> Array[Marker3D]:
	return _spawn_points


func _oval_point(t: float) -> Vector3:
	var angle: float = t * TAU
	return Vector3(sin(angle) * radius_x, 0.0, -cos(angle) * radius_z)


func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3((radius_x + 40) * 2.0, 1.0, (radius_z + 40) * 2.0)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = box.size
	mesh_inst.mesh = plane
	mesh_inst.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.5, 0.28)
	mat.roughness = 1.0
	mesh_inst.set_surface_override_material(0, mat)
	ground.add_child(mesh_inst)


func _build_loop() -> void:
	var checkpoints_node := Node3D.new()
	checkpoints_node.name = "Checkpoints"
	add_child(checkpoints_node)

	var waypoints_node := Node3D.new()
	waypoints_node.name = "Waypoints"
	add_child(waypoints_node)

	var spawns_node := Node3D.new()
	spawns_node.name = "SpawnPoints"
	add_child(spawns_node)

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.22, 0.24)
	road_mat.roughness = 0.9

	# Draw a continuous road ribbon out of short straight tiles between
	# consecutive sample points (robust to author without a curve tool).
	var road_samples: int = num_checkpoints * 8
	var prev_point: Vector3 = _oval_point(0.0)
	for i in range(1, road_samples + 1):
		var t: float = float(i) / road_samples
		var point: Vector3 = _oval_point(t)
		_add_road_tile(prev_point, point, road_width, road_mat)
		prev_point = point

	# Checkpoints (sparse, gameplay-relevant order/lap gates).
	for i in range(num_checkpoints):
		var t: float = float(i) / num_checkpoints
		var point: Vector3 = _oval_point(t)
		var next_point: Vector3 = _oval_point(t + 1.0 / num_checkpoints)
		var facing: Vector3 = (next_point - point).normalized()

		var cp := Checkpoint.new()
		cp.checkpoint_index = i
		cp.is_start_finish_line = (i == 0)
		cp.collision_layer = 0
		cp.collision_mask = 2
		checkpoints_node.add_child(cp)
		cp.global_position = point + Vector3.UP * 3.0
		cp.look_at(cp.global_position + facing, Vector3.UP)

		var gate_shape := CollisionShape3D.new()
		var gate_box := BoxShape3D.new()
		gate_box.size = Vector3(road_width, 6.0, 1.0)
		gate_shape.shape = gate_box
		cp.add_child(gate_shape)

		_add_gate_visual(cp, i == 0)

	# Denser waypoints for AI steering targets.
	var total_waypoints: int = num_checkpoints * waypoints_per_checkpoint
	for i in range(total_waypoints):
		var t: float = float(i) / total_waypoints
		var wp := Marker3D.new()
		waypoints_node.add_child(wp)
		wp.global_position = _oval_point(t)
	_waypoints.assign(waypoints_node.get_children())
	_checkpoints.assign(checkpoints_node.get_children())

	# Spawn grid just behind the start line, 2 across x N rows.
	var start_point: Vector3 = _oval_point(0.0)
	var start_facing: Vector3 = (_oval_point(1.0 / num_checkpoints) - start_point).normalized()
	var right: Vector3 = start_facing.cross(Vector3.UP).normalized()
	for row in range(4):
		var lane: float = 1 if row % 2 == 0 else -1
		var back_offset: float = 6.0 + row * 5.0
		var spawn := Marker3D.new()
		spawns_node.add_child(spawn)
		spawn.global_position = start_point - start_facing * back_offset + right * lane * 2.5
		spawn.look_at(spawn.global_position + start_facing, Vector3.UP)
	_spawn_points.assign(spawns_node.get_children())


func _add_road_tile(from: Vector3, to: Vector3, width: float, mat: StandardMaterial3D) -> void:
	var mid: Vector3 = (from + to) * 0.5
	var length: float = from.distance_to(to) + 0.4
	var tile := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.05, length)
	tile.mesh = box
	tile.set_surface_override_material(0, mat)
	tile.position = mid + Vector3.UP * 0.01
	var dir: Vector3 = (to - from).normalized()
	if dir.length() > 0.01:
		tile.look_at(tile.position + dir, Vector3.UP)
	add_child(tile)


func _add_gate_visual(cp: Checkpoint, is_start: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1) if is_start else Color(0.9, 0.9, 0.95)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.6

	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.4, 6.0, 0.4)
		post.mesh = post_mesh
		post.set_surface_override_material(0, mat)
		post.position = Vector3(side * road_width * 0.5, 0.0, 0.0)
		cp.add_child(post)

	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(road_width + 0.4, 0.4, 0.4)
	bar.mesh = bar_mesh
	bar.set_surface_override_material(0, mat)
	bar.position = Vector3(0, 3.0, 0)
	cp.add_child(bar)
