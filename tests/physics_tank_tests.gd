class_name PhysicsTankTests
extends RefCounted
## Checks the physics tank: resting, flat driving, the same controls as the
## kinematic tank, slopes (each run 3 times, majority result), the ledge
## strip, steps and crest, and stability. Physics is less exactly repeatable
## than the kinematic tank, so checks use tolerances.

const FLAT_AREA := Vector3(-100.0, 0.1, 60.0)
const FPS: int = 60

var runner: TestRunner
var report: TestReport


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Physics tank: rest and flat ground")
	await _rest_test()
	await _flat_tests()
	await _controls_test()


# --- Rest -------------------------------------------------------------------

func _rest_test() -> void:
	var tank: PhysicsTank = runner.spawn_test_physics_tank(FLAT_AREA + Vector3(0.0, 0.3, 0.0))
	runner.watch_tank(tank)
	await runner.wait_physics_frames(2 * FPS)
	var settled: Vector3 = tank.global_position
	var most_bounce: float = 0.0
	var most_turn: float = 0.0
	for frame: int in FPS:
		await runner.get_tree().physics_frame
		most_bounce = maxf(most_bounce, tank.global_position.distance_to(settled))
		most_turn = maxf(most_turn, tank.angular_velocity.length())
	var sag: float = tank.probe_compression[0]
	report.check("Placed on flat ground, it settles within 2 s and stays still",
			most_bounce < 0.01 and most_turn < 0.01,
			"moved %.4f m in the next second; springs squashed %d%% (target %d%%)" % [
				most_bounce, roundi(sag * 100.0), roundi(tank.tuning.target_sag * 100.0)])
	await runner.remove_test_tanks()


# --- Flat driving -------------------------------------------------------------

func _flat_tests() -> void:
	var result: Dictionary = await drive_on_flat(true, 1.0, 1.0, 5.0)
	report.check("Both treads forward 5 s: goes roughly straight",
			result.distance > 30.0 and absf(result.sideways) < 0.5 and absf(result.turned) < 1.0,
			"%.1f m forward, %.2f m sideways, turned %.1f°" % [result.distance, result.sideways, result.turned])
	result = await drive_on_flat(true, 1.0, 0.0, 4.0)
	report.check("Left tread only: turns right", result.turned < -5.0,
			"turned %.1f° (negative = right), %.0f°/s by the end" % [result.turned, result.rate])
	result = await drive_on_flat(true, 1.0, -1.0, 4.0)
	report.check("Opposite treads: spins with little travel",
			absf(result.turned) > 90.0 and result.distance < 0.5,
			"turned %.0f°, %.0f°/s by the end, moved %.2f m" % [result.turned, result.rate, result.distance])


## Drives a fresh tank (physics or kinematic) on flat ground.
## turned: degrees, positive = left. sideways: metres to the tank's right.
## rate: degrees per second over the last second.
func drive_on_flat(physics: bool, left: float, right: float, seconds: float) -> Dictionary:
	var tank: Node3D
	if physics:
		tank = runner.spawn_test_physics_tank(FLAT_AREA)
	else:
		tank = runner.spawn_test_tank(FLAT_AREA)
	runner.watch_tank(tank)
	var station: DriverStation = tank.get(&"driver_station")
	station.brake = true
	await runner.wait_physics_frames(60)
	station.brake = false
	var start: Vector3 = tank.global_position
	var start_forward: Vector3 = _flat(-tank.global_basis.z)
	var turned: float = 0.0
	var rate: float = 0.0
	var previous: Vector3 = start_forward
	var frames: int = roundi(seconds * FPS)
	for frame: int in frames:
		station.left_tread = left
		station.right_tread = right
		await runner.get_tree().physics_frame
		var forward: Vector3 = _flat(-tank.global_basis.z)
		var step: float = rad_to_deg(previous.signed_angle_to(forward, Vector3.UP))
		turned += step
		if frame >= frames - FPS:
			rate += step
		previous = forward
	var moved: Vector3 = tank.global_position - start
	var result: Dictionary = {
		"distance": Vector3(moved.x, 0.0, moved.z).length(),
		"forward": moved.dot(start_forward),
		"sideways": moved.dot(start_forward.cross(Vector3.UP)),
		"turned": turned,
		"rate": absf(rate),
	}
	await runner.remove_test_tanks()
	return result


func _flat(direction: Vector3) -> Vector3:
	return Vector3(direction.x, 0.0, direction.z).normalized()


# --- Same controls for both tanks ------------------------------------------------

func _controls_test() -> void:
	var cases: Array = [["left only", 1.0, 0.0], ["right only", 0.0, 1.0],
			["both forward", 1.0, 1.0], ["opposite", 1.0, -1.0]]
	var all_same: bool = true
	var details: PackedStringArray = []
	for case: Array in cases:
		var kinematic: Dictionary = await drive_on_flat(false, case[1], case[2], 1.5)
		var physics: Dictionary = await drive_on_flat(true, case[1], case[2], 1.5)
		var same: bool = _sign(kinematic.forward, 0.3) == _sign(physics.forward, 0.3) \
				and _sign(kinematic.turned, 2.0) == _sign(physics.turned, 2.0)
		all_same = all_same and same
		details.append("%s: %s" % [case[0], "same" if same else "DIFFERENT (kinematic %.1f m %.0f°, physics %.1f m %.0f°)" % [
				kinematic.forward, kinematic.turned, physics.forward, physics.turned]])
	report.check("Same lever input moves and turns both tanks the same way", all_same, ", ".join(details))


## -1, 0 or 1, treating anything smaller than `dead` as 0.
func _sign(value: float, dead: float) -> int:
	if absf(value) < dead:
		return 0
	return 1 if value > 0.0 else -1
