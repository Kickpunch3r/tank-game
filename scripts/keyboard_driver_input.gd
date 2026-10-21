class_name KeyboardDriverInput
extends DriverInputSource
## Keyboard controls for the driver. Keys are set in Project Settings > Input Map:
## left tread W / S, right tread Up / Down arrows, all stop Space, reset R.
##
## Two ways to drive, switched with `use_tread_levels`:
## - Levels (on): each press moves that tread one level up or down, from -3 to +3,
##   and it stays there when you let go, like a throttle lever with notches.
##   Space sets both treads to 0. The treads still slow down gradually (inertia).
## - Hold (off): a tread drives only while its key is held.

## Highest tread level. Level MAX_LEVEL is full speed.
const MAX_LEVEL: int = 3

## On: keys step the tread levels. Off: hold a key to drive.
@export var use_tread_levels: bool = true

## Current tread levels, from -MAX_LEVEL to MAX_LEVEL (only used with levels on).
var left_level: int = 0
var right_level: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"driver_reset") or event.is_action_pressed(&"driver_all_stop"):
		left_level = 0
		right_level = 0
		return
	if not use_tread_levels:
		return
	if event.is_action_pressed(&"driver_left_forward"):
		left_level = _step(left_level, 1)
	elif event.is_action_pressed(&"driver_left_back"):
		left_level = _step(left_level, -1)
	elif event.is_action_pressed(&"driver_right_forward"):
		right_level = _step(right_level, 1)
	elif event.is_action_pressed(&"driver_right_back"):
		right_level = _step(right_level, -1)


func get_left_tread() -> float:
	if use_tread_levels:
		return float(left_level) / MAX_LEVEL
	return Input.get_axis(&"driver_left_back", &"driver_left_forward")


func get_right_tread() -> float:
	if use_tread_levels:
		return float(right_level) / MAX_LEVEL
	return Input.get_axis(&"driver_right_back", &"driver_right_forward")


func is_reset_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"driver_reset")


func _step(level: int, direction: int) -> int:
	return clampi(level + direction, -MAX_LEVEL, MAX_LEVEL)
