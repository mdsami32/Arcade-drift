extends Node
class_name RaceManager
## RaceManager.gd (Section 55) — owns checkpoint/lap tracking, the start
## countdown, live race positions, and finish/results handoff.
## EventManager-equivalent for this first playable slice.

signal countdown_tick(text: String)
signal race_started
signal race_finished(results: Array)
signal hud_update(data: Dictionary)

@export var lap_count: int = 3
@export var countdown_seconds: int = 3

var checkpoints: Array[Checkpoint] = []
var vehicles: Array[Node3D] = []
var progress: Dictionary = {} # vehicle -> {expected_index, laps, finished, finish_time, distance_to_next}

var race_time: float = 0.0
var race_active: bool = false
var _finish_order: Array = []


func setup(checkpoint_nodes: Array[Checkpoint], vehicle_nodes: Array[Node3D]) -> void:
	checkpoints = checkpoint_nodes
	checkpoints.sort_custom(func(a, b): return a.checkpoint_index < b.checkpoint_index)
	vehicles = vehicle_nodes

	for cp in checkpoints:
		cp.vehicle_passed.connect(_on_checkpoint_passed)

	for v in vehicles:
		progress[v] = {
			"expected_index": 1 if checkpoints.size() > 1 else 0,
			"laps": 0,
			"finished": false,
			"finish_time": 0.0,
			"distance_to_next": 999999.0,
		}

	GameManager.lap_count = lap_count
	_start_countdown()


func _start_countdown() -> void:
	GameManager.is_race_input_locked = true
	for i in range(countdown_seconds, 0, -1):
		countdown_tick.emit(str(i))
		await get_tree().create_timer(1.0).timeout
	countdown_tick.emit("GO!")
	GameManager.is_race_input_locked = false
	race_active = true
	race_started.emit()
	await get_tree().create_timer(0.6).timeout
	countdown_tick.emit("")


func _process(delta: float) -> void:
	if not race_active or GameManager.is_paused:
		return

	race_time += delta
	_update_distances()
	var ranking: Array = _current_ranking()
	hud_update.emit({
		"time": race_time,
		"ranking": ranking,
	})


func _update_distances() -> void:
	for v in vehicles:
		if not is_instance_valid(v):
			continue
		var p: Dictionary = progress[v]
		if p.finished or checkpoints.is_empty():
			continue
		var next_cp: Checkpoint = checkpoints[p.expected_index]
		p.distance_to_next = v.global_position.distance_to(next_cp.global_position)


func _current_ranking() -> Array:
	var scored: Array = []
	var total_cp: int = maxi(checkpoints.size(), 1)
	for v in vehicles:
		if not is_instance_valid(v):
			continue
		var p: Dictionary = progress[v]
		var score: float = p.laps * total_cp * 1000.0 + p.expected_index * 1000.0 - p.distance_to_next
		if p.finished:
			score = 999999999.0 - p.finish_time # finished vehicles rank by finish time
		scored.append({"vehicle": v, "score": score, "finished": p.finished})
	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored


func _on_checkpoint_passed(vehicle: Node3D, checkpoint: Checkpoint) -> void:
	if not race_active or not progress.has(vehicle):
		return
	var p: Dictionary = progress[vehicle]
	if p.finished:
		return

	if checkpoint.checkpoint_index != p.expected_index:
		return # wrong order — ignore (Section 54 validation)

	if checkpoint.is_start_finish_line and checkpoint.checkpoint_index == 0:
		p.laps += 1
		if p.laps >= lap_count:
			p.finished = true
			p.finish_time = race_time
			_finish_order.append(vehicle)
			if vehicle.is_in_group("player"):
				_end_race()
			return

	p.expected_index = (checkpoint.checkpoint_index + 1) % checkpoints.size()


func _end_race() -> void:
	race_active = false
	var ranking: Array = _current_ranking()
	race_finished.emit(ranking)
