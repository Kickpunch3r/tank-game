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
	var tank: Tank = course.get_node(^"Tank")
	var chase: ChaseCamera = course.get_node(^"ChaseCamera")
	var slit: DriverSlitCamera = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	var hud: DebugHud = course.get_node(^"DebugHud")

	report.check("Starts in the chase view, no slit mask", chase.current and not slit.is_slit_visible())
	await _tap_key(KEY_V)
	report.check("V switches to the driver's slit, mask showing", slit.current and slit.is_slit_visible())
	await _tap_key(KEY_V)
	report.check("V again switches back to the chase view", chase.current and not slit.is_slit_visible())

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

	report.check("Debug display shows at the start", hud.visible)
	await _tap_key(KEY_F3)
	report.check("F3 hides the debug display", not hud.visible)
	await _tap_key(KEY_F3)
	report.check("F3 again shows it", hud.visible)


func _tap_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await runner.wait_physics_frames(2)
