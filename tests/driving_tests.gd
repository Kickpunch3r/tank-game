class_name DrivingTests
extends RefCounted
## Drives test tanks on flat ground and up every ramp, by writing straight into
## their DriverStations, and checks the results against the climbing targets.

## Open flat ground, away from the ramps and bumps.
const FLAT_AREA := Vector3(-100.0, 0.5, 60.0)
## Longest a ramp attempt may take, in seconds.
const CLIMB_TIME_LIMIT: float = 15.0
## Physics frames per second (Godot's default).
const FPS: int = 60

var runner: TestRunner
var report: TestReport


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	# The course's own tank is only needed for the input tests.
	var course_tank: Tank = runner.course.get_node(^"Tank")
	course_tank.queue_free()
	await _flat_tests()
	await _kill_plane_test()
	await _ramp_tests()


# --- Flat ground ---------------------------------------------------------

func _flat_tests() -> void:
	report.heading("Flat ground")

	var result: Dictionary = await _drive_on_flat(1.0, 1.0, 5.0)
	report.check("Both treads forward 5 s: goes roughly straight",
			result.distance > 30.0 and absf(result.sideways) < 0.5 and absf(result.turned) < 1.0,
			"%.1f m forward, %.2f m sideways, turned %.1f°" % [result.distance, result.sideways, result.turned])

	result = await _drive_on_flat(1.0, 0.0, 1.5)
	report.check("Left tread only: turns right", result.turned < -5.0,
			"turned %.1f° (negative = right)" % result.turned)

	result = await _drive_on_flat(1.0, -1.0, 3.0)
	report.check("Opposite treads: spins with little travel",
			absf(result.turned) > 90.0 and result.distance < 0.5,
			"turned %.0f°, moved %.2f m" % [result.turned, result.distance])


## Drives one fresh tank on flat ground and measures what happened.
## turned: degrees, positive = left. sideways: metres to the tank's right.
func _drive_on_flat(left: float, right: float, seconds: float) -> Dictionary:
	var tank: Tank = runner.spawn_test_tank(FLAT_AREA)
	runner.watch_tank(tank)
	await runner.wait_physics_frames(30)
	var start: Vector3 = tank.global_position
	var start_forward: Vector3 = -tank.global_basis.z
	var turned: float = 0.0
	var previous_forward: Vector3 = start_forward
	for frame: int in roundi(seconds * FPS):
		tank.driver_station.left_tread = left
		tank.driver_station.right_tread = right
		await runner.get_tree().physics_frame
		var forward: Vector3 = -tank.global_basis.z
		turned += rad_to_deg(previous_forward.signed_angle_to(forward, Vector3.UP))
		previous_forward = forward
	var moved: Vector3 = tank.global_position - start
	var result: Dictionary = {
		"distance": Vector3(moved.x, 0.0, moved.z).length(),
		"sideways": moved.dot(start_forward.cross(Vector3.UP)),
		"turned": turned,
	}
	await runner.remove_test_tanks()
	return result


# --- Kill-plane ----------------------------------------------------------

func _kill_plane_test() -> void:
	report.heading("Kill-plane")
	var tank: Tank = runner.spawn_test_tank(FLAT_AREA)
	await runner.wait_physics_frames(30)
	var spawn: Vector3 = tank.global_position
	tank.global_position = Vector3(250.0, 5.0, 0.0)  # outside the walls, over nothing
	var came_back: bool = false
	for frame: int in 5 * FPS:
		await runner.get_tree().physics_frame
		if tank.global_position.distance_to(spawn) < 0.5:
			came_back = true
			break
	report.check("Falling off the world sends the tank back to its start", came_back)
	await runner.remove_test_tanks()


# --- Ramps ---------------------------------------------------------------

func _ramp_tests() -> void:
	var ladder: SlopeLadder = runner.course.get_node(^"SlopeLadder")
	var standing: Array[Dictionary] = await _climb_all(ladder, false)
	var run_up: Array[Dictionary] = await _climb_all(ladder, true)

	report.heading("Slope Ladder (full forward, up to %d s each)" % CLIMB_TIME_LIMIT)
	report.add_line("       Ramp            Standing start        With run-up           Target (standing / run-up)")
	for index: int in ladder.ramps.size():
		var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
		var target: Array[String] = target_for(ramp.angle_degrees)
		var ok: bool = _meets(standing[index], target[0]) and _meets(run_up[index], target[1])
		report.check("%2d° %-8s   %-20s  %-20s  %s / %s" % [
				roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge",
				_describe(standing[index]), _describe(run_up[index]), target[0], target[1]], ok)


## Puts one tank at every ramp at once, drives them all at full forward, and
## records whether and when each reached the top of its slope.
func _climb_all(ladder: SlopeLadder, with_run_up: bool) -> Array[Dictionary]:
	var tanks: Array[Tank] = []
	var results: Array[Dictionary] = []
	for index: int in ladder.ramps.size():
		var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
		var start: Vector3 = ramp.run_up_start + Vector3(0.0, 0.05, 0.0)
		var tank: Tank = runner.spawn_test_tank(start)
		if not with_run_up:
			# Standing start: at rest, already touching the slope.
			tank.position = ladder.start_position(index, 0.0, tank.contact_radius())
			tank.set_spawn(tank.global_transform)
		tanks.append(tank)
		results.append({"climbed": false, "seconds": 0.0, "best_height": 0.0})
	runner.watch_tank(tanks[tanks.size() / 2])
	await runner.wait_physics_frames(30)

	for frame: int in roundi(CLIMB_TIME_LIMIT * FPS):
		for index: int in tanks.size():
			tanks[index].driver_station.left_tread = 1.0
			tanks[index].driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		for index: int in tanks.size():
			var result: Dictionary = results[index]
			if result.climbed:
				continue
			var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
			var where: Vector3 = tanks[index].global_position
			var rise: float = ramp.top_position.y - ramp.base_position.y
			result.best_height = maxf(result.best_height, clampf(where.y / rise, 0.0, 1.0))
			# Past the top edge of the slope, and up at that height.
			if where.z < ramp.top_position.z and where.y > ramp.top_position.y - 1.0:
				result.climbed = true
				result.seconds = (frame + 1) / float(FPS)
	await runner.remove_test_tanks()
	return results


## What each angle should do: [standing start, run-up]. "climbs", "fails" or "either".
static func target_for(angle_degrees: float) -> Array[String]:
	if angle_degrees <= 27.5:
		return ["climbs", "climbs"]
	if angle_degrees <= 37.5:
		return ["fails", "climbs"]
	if angle_degrees <= 42.5:
		return ["fails", "either"]
	return ["fails", "fails"]


func _meets(result: Dictionary, wanted: String) -> bool:
	match wanted:
		"climbs":
			return result.climbed
		"fails":
			return not result.climbed
	return true


func _describe(result: Dictionary) -> String:
	if result.climbed:
		return "climbs in %.1f s" % result.seconds
	return "fails (got %d%% up)" % roundi(result.best_height * 100.0)
