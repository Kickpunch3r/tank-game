class_name ViewTests
extends RefCounted
## Checks the camera views and the debug display: V switches between the chase
## camera and the driver's slit, the slit tilts with the hull, F3 hides the HUD.

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func run() -> void:
	var report: TestReport = runner.report
	report.heading("Views and debug display")
	var course: Node3D = runner.course
	var tank: Tank = course.get_node(^"PlayerRig/Tank")
	var chase: ChaseCamera = course.get_node(^"PlayerRig/ChaseCamera")
	var slit: DriverSlitCamera = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	var hud: DebugHud = course.get_node(^"PlayerRig/DebugHud")

	report.check("Starts in the driver's slit view (first person), mask showing", slit.current and slit.is_slit_visible())
	await _tap_key(KEY_V)
	report.check("V switches to the chase view, no slit mask", chase.current and not slit.is_slit_visible())
	await _tap_key(KEY_V)
	report.check("V again switches back to the driver's slit", slit.current and slit.is_slit_visible())

	var front_of_hull: bool = slit.position.z < -2.0 and slit.get_parent().name == "Hull"
	report.check("Slit camera sits at the front of the hull", front_of_hull, "local position %s" % slit.position)

	# Park the tank on the 20 degree ramp and let the hull settle.
	var ladder: SlopeLadder = course.get_node(^"SlopeLadder")
	var ramp_20: SlopeLadder.RampInfo = null
	for ramp: SlopeLadder.RampInfo in ladder.ramps:
		if is_equal_approx(ramp.angle_degrees, 20.0):
			ramp_20 = ramp
	if ramp_20 == null:
		report.check("Slit camera tilts with the hull (needs a 20° ramp)", false, "no 20° ramp in the list")
	else:
		var middle: Vector3 = ramp_20.base_position.lerp(ramp_20.top_position, 0.5)
		tank.global_position = middle + Vector3(0.0, 0.3, 0.0)
		await runner.wait_physics_frames(120)
		var pitch: float = rad_to_deg(slit.global_basis.y.angle_to(Vector3.UP))
		report.check("Slit camera tilts with the hull on a 20° ramp", absf(pitch - 20.0) < 1.0,
				"camera tilted %.1f°" % pitch)
		tank.reset_to_spawn()
		await runner.wait_physics_frames(30)

	await _throttle_display(tank)

	var phone_line: PhoneStatusLabel = course.get_node(^"PlayerRig/PhoneStatusLabel")
	report.check("Debug display starts hidden, and so does the phone line at the bottom left",
			not hud.visible and not phone_line.visible)
	await _tap_key(KEY_F3)
	report.check("F3 shows the debug display and the phone line", hud.visible and phone_line.visible)
	await _tap_key(KEY_F3)
	report.check("F3 again hides both", not hud.visible and not phone_line.visible)


func _tap_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await runner.wait_physics_frames(2)


## The throttle bars follow the levers, mark the top level as turbo, and show
## over the driver's slit too.
func _throttle_display(tank: Tank) -> void:
	var report: TestReport = runner.report
	var display: ThrottleDisplay = runner.course.get_node(^"PlayerRig/ThrottleDisplay")
	var keyboard: KeyboardDriverInput = tank.driver_station.get_node(^"KeyboardDriverInput")
	var slit: DriverSlitCamera = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	keyboard.clear_levels()
	for i: int in 3:
		await _tap_key(KEY_W)
	await _tap_key(KEY_DOWN)
	report.check("Throttle bars show each lever's level (left turbo = 3, right one back = -1)",
			display.levels() == Vector2i(3, -1), "levels %s" % display.levels())
	report.check("Throttle bars sit above the driver's slit mask, so they show in both views",
			display.visible and display.layer > (slit.get_node(^"SlitOverlay") as CanvasLayer).layer)
	var flashes: Array[float] = []
	for i: int in 12:
		flashes.append(display.turbo_flash_amount())
		await runner.get_tree().process_frame
	report.check("Engaged turbo flashes (its brightness keeps changing)",
			flashes.max() - flashes.min() > 0.3, "brightness from %.2f to %.2f" % [flashes.min(), flashes.max()])
	report.check("A lever between notches (a gamepad stick) shows the nearest notch",
			ThrottleDisplay.level_for(0.9) == 3 and ThrottleDisplay.level_for(-0.3) == -1 and ThrottleDisplay.level_for(0.05) == 0)
	keyboard.clear_levels()
	await runner.wait_physics_frames(2)
