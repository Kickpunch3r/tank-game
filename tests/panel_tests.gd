class_name PanelTests
extends RefCounted
## Checks the in-game tuning panel, the reset point setting, and the air and
## landing levers (air gravity, nose dip, landing speed loss).

## Open flat ground for drop tests, away from the ramps and bumps.
const DROP_AREA := Vector3(-100.0, 0.0, -20.0)

var runner: TestRunner
var report: TestReport


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Tuning panel")
	var course: Node3D = runner.course
	var panel: TuningPanel = course.get_node(^"TuningPanel")
	var tank: Tank = course.get_node(^"Tank")
	var ladder: SlopeLadder = course.get_node(^"SlopeLadder")

	report.check("Panel starts hidden", not panel.visible)
	await _tap_key(KEY_TAB)
	report.check("Tab opens the panel", panel.visible)
	await _tap_key(KEY_TAB)
	report.check("Tab again closes it", not panel.visible)

	panel.set_setting(&"max_tread_speed", 15.0)
	report.check("Moving a slider changes the tank's tuning", is_equal_approx(tank.tuning.max_tread_speed, 15.0))
	var slit: DriverSlitCamera = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	panel.set_setting(&"slit_height", 0.3)
	await runner.wait_physics_frames(2)
	var mask_top: ColorRect = slit.get_node(^"SlitOverlay/MaskTop")
	report.check("Slit height slider redraws the slit", is_equal_approx(mask_top.anchor_bottom, 0.35),
			"mask top ends at %.2f of the screen" % mask_top.anchor_bottom)
	var text: String = panel.values_text()
	report.check("Copy values text lists current numbers and where they go",
			text.contains("# tuning/tank_tuning.tres") and text.contains("max_tread_speed = 15.0")
			and text.contains("slit_height = 0.3"))
	panel._on_reset_to_saved_pressed()
	report.check("Reset to saved puts values back",
			is_equal_approx(tank.tuning.max_tread_speed, 10.0) and is_equal_approx(slit.slit_height, 0.18))

	# Reset point.
	var index_30: int = _ramp_index(ladder, 30.0)
	panel.choose_reset_point(index_30, 0.0)
	await _tap_key(KEY_R)
	var want: Vector3 = ladder.start_position(index_30, 0.0, tank.contact_radius())
	report.check("Reset point: R puts the tank touching the chosen ramp",
			tank.global_position.distance_to(want) < 0.2, "at %s, wanted %s" % [tank.global_position, want])
	panel.choose_reset_point(index_30, 20.0)
	await _tap_key(KEY_R)
	report.check("Reset point: distance moves the tank back from the ramp",
			absf(tank.global_position.z - (want.z + 20.0)) < 0.2, "z %.2f, wanted %.2f" % [tank.global_position.z, want.z + 20.0])
	panel.choose_reset_point(-1, 0.0)
	await _tap_key(KEY_R)
	report.check("Reset point: Start field puts the tank back at the start",
			tank.global_position.distance_to(Vector3(0.0, 1.0, 0.0)) < 0.2)

	await _air_and_landing_tests()
	await _engine_power_tests()


func _engine_power_tests() -> void:
	report.heading("Engine power")
	var full: Dictionary = await _speed_up_and_brake(1.0, 1.0)
	var faded: Dictionary = await _speed_up_and_brake(0.5, 0.3)
	report.check("Fade from half speed: same pull from a standstill",
			absf(faded.to_40 - full.to_40) < 0.05,
			"0 to 4 m/s: %.2f s without fade, %.2f s with" % [full.to_40, faded.to_40])
	report.check("Fade from half speed, 30% left: slower to near top speed",
			faded.to_95 > full.to_95 + 0.3,
			"0 to 9.5 m/s: %.2f s without fade, %.2f s with" % [full.to_95, faded.to_95])
	report.check("Braking is not affected by the fade",
			absf(faded.stop - full.stop) < 0.05,
			"stop from top speed: %.2f s without fade, %.2f s with" % [full.stop, faded.stop])


## Times to reach 40% and 95% of top speed from rest, and to stop again.
func _speed_up_and_brake(falloff_start: float, at_top: float) -> Dictionary:
	var tank: Tank = _tank_with_own_tuning(DROP_AREA + Vector3(0.0, 0.5, 0.0))
	tank.tuning.power_falloff_start = falloff_start
	tank.tuning.power_at_top_speed = at_top
	await runner.wait_physics_frames(30)
	var result: Dictionary = {"to_40": -1.0, "to_95": -1.0, "stop": -1.0}
	var top: float = tank.tuning.max_tread_speed
	var frames: int = 0
	while result.to_95 < 0.0 and frames < 1200:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		frames += 1
		if result.to_40 < 0.0 and tank.left_tread.speed >= 0.4 * top:
			result.to_40 = frames / float(DrivingTests.FPS)
		if tank.left_tread.speed >= 0.95 * top:
			result.to_95 = frames / float(DrivingTests.FPS)
	# Let it reach top speed, then let go and time the stop.
	await runner.wait_physics_frames(600)
	frames = 0
	while tank.left_tread.speed > 0.01 and frames < 600:
		tank.driver_station.left_tread = 0.0
		tank.driver_station.right_tread = 0.0
		await runner.get_tree().physics_frame
		frames += 1
	result.stop = frames / float(DrivingTests.FPS)
	await runner.remove_test_tanks()
	return result


func _air_and_landing_tests() -> void:
	report.heading("Air and landing levers")

	var normal_fall: float = await _fall_time(1.0)
	var floaty_fall: float = await _fall_time(0.5)
	report.check("Air gravity x0.5 gives more hang time (about 1.41x)",
			absf(floaty_fall / normal_fall - sqrt(2.0)) < 0.1,
			"20 m drop: %.2f s normal, %.2f s at x0.5" % [normal_fall, floaty_fall])

	var level_pitch: float = await _pitch_while_falling(0.0)
	var dipped_pitch: float = await _pitch_while_falling(1.0)
	report.check("Nose dip 0: hull stays level in the air", absf(level_pitch) < 2.0, "%.1f°" % level_pitch)
	report.check("Nose dip 1: nose points down along the fall", dipped_pitch < -20.0, "%.1f°" % dipped_pitch)

	var kept_none: float = await _speed_after_landing(0.0)
	var kept_half: float = await _speed_after_landing(0.5)
	report.check("Landing speed loss 0: no speed lost", kept_none > 7.9, "%.1f of 8.0 m/s" % kept_none)
	report.check("Landing speed loss 0.5: a 5 m drop costs about half",
			kept_half > 3.5 and kept_half < 4.8, "%.1f of 8.0 m/s" % kept_half)


## A tank with its own copy of the tuning, so changes don't leak into other tests.
func _tank_with_own_tuning(where: Vector3) -> Tank:
	var tank: Tank = runner.spawn_test_tank(where)
	tank.tuning = tank.tuning.duplicate()
	runner.watch_tank(tank)
	return tank


## Seconds to fall 20 m with the given air gravity multiplier.
func _fall_time(air_gravity_scale: float) -> float:
	var tank: Tank = _tank_with_own_tuning(DROP_AREA + Vector3(0.0, 20.0, 0.0))
	tank.tuning.air_gravity_scale = air_gravity_scale
	var frames: int = 0
	while not tank.is_on_floor() and frames < 600:
		await runner.get_tree().physics_frame
		frames += 1
	await runner.remove_test_tanks()
	return frames / float(DrivingTests.FPS)


## Hull pitch in degrees after flying forward and falling for one second.
func _pitch_while_falling(nose_dip: float) -> float:
	var tank: Tank = _tank_with_own_tuning(DROP_AREA + Vector3(0.0, 40.0, 0.0))
	tank.tuning.nose_dip = nose_dip
	tank.velocity = Vector3(0.0, 0.0, -10.0)
	await runner.wait_physics_frames(60)
	var hull: Node3D = tank.get_node(^"Visual/Hull")
	var nose: Vector3 = -hull.global_basis.z
	await runner.remove_test_tanks()
	return rad_to_deg(asin(clampf(nose.y, -1.0, 1.0)))


## Tread speed just after landing from a 5 m drop with both treads at 8 m/s.
func _speed_after_landing(landing_speed_loss: float) -> float:
	var tank: Tank = _tank_with_own_tuning(DROP_AREA + Vector3(0.0, 5.0, 0.0))
	tank.tuning.landing_speed_loss = landing_speed_loss
	tank.tuning.max_tread_speed = 8.0
	tank.driver_station.left_tread = 1.0
	tank.driver_station.right_tread = 1.0
	tank.left_tread.speed = 8.0
	tank.right_tread.speed = 8.0
	var frames: int = 0
	while not tank.is_on_floor() and frames < 300:
		await runner.get_tree().physics_frame
		frames += 1
	# The landing is handled in the next physics frame.
	await runner.get_tree().physics_frame
	var speed: float = tank.left_tread.speed
	await runner.remove_test_tanks()
	return speed


func _ramp_index(ladder: SlopeLadder, angle: float) -> int:
	for index: int in ladder.ramps.size():
		if is_equal_approx(ladder.ramps[index].angle_degrees, angle):
			return index
	return 0


func _tap_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await runner.wait_physics_frames(2)
