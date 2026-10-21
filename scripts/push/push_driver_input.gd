class_name PushDriverInput
extends DriverInputSource
## The Ableton Push 3's levers and brake (via the PushController in the player
## rig), as one more input source on a tank's DriverStation. Like the
## keyboard: for each tread the hardest push of all sources wins, and the
## brake counts from any source.

var _controller: PushController


func get_left_tread() -> float:
	var controller: PushController = _find_controller()
	return controller.left_tread() if controller != null else 0.0


func get_right_tread() -> float:
	var controller: PushController = _find_controller()
	return controller.right_tread() if controller != null else 0.0


func is_brake_held() -> bool:
	var controller: PushController = _find_controller()
	return controller != null and controller.is_brake_held()


func _find_controller() -> PushController:
	if not is_instance_valid(_controller):
		_controller = get_tree().get_first_node_in_group(PushController.GROUP) as PushController
	return _controller
