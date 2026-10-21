class_name GamepadDriverInput
extends DriverInputSource
## Gamepad controls for the driver: left stick up/down = left tread,
## right stick up/down = right tread, Back/Select = reset.
## Uses any connected gamepad. The deadzone (how far the stick must move before
## it counts) is set per action in Project Settings > Input Map (0.2 by default).


func get_left_tread() -> float:
	return Input.get_axis(&"driver_left_back_pad", &"driver_left_forward_pad")


func get_right_tread() -> float:
	return Input.get_axis(&"driver_right_back_pad", &"driver_right_forward_pad")


func is_reset_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"driver_reset_pad")
