class_name KeyboardDriverInput
extends DriverInputSource
## Keyboard controls for the driver. Keys are set in Project Settings > Input Map:
## left tread W / S, right tread Up / Down arrows, reset R.


func get_left_tread() -> float:
	return Input.get_axis(&"driver_left_back", &"driver_left_forward")


func get_right_tread() -> float:
	return Input.get_axis(&"driver_right_back", &"driver_right_forward")


func is_reset_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"driver_reset")
