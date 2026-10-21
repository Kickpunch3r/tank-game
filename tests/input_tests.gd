class_name InputTests
extends RefCounted
## Checks the driver's controls by feeding fake key, stick and button events
## into Godot, then reading what the course tank's DriverStation received.

var runner: TestRunner
var tank: Tank
var station: DriverStation
var keyboard: KeyboardDriverInput


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func run() -> void:
	var report: TestReport = runner.report
	report.heading("Driver input")
	tank = runner.course.get_node(^"PlayerRig/Tank")
	station = tank.driver_station
	keyboard = station.get_node(^"KeyboardDriverInput")

	# Tread levels (keyboard default).
	for i: int in 4:
		await _tap_key(KEY_W)
	for i: int in 3:
		await _tap_key(KEY_UP)
	report.check("W x4 -> left level stops at +3", keyboard.left_level == 3, "left level %d" % keyboard.left_level)
	report.check("Up x3 -> right level +3", keyboard.right_level == 3, "right level %d" % keyboard.right_level)
	report.check("Level +3 = full forward at the station",
			is_equal_approx(station.left_tread, 1.0) and is_equal_approx(station.right_tread, 1.0),
			"L %.2f R %.2f" % [station.left_tread, station.right_tread])
	await _set_key(KEY_SPACE, true)
	report.check("Holding Space brakes and sets both levels to 0",
			station.brake and keyboard.left_level == 0 and keyboard.right_level == 0)
	await _set_key(KEY_SPACE, false)
	report.check("Letting go of Space releases the brake", not station.brake)
	await _tap_key(KEY_W)
	await _tap_key(KEY_S)
	await _tap_key(KEY_S)
	await _tap_key(KEY_DOWN)
	await _tap_key(KEY_UP)
	await _tap_key(KEY_UP)
	report.check("Levels are 0.25 / 0.5 / 1 (left -1 = -0.25, right +1 = 0.25)",
			keyboard.left_level == -1 and is_equal_approx(station.left_tread, -0.25)
			and keyboard.right_level == 1 and is_equal_approx(station.right_tread, 0.25),
			"levels %d / %d, station L %.2f R %.2f" % [keyboard.left_level, keyboard.right_level, station.left_tread, station.right_tread])
	await _tap_key(KEY_S)
	await _tap_key(KEY_UP)
	report.check("Level 2 = 0.5 (left -2 = -0.5, right +2 = 0.5)",
			is_equal_approx(station.left_tread, -0.5) and is_equal_approx(station.right_tread, 0.5),
			"station L %.2f R %.2f" % [station.left_tread, station.right_tread])
	report.check("The keyboard's levels come from the shared list (TreadLevels)",
			TreadLevels.all_notches() == [-1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0])
	keyboard.clear_levels()

	# Reset.
	tank.global_position = Vector3(5.0, 0.5, 7.0)
	await _tap_key(KEY_R)
	report.check("R clears levels and puts tank back at the start",
			keyboard.left_level == 0 and tank.global_position.distance_to(Vector3(0.0, 1.0, 0.0)) < 0.1,
			"position %s" % tank.global_position)

	# Hold-to-drive mode.
	keyboard.use_tread_levels = false
	await _set_key(KEY_W, true)
	report.check("Levels off: holding W drives the left tread", is_equal_approx(station.left_tread, 1.0))
	await _set_key(KEY_W, false)
	report.check("Levels off: letting go of W stops asking", station.left_tread == 0.0)
	keyboard.use_tread_levels = true

	# Gamepad (simulated: no real gamepad has been tested).
	await _set_stick(JOY_AXIS_LEFT_Y, -0.6)
	await _set_stick(JOY_AXIS_RIGHT_Y, 1.0)
	report.check("Gamepad sticks drive the treads (simulated)",
			station.left_tread > 0.3 and station.left_tread < 0.7 and is_equal_approx(station.right_tread, -1.0),
			"L %.2f R %.2f" % [station.left_tread, station.right_tread])
	for i: int in 3:
		await _tap_key(KEY_W)
	report.check("Hardest push wins: keyboard +3 beats half stick", is_equal_approx(station.left_tread, 1.0))
	keyboard.clear_levels()
	await _set_stick(JOY_AXIS_LEFT_Y, 0.1)
	await _set_stick(JOY_AXIS_RIGHT_Y, -0.15)
	report.check("Small stick wobble inside the deadzone counts as 0",
			station.left_tread == 0.0 and station.right_tread == 0.0,
			"L %.3f R %.3f" % [station.left_tread, station.right_tread])
	await _set_stick(JOY_AXIS_LEFT_Y, 0.0)
	await _set_stick(JOY_AXIS_RIGHT_Y, 0.0)
	tank.global_position = Vector3(-4.0, 0.5, 3.0)
	await _set_button(JOY_BUTTON_BACK, true)
	await _set_button(JOY_BUTTON_BACK, false)
	report.check("Gamepad Back resets the tank (simulated)",
			tank.global_position.distance_to(Vector3(0.0, 1.0, 0.0)) < 0.1)

	# Tests write straight into the station.
	station.listen_to_input_sources = false
	station.left_tread = 0.7
	await runner.wait_physics_frames(2)
	report.check("Tests can write into the station directly", is_equal_approx(station.left_tread, 0.7))
	station.left_tread = 0.0
	station.listen_to_input_sources = true


func _tap_key(code: Key) -> void:
	await _set_key(code, true)
	await _set_key(code, false)


func _set_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	await _send(event)


func _set_stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	await _send(event)


func _set_button(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = down
	await _send(event)


## Send the event, then wait so the station and tank have seen it.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await runner.wait_physics_frames(2)
