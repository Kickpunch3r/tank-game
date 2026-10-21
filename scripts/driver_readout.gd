class_name DriverReadout
extends CanvasLayer
## Temporary corner readout of what the DriverStation is receiving.
## Becomes the start of the F3 debug display in milestone 6.

## The station to show.
@export var station: DriverStation

var _label: Label
var _reset_count: int = 0


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if station == null:
		return
	if station.reset_requested:
		_reset_count += 1
	# Rebuilt from the station's state every frame.
	_label.text = "Left tread:  %+.2f\nRight tread: %+.2f\nResets: %d" % [
		station.left_tread, station.right_tread, _reset_count]
