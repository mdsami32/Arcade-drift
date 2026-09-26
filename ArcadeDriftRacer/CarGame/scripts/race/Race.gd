extends Node3D
## Race.gd — Stage 1 "first playable" wiring (Section 61):
## spawns the player + 3 AI opponents on the track, starts RaceManager's
## countdown, and hooks up HUD / camera / results.

const CarScene := preload("res://scenes/vehicles/Car.tscn")
const AICarScene := preload("res://scenes/vehicles/AICar.tscn")
const HUDScene := preload("res://scenes/ui/HUD.tscn")
const ResultsScene := preload("res://scenes/ui/ResultsScreen.tscn")

@onready var track: Track = $Track
@onready var camera_rig: CameraController = $CameraRig

var pause_label: Label


func _ready() -> void:
	var spawns: Array[Marker3D] = track.get_spawn_points()

	var player: VehicleController = CarScene.instantiate()
	add_child(player)
	player.global_transform = spawns[0].global_transform

	var ai_cars: Array[Node3D] = []
	var difficulties := [AIController.Difficulty.NORMAL, AIController.Difficulty.NORMAL, AIController.Difficulty.HARD]
	for i in range(3):
		var ai: AIController = AICarScene.instantiate()
		add_child(ai)
		ai.global_transform = spawns[i + 1].global_transform
		ai.difficulty = difficulties[i]
		ai.set_waypoints(track.get_waypoints())
		ai_cars.append(ai)

	var all_vehicles: Array[Node3D] = [player]
	all_vehicles.append_array(ai_cars)

	var race_manager := RaceManager.new()
	race_manager.name = "RaceManager"
	race_manager.lap_count = GameManager.lap_count
	add_child(race_manager)
	race_manager.setup(track.get_checkpoints(), all_vehicles)

	var hud: HUD = HUDScene.instantiate()
	add_child(hud)
	hud.setup(player, race_manager)

	var results: ResultsScreen = ResultsScene.instantiate()
	add_child(results)
	race_manager.race_finished.connect(func(ranking): results.show_results(ranking, player, race_manager.race_time))

	camera_rig.target = player
	player.hard_landed.connect(func(_speed): camera_rig.shake(1.0, 0.3))
	player.collided.connect(func(speed): camera_rig.shake(clampf(speed / 20.0, 0.2, 1.0), 0.25))

	_setup_pause_overlay()


func _setup_pause_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	pause_label = Label.new()
	pause_label.text = "PAUSED\n(Esc to resume)"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.set_anchors_preset(Control.PRESET_CENTER)
	pause_label.add_theme_font_size_override("font_size", 40)
	pause_label.visible = false
	pause_label.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_label)
	GameManager.pause_toggled.connect(func(is_paused): pause_label.visible = is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		GameManager.toggle_pause()
