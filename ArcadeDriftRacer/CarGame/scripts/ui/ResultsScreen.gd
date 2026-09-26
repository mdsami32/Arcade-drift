extends CanvasLayer
class_name ResultsScreen
## ResultsScreen.gd (Section 43) — end-of-race summary and rewards.

@onready var position_label: Label = $Panel/VBox/PositionLabel
@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var rewards_label: Label = $Panel/VBox/RewardsLabel
@onready var restart_button: Button = $Panel/VBox/Buttons/RestartButton
@onready var menu_button: Button = $Panel/VBox/Buttons/MenuButton


func _ready() -> void:
	hide()
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	menu_button.pressed.connect(func(): get_tree().quit()) # stub until a real Main Menu scene exists


func show_results(ranking: Array, player_vehicle: Node3D, race_time: float) -> void:
	var finish_position: int = 1
	for i in ranking.size():
		if ranking[i].vehicle == player_vehicle:
			finish_position = i + 1
			break

	var stars: int = 1
	if finish_position == 1:
		stars = 3
	elif race_time < 999.0:
		stars = 2

	GameManager.award_race_rewards(finish_position, stars)

	var suffix := "th"
	if finish_position == 1:
		suffix = "st"
	elif finish_position == 2:
		suffix = "nd"
	elif finish_position == 3:
		suffix = "rd"

	position_label.text = "%d%s PLACE" % [finish_position, suffix]
	var minutes: int = int(race_time) / 60
	var seconds: float = fmod(race_time, 60.0)
	time_label.text = "Time: %02d:%05.2f" % [minutes, seconds]
	rewards_label.text = "%s\n+%d Credits   +%d XP" % ["★".repeat(stars) + "☆".repeat(3 - stars), 1000, 250]

	show()
	get_tree().paused = true
