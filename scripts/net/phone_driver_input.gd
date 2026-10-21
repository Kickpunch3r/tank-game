class_name PhoneDriverInput
extends DriverInputSource
## Tread values from a driver phone (via the ControllerServer), as one more
## input source on the DriverStation.
##
## While the driver phone is live (sent input in the last 0.25 s), it takes
## over: keyboard and gamepad are ignored. If it goes quiet, it reports 0 and
## stops taking over, so the keyboard and gamepad work again.

var _server: ControllerServer


func get_left_tread() -> float:
	var server: ControllerServer = _find_server()
	return server.driver_left() if server != null else 0.0


func get_right_tread() -> float:
	var server: ControllerServer = _find_server()
	return server.driver_right() if server != null else 0.0


func takes_over() -> bool:
	var server: ControllerServer = _find_server()
	return server != null and server.is_driver_live()


func _find_server() -> ControllerServer:
	if not is_instance_valid(_server):
		_server = get_tree().get_first_node_in_group(ControllerServer.GROUP) as ControllerServer
	return _server
