class_name KeyboardDriverInput
extends DriverInputSource
## Keyboard controls for the driver. Keys are set in Project Settings > Input Map:
## left tread W / S, right tread Up / Down arrows, brake Space (hold, action
## "driver_all_stop"), reset R.
##
## Two ways to drive, switched with `use_tread_levels`:
## - Levels (on): each press moves that tread one notch up or down (see
##   TreadLevels: 0.25, 0.5, 1 forward and the same back), and it stays there
##   when you let go, like a notched lever. Level 0 = engine idling: the tank
##   coasts. Holding Space brakes and sets both levels back to 0.
## - Hold (off): a tread drives only while its key is held.

## On: keys step the tread levels. Off: hold a key to drive.
@export var use_tread_levels: bool = true

## Current tread levels, from -3 to 3 (only used with levels on).
var left_level: int = 0
var right_level: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"driver_reset") or event.is_action_pressed(&"driver_all_stop"):
		clear_levels()
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
		return TreadLevels.value_for(left_level)
	return Input.get_axis(&"driver_left_back", &"driver_left_forward")


func get_right_tread() -> float:
	if use_tread_levels:
		return TreadLevels.value_for(right_level)
	return Input.get_axis(&"driver_right_back", &"driver_right_forward")


func is_brake_held() -> bool:
	return Input.is_action_pressed(&"driver_all_stop")


func is_reset_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"driver_reset")


## Both treads back to level 0.
func clear_levels() -> void:
	left_level = 0
	right_level = 0


func _step(level: int, direction: int) -> int:
	return clampi(level + direction, -TreadLevels.MAX_LEVEL, TreadLevels.MAX_LEVEL)
