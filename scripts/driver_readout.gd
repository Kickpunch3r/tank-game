class_name DriverReadout
extends CanvasLayer
## Temporary corner readout of the driver's input and what the tank is doing.
## Becomes the start of the F3 debug display in milestone 6.

## The station to show.
@export var station: DriverStation

## The tank to show.
@export var tank: Tank

var _label: Label
var _reset_count: int = 0


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if station == null or tank == null:
		return
	if station.reset_requested:
		_reset_count += 1
	# Rebuilt from the station's and tank's state every frame.
	var lines: PackedStringArray = [
		"Left tread:  input %+.2f   speed %+5.1f m/s" % [station.left_tread, tank.left_tread.speed],
		"Right tread: input %+.2f   speed %+5.1f m/s" % [station.right_tread, tank.right_tread.speed],
		"Forward speed: %+5.1f m/s" % tank.forward_speed,
		"Slope: %+5.1f deg   On floor: %s" % [tank.slope_degrees, "yes" if tank.is_on_floor() else "no"],
		"Traction capped: %s" % ("YES" if tank.is_traction_capped() else "no"),
		"Resets: %d" % _reset_count,
	]
	_label.text = "\n".join(lines)
