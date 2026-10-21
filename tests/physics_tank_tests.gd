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
	await _slope_tests()
	await _ledge_steps_and_crest()
	await _stability_tests()
	await _preset_tests()


# --- Swapping tanks (T) ---------------------------------------------------------

## On the course's own player rig, so this runs early (before the driving
## tests remove the course's tank).
func run_swap() -> void:
	report.heading("Swapping tanks (T)")
	var course: Node3D = runner.course
	var rig: PlayerRig = course.get_node(^"PlayerRig")
	var kinematic: Tank = course.get_node(^"PlayerRig/Tank")
	var physics: PhysicsTank = course.get_node(^"PlayerRig/PhysicsTank")
	var chase: ChaseCamera = course.get_node(^"PlayerRig/ChaseCamera")
	var hud: DebugHud = course.get_node(^"PlayerRig/DebugHud")
	var panel: TuningPanel = course.get_node(^"PlayerRig/TuningPanel")
	var views: ViewSwitcher = course.get_node(^"PlayerRig/ViewSwitcher")
	var kinematic_keys: KeyboardDriverInput = kinematic.get_node(^"DriverStation/KeyboardDriverInput")
	var physics_keys: KeyboardDriverInput = physics.get_node(^"DriverStation/KeyboardDriverInput")
	runner.watch_tank(kinematic)

	report.check("The kinematic tank starts active; the physics tank is hidden and switched off",
			rig.active_tank == kinematic and not physics.visible
			and physics.process_mode == Node.PROCESS_MODE_DISABLED)
	kinematic.place_at(Transform3D(Basis(Vector3.UP, 0.6), Vector3(10.0, 0.05, 20.0)))
	await runner.wait_physics_frames(20)
	await _tap_key(KEY_W)
	report.check("The hidden tank doesn't react to the keys", kinematic_keys.left_level == 1 and physics_keys.left_level == 0)
	var kinematic_place: Vector3 = kinematic.global_position
	await _tap_key(KEY_T)
	var heading_gap: float = rad_to_deg(absf(_flat(-physics.global_basis.z).signed_angle_to(_flat(-kinematic.global_basis.z), Vector3.UP)))
	var place_gap: float = Vector2(physics.global_position.x - kinematic_place.x, physics.global_position.z - kinematic_place.z).length()
	report.check("T: the physics tank appears where the kinematic tank was, facing the same way",
			rig.active_tank == physics and physics.visible and not kinematic.visible
			and kinematic.process_mode == Node.PROCESS_MODE_DISABLED
			and place_gap < 0.5 and heading_gap < 2.0,
			"%.2f m away, heading %.1f° off" % [place_gap, heading_gap])
	report.check("...and the keyboard levers stay where they were (level 1 on the left)", physics_keys.left_level == 1)
	await runner.wait_physics_frames(2)
	var hud_text: String = (hud.get_child(0) as Label).text
	report.check("Camera, HUD and Tab panel follow the physics tank",
			chase.target == physics and hud.tank == physics and panel.tank == physics
			and hud_text.contains("Tank: PHYSICS") and not panel.controls_for(&"base_mass").is_empty())
	var probe_rows: int = 0
	for line: String in hud_text.split("\n"):
		if line.begins_with("   L ") and line.contains(" R "):
			probe_rows += 1
	report.check("Physics HUD: 8 probes (touching, spring squash), pitch and roll, grip per tread",
			probe_rows == 4 and hud_text.contains("Hull pitch") and hud_text.contains("roll")
			and hud_text.contains("grip ok") and hud_text.contains("%"), "%d probe rows" % probe_rows)
	await _tap_key(KEY_V)
	var physics_slit: DriverSlitCamera = physics.get_node(^"Visual/Hull/DriverSlitCamera")
	report.check("V shows the physics tank's slit view", physics_slit.current and physics_slit.is_slit_visible())
	await _tap_key(KEY_V)
	var phone_source: PhoneDriverInput = physics.get_node(^"DriverStation/PhoneDriverInput")
	report.check("The physics tank's phone input finds the phone server", phone_source._find_server() != null)
	await _tap_key(KEY_1)
	var heavy: TankFeel = load("res://tuning/presets/heavy.tres")
	report.check("Presets set the knobs on both tanks (key 1: heavy)",
			heavy.matches(physics.tuning) and heavy.matches(kinematic.tuning))
	panel._on_reset_to_saved_pressed()
	# Panel's Reset to saved only resets the shown tank's values; the hidden
	# tank's knobs go back too.
	report.check("Reset to saved puts the knobs back (both tanks)",
			not heavy.matches(physics.tuning) and not heavy.matches(kinematic.tuning),
			"physics weight %.2f, kinematic weight %.2f" % [physics.tuning.weight, kinematic.tuning.weight])
	physics_keys.clear_levels()
	physics.place_at(Transform3D(Basis.IDENTITY, Vector3(-30.0, 0.5, 15.0)))
	await runner.wait_physics_frames(10)
	await _tap_key(KEY_R)
	report.check("R puts the active (physics) tank back at the start",
			Vector2(physics.global_position.x, physics.global_position.z).length() < 0.3,
			"at %s" % physics.global_position)
	await _tap_key(KEY_T)
	report.check("T again swaps back to the kinematic tank", rig.active_tank == kinematic and kinematic.visible
			and not physics.visible and hud.tank == kinematic)
	kinematic_keys.clear_levels()
	await _tap_key(KEY_R)


func _tap_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await runner.wait_physics_frames(2)


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


# --- Slopes -------------------------------------------------------------------

## How many times each slope test runs; the majority result counts.
const SLOPE_RUNS: int = 3


func _slope_tests() -> void:
	var ladder: SlopeLadder = runner.course.get_node(^"SlopeLadder")
	var driving := DrivingTests.new(runner)
	var kinematic_standing: Array[Dictionary] = await driving.climb_all(ladder, false)
	var kinematic_run_up: Array[Dictionary] = await driving.climb_all(ladder, true)
	var standing: Array[Dictionary] = await climb_all_majority(ladder, false)
	var run_up: Array[Dictionary] = await climb_all_majority(ladder, true)

	report.heading("Physics tank: Slope Ladder (full forward, %d runs each, majority result)" % SLOPE_RUNS)
	report.add_line("       Ramp            Physics: standing     Physics: run-up       Kinematic: standing   Kinematic: run-up")
	var steep_always_fail: bool = true
	for index: int in ladder.ramps.size():
		var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
		report.add_line("       %2d° %-8s   %-20s  %-20s  %-20s  %s" % [
				roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge",
				_describe(standing[index]), _describe(run_up[index]),
				driving._describe(kinematic_standing[index]), driving._describe(kinematic_run_up[index])])
		if ramp.angle_degrees >= 44.0 and (standing[index].any_climbed or run_up[index].any_climbed):
			steep_always_fail = false
	report.check("Physics tank: 45° and 55° always fail (every run, standing and run-up)", steep_always_fail)
	var ordering_ok: bool = true
	for results: Array[Dictionary] in [standing, run_up]:
		for a: int in ladder.ramps.size():
			for b: int in ladder.ramps.size():
				if ladder.ramps[b].angle_degrees > ladder.ramps[a].angle_degrees \
						and results[b].climbed and not results[a].climbed:
					ordering_ok = false
	report.check("Physics tank: steeper ramps are never easier", ordering_ok)
	var gentle_ok: bool = true
	for index: int in ladder.ramps.size():
		if ladder.ramps[index].angle_degrees <= 25.0 and not (standing[index].climbed and run_up[index].climbed):
			gentle_ok = false
	report.check("Physics tank: climbs every ramp up to 25°, standing and with a run-up", gentle_ok)


## Climbs every ramp SLOPE_RUNS times; per ramp: climbed (majority),
## any_climbed, seconds (middle of the climbing runs), best_height (highest).
func climb_all_majority(ladder: SlopeLadder, with_run_up: bool, tuning: PhysicsTankTuning = null) -> Array[Dictionary]:
	var runs: Array = []
	for run: int in SLOPE_RUNS:
		runs.append(await climb_all(ladder, with_run_up, tuning))
	var results: Array[Dictionary] = []
	for index: int in ladder.ramps.size():
		var climbs: int = 0
		var times: Array[float] = []
		var best: float = 0.0
		for run: Array in runs:
			var result: Dictionary = run[index]
			best = maxf(best, result.best_height)
			if result.climbed:
				climbs += 1
				times.append(result.seconds)
		times.sort()
		results.append({"climbed": climbs * 2 > SLOPE_RUNS, "any_climbed": climbs > 0, "climbs": climbs,
				"seconds": times[times.size() / 2] if not times.is_empty() else 0.0, "best_height": best})
	return results


## One physics tank at every ramp at once, full forward, like DrivingTests.climb_all().
func climb_all(ladder: SlopeLadder, with_run_up: bool, tuning: PhysicsTankTuning = null) -> Array[Dictionary]:
	var tanks: Array[PhysicsTank] = []
	var results: Array[Dictionary] = []
	for index: int in ladder.ramps.size():
		var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
		var tank: PhysicsTank = runner.spawn_test_physics_tank(ramp.run_up_start + Vector3(0.0, 0.1, 0.0))
		if not with_run_up:
			# Standing start: at rest, front probes at the foot of the slope.
			tank.place_at(Transform3D(Basis.IDENTITY, ladder.start_position_for(index, 0.0, tank)))
		if tuning != null:
			tank.tuning = tuning
		tanks.append(tank)
		results.append({"climbed": false, "seconds": 0.0, "best_height": 0.0})
	runner.watch_tank(tanks[tanks.size() / 2])
	for tank: PhysicsTank in tanks:
		tank.driver_station.brake = true
	await runner.wait_physics_frames(90)
	for tank: PhysicsTank in tanks:
		tank.driver_station.brake = false
	for frame: int in roundi(DrivingTests.CLIMB_TIME_LIMIT * FPS):
		for tank: PhysicsTank in tanks:
			tank.driver_station.left_tread = 1.0
			tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		for index: int in tanks.size():
			var result: Dictionary = results[index]
			if result.climbed:
				continue
			var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
			var where: Vector3 = tanks[index].global_position
			var rise: float = ramp.top_position.y - ramp.base_position.y
			result.best_height = maxf(result.best_height, clampf(where.y / rise, 0.0, 1.0))
			if where.z < ramp.top_position.z and where.y > ramp.top_position.y - 1.0:
				result.climbed = true
				result.seconds = (frame + 1) / float(FPS)
	await runner.remove_test_tanks()
	return results


func _describe(result: Dictionary) -> String:
	if result.climbed:
		var text: String = "climbs in %.1f s" % result.seconds
		return text if result.climbs == SLOPE_RUNS else text + " (%d/%d)" % [result.climbs, SLOPE_RUNS]
	if result.any_climbed:
		return "fails (%d/%d climbed)" % [result.climbs, SLOPE_RUNS]
	return "fails (got %d%% up)" % roundi(result.best_height * 100.0)


# --- Ledge strip, steps and crest ---------------------------------------------------

func _ledge_steps_and_crest() -> void:
	report.heading("Physics tank: ledge strip, steps and crest")
	var features: ComparisonFeatures = runner.course.get_node(^"ComparisonFeatures")
	# Middle of the tank 0.5 m inside the edge: the right tread's outer probes hang over.
	var tank: PhysicsTank = runner.spawn_test_physics_tank(features.ledge_edge_transform(-0.5).origin)
	runner.watch_tank(tank)
	tank.driver_station.brake = true
	await runner.wait_physics_frames(2 * FPS)
	var standing_roll: float = tank.roll_degrees()
	var hanging: int = 0
	for index: int in PhysicsTank.PROBE_COUNT:
		if not tank.probe_grounded[index]:
			hanging += 1
	tank.driver_station.brake = false
	var most_roll: float = absf(standing_roll)
	var broken: bool = false
	for frame: int in 4 * FPS:
		tank.driver_station.left_tread = 0.5
		tank.driver_station.right_tread = 0.5
		await runner.get_tree().physics_frame
		most_roll = maxf(most_roll, absf(tank.roll_degrees()))
		broken = broken or not tank.global_position.is_finite() or tank.global_position.y < -2.0
	report.check("Ledge strip, one tread over the edge: the tank leans over the drop",
			standing_roll > 3.0 and hanging > 0 and not broken,
			"%d probes over the edge, leaning %.1f° standing, up to %.1f° driving along; no NaN, didn't fall through" % [
				hanging, standing_roll, most_roll])
	await runner.remove_test_tanks()

	for point: Dictionary in features.reset_points().slice(1):
		var drive: Dictionary = await _drive_lane(point.transform)
		report.check("%s at half speed: over it without flipping" % point.name,
				drive.travelled > 50.0 and drive.most_tilt < 45.0 and drive.finite,
				"travelled %.0f m, pitch %.1f° to %.1f°, highest %.2f m" % [
					drive.travelled, drive.lowest_pitch, drive.highest_pitch, drive.highest])


## Drives a physics tank at half speed from `start` toward -Z for 15 s.
func _drive_lane(start: Transform3D) -> Dictionary:
	var tank: PhysicsTank = runner.spawn_test_physics_tank(start.origin)
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	var result: Dictionary = {"lowest_pitch": 0.0, "highest_pitch": 0.0, "highest": 0.0, "most_tilt": 0.0, "finite": true}
	for frame: int in 15 * FPS:
		tank.driver_station.left_tread = 0.5
		tank.driver_station.right_tread = 0.5
		await runner.get_tree().physics_frame
		result.lowest_pitch = minf(result.lowest_pitch, tank.pitch_degrees())
		result.highest_pitch = maxf(result.highest_pitch, tank.pitch_degrees())
		result.highest = maxf(result.highest, tank.global_position.y)
		result.most_tilt = maxf(result.most_tilt, rad_to_deg(tank.global_basis.y.angle_to(Vector3.UP)))
		result.finite = result.finite and tank.global_position.is_finite()
	result.travelled = start.origin.z - tank.global_position.z
	await runner.remove_test_tanks()
	return result


# --- Stability -------------------------------------------------------------------

func _stability_tests() -> void:
	report.heading("Physics tank: stability")
	# Full speed on flat ground, then throw it into a spin.
	var tank: PhysicsTank = runner.spawn_test_physics_tank(FLAT_AREA + Vector3(0.0, 0.0, -30.0), PI)
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	var most_tilt: float = 0.0
	for frame: int in 6 * FPS:
		var spinning: bool = frame >= 3 * FPS
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = -1.0 if spinning else 1.0
		await runner.get_tree().physics_frame
		most_tilt = maxf(most_tilt, rad_to_deg(tank.global_basis.y.angle_to(Vector3.UP)))
	report.check("Flat ground: full speed, then opposite levers: doesn't flip",
			most_tilt < 20.0 and tank.global_position.is_finite(), "most tilt %.1f°" % most_tilt)
	await runner.remove_test_tanks()

	# Full speed across the rolling bumps.
	var bumps: RollingBumps = runner.course.get_node(^"RollingBumps")
	tank = runner.spawn_test_physics_tank(bumps.global_position + Vector3(0.0, 0.5, bumps.patch_size / 2.0 + 10.0))
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	most_tilt = 0.0
	var highest_hop: float = 0.0
	for frame: int in 8 * FPS:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		most_tilt = maxf(most_tilt, rad_to_deg(tank.global_basis.y.angle_to(Vector3.UP)))
	var crossed: float = bumps.global_position.z + bumps.patch_size / 2.0 + 10.0 - tank.global_position.z
	report.check("Gentle bumps at full speed: drives across without flipping",
			most_tilt < 45.0 and crossed > 60.0 and tank.global_position.is_finite(),
			"crossed %.0f m, most tilt %.1f°" % [crossed, most_tilt])
	await runner.remove_test_tanks()


# --- Presets ------------------------------------------------------------------------

func _preset_tests() -> void:
	report.heading("Physics tank: presets (one run each, information)")
	var ladder: SlopeLadder = runner.course.get_node(^"SlopeLadder")
	var names: Array[String] = []
	var tables: Array[Array] = []
	var spins_ok: bool = true
	var spin_details: PackedStringArray = []
	for preset_name: String in ["heavy", "nimble", "slippery"]:
		var preset: TankFeel = load("res://tuning/presets/%s.tres" % preset_name)
		var tuning: PhysicsTankTuning = (load("res://tuning/physics_tank_tuning.tres") as PhysicsTankTuning).duplicate()
		preset.apply_to(tuning)
		names.append(preset.display_name)
		tables.append([await climb_all(ladder, false, tuning), await climb_all(ladder, true, tuning)])
		var tilt: float = await _spin_at_speed(tuning)
		spins_ok = spins_ok and tilt < 30.0
		spin_details.append("%s %.1f°" % [preset.display_name, tilt])
	var header: String = "       Ramp        "
	for preset_name: String in names:
		header += "%-26s" % preset_name
	report.add_line(header)
	for index: int in ladder.ramps.size():
		var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
		var line: String = "       %2d° %-8s " % [roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge"]
		for table: Array in tables:
			line += "%-26s" % ("%s / %s" % [_short(table[0][index]), _short(table[1][index])])
		report.add_line(line)
	report.check("Every preset: full speed into a spin on flat ground doesn't flip", spins_ok,
			"most tilt: %s" % ", ".join(spin_details))


## Full speed for 3 s, then opposite levers for 3 s. Returns the most tilt in degrees.
func _spin_at_speed(tuning: PhysicsTankTuning) -> float:
	var tank: PhysicsTank = runner.spawn_test_physics_tank(FLAT_AREA + Vector3(0.0, 0.0, -30.0), PI)
	tank.tuning = tuning
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	var most_tilt: float = 0.0
	for frame: int in 6 * FPS:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = -1.0 if frame >= 3 * FPS else 1.0
		await runner.get_tree().physics_frame
		most_tilt = maxf(most_tilt, rad_to_deg(tank.global_basis.y.angle_to(Vector3.UP)))
	await runner.remove_test_tanks()
	return most_tilt


func _short(result: Dictionary) -> String:
	if result.climbed:
		return "%.1f s" % result.seconds
	return "fail %d%%" % roundi(result.best_height * 100.0)
