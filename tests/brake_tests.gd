class_name BrakeTests
extends RefCounted
## Checks the brake, idling at level 0 (idle drag), engine warm-up and turn
## scrub. Prints measured numbers so the feel can be compared while tuning.

const FLAT_AREA := Vector3(-100.0, 0.05, 60.0)
const FPS: int = 60

var runner: TestRunner
var report: TestReport


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Brake and idling (level 0)")
	var defaults := TankTuning.new()
	var idle_stop: float = await _seconds_to_stop(10.0, false)
	var want_idle: float = 10.0 / (defaults.idle_drag + defaults.rolling_resistance)
	report.check("Both levers at 0: the tank slows to a stop by itself (idle drag)",
			absf(idle_stop - want_idle) < 0.2, "%.2f s from 10 m/s (expected about %.1f s)" % [idle_stop, want_idle])
	var brake_stop: float = await _seconds_to_stop(10.0, true)
	report.check("Brake stops the tank from top speed in about 2 s", absf(brake_stop - 2.0) < 0.2,
			"%.2f s" % brake_stop)

	var held: float = await _slide_on_ramp(25.0, true)
	var rolled: float = await _slide_on_ramp(25.0, false)
	report.check("Brake holds the tank on a 25° slope", held < 0.2, "moved %.2f m in 3 s" % held)
	report.check("At level 0 the tank rolls back down a 25° slope (steeper than idle drag holds)",
			rolled > 2.0, "rolled %.1f m in 3 s" % rolled)

	report.heading("Engine warm-up")
	var instant: float = await _speed_after_straight(0.5, 0.0)
	var warming: float = await _speed_after_straight(0.5, 0.5)
	report.check("Warm-up 0.5 s: about half the speed after the first 0.5 s",
			absf(warming / instant - 0.5) < 0.1, "%.2f m/s with warm-up, %.2f without" % [warming, instant])
	var warmed_stop: float = await _seconds_to_stop(10.0, true, 0.5)
	report.check("Warm-up never delays the brake", absf(warmed_stop - brake_stop) < 0.05,
			"%.2f s with warm-up, %.2f without" % [warmed_stop, brake_stop])

	report.heading("Turning (turn scrub %.1f, idle drag %.1f)" % [defaults.turn_scrub, defaults.idle_drag])
	var straight: float = await _speed_after_straight(3.0, 0.0)
	report.check("Turn scrub never slows driving straight (reaches 10 m/s)", straight > 9.9, "%.2f m/s" % straight)

	var spin_free: Dictionary = await _drive(0.0, 0.0, 1.0, -1.0, 4.0)
	var spin: Dictionary = await _drive(0.0, defaults.turn_scrub, 1.0, -1.0, 4.0)
	report.check("Spinning on the spot is slow and heavy with turn scrub",
			spin.turn_rate < spin_free.turn_rate * 0.8,
			"%.0f°/s with scrub, %.0f°/s without" % [spin.turn_rate, spin_free.turn_rate])

	var pivot: Dictionary = await _drive(0.0, defaults.turn_scrub, 1.0, 0.0, 4.0)
	report.check("One tread powered, the other at 0: a slow pivot round the idle tread",
			pivot.turn_rate > 5.0 and pivot.turn_rate < 35.0 and pivot.left_speed < 8.0,
			"%.0f°/s, powered tread at %.1f m/s" % [pivot.turn_rate, pivot.left_speed])

	var at_speed_free: Dictionary = await _drive(10.0, 0.0, 1.0, 0.25, 2.0)
	var at_speed: Dictionary = await _drive(10.0, defaults.turn_scrub, 1.0, 0.25, 2.0)
	report.check("Hard turn at speed costs speed with turn scrub",
			at_speed.speed < at_speed_free.speed - 1.0,
			"after 2 s: %.1f m/s with scrub, %.1f without" % [at_speed.speed, at_speed_free.speed])

	var lever_zero: Dictionary = await _drive(10.0, defaults.turn_scrub, 1.0, 0.0, 2.0)
	report.check("At speed, one lever at 0 swings into a slow, heavy pivot (idle drag + scrub)",
			lever_zero.turned > 5.0 and lever_zero.speed < 8.0, "turned %.0f° in 2 s, %.1f m/s after" % [lever_zero.turned, lever_zero.speed])


## A test tank with its own copy of the tuning.
func _tank(where: Vector3, warm_up: float = 0.0, scrub: float = -1.0) -> Tank:
	var tank: Tank = runner.spawn_test_tank(where)
	tank.tuning = tank.tuning.duplicate()
	tank.tuning.warm_up_time = warm_up
	if scrub >= 0.0:
		tank.tuning.turn_scrub = scrub
	runner.watch_tank(tank)
	return tank


## From rest, both levers full for `seconds`; returns the speed.
func _speed_after_straight(seconds: float, warm_up: float) -> float:
	var tank: Tank = _tank(FLAT_AREA, warm_up)
	tank.driver_station.brake = true
	await runner.wait_physics_frames(20)
	tank.driver_station.brake = false
	for frame: int in roundi(seconds * FPS):
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
	var speed: float = tank.forward_speed
	await runner.remove_test_tanks()
	return speed


## From `start_speed`, levers at 0, with or without the brake: seconds to stop.
func _seconds_to_stop(start_speed: float, braking: bool, warm_up: float = 0.0) -> float:
	var tank: Tank = _tank(FLAT_AREA, warm_up)
	await runner.wait_physics_frames(20)
	tank.left_tread.speed = start_speed
	tank.right_tread.speed = start_speed
	tank.driver_station.brake = braking
	var frames: int = 0
	while tank.left_tread.speed > 0.01 and frames < 900:
		await runner.get_tree().physics_frame
		frames += 1
	await runner.remove_test_tanks()
	return frames / float(FPS)


## Distance moved in 3 s, resting mid-way up a ramp of `angle` with levers at 0.
func _slide_on_ramp(angle: float, braking: bool) -> float:
	var ladder: SlopeLadder = runner.course.get_node(^"SlopeLadder")
	var ramp: SlopeLadder.RampInfo = null
	for candidate: SlopeLadder.RampInfo in ladder.ramps:
		if is_equal_approx(candidate.angle_degrees, angle):
			ramp = candidate
	var tank: Tank = _tank(ramp.base_position.lerp(ramp.top_position, 0.5) + Vector3(0.0, 0.3, 0.0))
	tank.driver_station.brake = true
	await runner.wait_physics_frames(30)
	var start: Vector3 = tank.global_position
	tank.driver_station.brake = braking
	await runner.wait_physics_frames(3 * FPS)
	var moved: float = tank.global_position.distance_to(start)
	await runner.remove_test_tanks()
	return moved


## Start at `start_speed`, hold the levers for `seconds`. Returns the average
## turn rate over the last second (°/s), total degrees turned, final speed,
## and the left tread's final speed.
func _drive(start_speed: float, scrub: float, left: float, right: float, seconds: float) -> Dictionary:
	var tank: Tank = _tank(FLAT_AREA, 0.0, scrub)
	tank.driver_station.brake = true
	await runner.wait_physics_frames(20)
	tank.driver_station.brake = false
	tank.left_tread.speed = start_speed
	tank.right_tread.speed = start_speed
	var turned: float = 0.0
	var last_second: float = 0.0
	var previous: Vector3 = -tank.global_basis.z
	var frames: int = roundi(seconds * FPS)
	for frame: int in frames:
		tank.driver_station.left_tread = left
		tank.driver_station.right_tread = right
		await runner.get_tree().physics_frame
		var forward: Vector3 = -tank.global_basis.z
		var step: float = absf(rad_to_deg(previous.signed_angle_to(forward, Vector3.UP)))
		turned += step
		if frame >= frames - FPS:
			last_second += step
		previous = forward
	var result: Dictionary = {"turn_rate": last_second, "turned": turned,
			"speed": tank.forward_speed, "left_speed": tank.left_tread.speed}
	await runner.remove_test_tanks()
	return result
