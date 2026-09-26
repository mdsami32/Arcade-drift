extends Area3D
class_name Checkpoint
## Checkpoint.gd (Section 24) — detects vehicles passing in order.

signal vehicle_passed(vehicle: Node3D, checkpoint: Checkpoint)

@export var checkpoint_index: int = 0
@export var is_start_finish_line: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2 # vehicles only (see LayerMap below)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("vehicle"):
		vehicle_passed.emit(body, self)
