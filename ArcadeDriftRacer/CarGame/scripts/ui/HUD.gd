extends CanvasLayer
class_name HUD
## HUD.gd (Section 40) — minimal readable race HUD.

@onready var speed_label: Label = $Margin/Speed
@onready var position_label: Label = $Margin/Position
@onready var lap_label: Label = $Margin/Lap
@onready var timer_label: Label = $Margin/Timer
@onready var countdown_label: Label = $Countdown

var player_vehicle: VehicleController
var race_manager: RaceManager


func setup(vehicle: VehicleController, manager: RaceManager) -> void:
	player_vehicle = vehicle
	race_manager = manager
	race_manager.hud_update.connect(_on_hud_update)
	race_manager.countdown_tick.connect(_on_countdown_tick)


func _process(_delta: float) -> void:
	if player_vehicle:
		speed_label.text = "%d KM/H" % int(round(player_vehicle.speed_kmh()))


func _on_hud_update(data: Dictionary) -> void:
	var ranking: Array = data.get("ranking", [])
	var pos: int = 1
	for i in ranking.size():
		if ranking[i].vehicle == player_vehicle:
			pos = i + 1
			break
	position_label.text = "POSITION\n%d / %d" % [pos, ranking.size()]

	var laps: int = 0
	if race_manager and race_manager.progress.has(player_vehicle):
		laps = race_manager.progress[player_vehicle].laps
	lap_label.text = "LAP %d / %d" % [mini(laps + 1, race_manager.lap_count), race_manager.lap_count]

	var t: float = data.get("time", 0.0)
	var minutes: int = int(t) / 60
	var seconds: float = fmod(t, 60.0)
	timer_label.text = "%02d:%05.2f" % [minutes, seconds]


func _on_countdown_tick(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = text != ""
