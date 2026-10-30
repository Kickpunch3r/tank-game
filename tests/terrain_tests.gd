class_name TerrainTests
extends RefCounted
## Checks that terrain patches are found and change how the tank drives: mud
## and sand are slower, mud stops you quickly, one tread in mud pulls the tank
## toward it, soft ground sinks the hull, and terrain ramps keep the rule that
## steeper is never easier. Checks are about how terrains compare, not exact
## numbers, so they keep passing while the terrain values are being tuned.

var runner: TestRunner
var report: TestReport
var mud_patch: TerrainPatch
var sand_patch: TerrainPatch


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Terrain")
	mud_patch = runner.course.get_node(^"MudPatch")
	sand_patch = runner.course.get_node(^"SandPatch")
	var tree: SceneTree = runner.get_tree()

	report.check("Ground lookup finds mud, sand, and firm ground elsewhere",
			TerrainPatch.terrain_at(tree, mud_patch.global_position) == mud_patch.terrain
			and TerrainPatch.terrain_at(tree, sand_patch.global_position) == sand_patch.terrain
			and TerrainPatch.terrain_at(tree, Vector3(0.0, 0.0, 0.0)) == null)

	var firm: Dictionary = await _drive_and_stop(Vector3(0.0, 0.0, 35.0))
	var sand: Dictionary = await _drive_and_stop(sand_patch.global_position)
	var mud: Dictionary = await _drive_and_stop(mud_patch.global_position)
	report.check("Top speed: mud < sand < firm", mud.top < sand.top and sand.top < firm.top,
			"after 3 s: firm %.1f, sand %.1f, mud %.1f m/s" % [firm.top, sand.top, mud.top])
	report.check("Idling (lever at 0) stops sooner in mud than on firm ground", mud.stop < firm.stop,
			"from 4 m/s: firm %.2f s, mud %.2f s" % [firm.stop, mud.stop])
	report.check("Hull sinks in mud, more than in sand", mud.sink > sand.sink and sand.sink >= firm.sink,
			"hull lowered by firm %.2f, sand %.2f, mud %.2f m" % [firm.sink, sand.sink, mud.sink])

	var turned: float = await _one_tread_in_mud()
	report.check("Left tread in mud, right on firm ground: pulls left, toward the mud",
			turned > 3.0, "turned %.1f° (positive = left)" % turned)

	await _physics_tank_terrain()
	await _terrain_ramps()


## Drives full forward for 3 s from `where`, then lets go. Returns top speed,
## seconds to stop from 4 m/s with the lever at 0 (capped at 10 s), and how far the hull sank.
func _drive_and_stop(where: Vector3) -> Dictionary:
	var tank: Tank = runner.spawn_test_tank(where + Vector3(0.0, 0.05, 6.0))
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	var hull: Node3D = tank.get_node(^"Visual/Hull")
	var sink: float = -hull.position.y
	for frame: int in 180:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
	var top: float = tank.forward_speed
	# Bring every case to the same 4 m/s, then idle (lever at 0) and time the stop.
	tank.left_tread.speed = 4.0
	tank.right_tread.speed = 4.0
	var frames: int = 0
	while tank.forward_speed > 0.01 and frames < 600:
		tank.driver_station.left_tread = 0.0
		tank.driver_station.right_tread = 0.0
		await runner.get_tree().physics_frame
		frames += 1
	await runner.remove_test_tanks()
	return {"top": top, "stop": frames / float(DrivingTests.FPS), "sink": sink}


## Degrees turned in 1.5 s at full forward with only the left tread in mud.
func _one_tread_in_mud() -> float:
	# Just inside the patch's right-hand edge: left tread in mud, right tread out.
	var edge_x: float = mud_patch.global_position.x + mud_patch.size.x / 2.0
	var tank: Tank = runner.spawn_test_tank(Vector3(edge_x, 0.05, mud_patch.global_position.z + 8.0))
	runner.watch_tank(tank)
	await runner.wait_physics_frames(30)
	var turned: float = 0.0
	var previous: Vector3 = -tank.global_basis.z
	for frame: int in 90:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		var forward: Vector3 = -tank.global_basis.z
		turned += rad_to_deg(previous.signed_angle_to(forward, Vector3.UP))
		previous = forward
	await runner.remove_test_tanks()
	return turned


func _terrain_ramps() -> void:
	var ladder: SlopeLadder = runner.course.get_node(^"TerrainRamps")
	var driving := DrivingTests.new(runner)
	var standing: Array[Dictionary] = await driving.climb_all(ladder, false)
	var run_up: Array[Dictionary] = await driving.climb_all(ladder, true)

	report.add_line("")
	report.add_line("  Terrain ramps (information; values are being tuned)")
	report.add_line("       Ramp                  Standing start        With run-up")
	for index: int in ladder.ramps.size():
		var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
		report.add_line("       %2d° %-8s %-5s   %-20s  %s" % [
				roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge",
				ramp.terrain.display_name.to_lower(),
				driving._describe(standing[index]), driving._describe(run_up[index])])

	# Within each terrain, a steeper ramp must never be easier than a gentler one.
	var ordering_ok: bool = true
	for a: int in ladder.ramps.size():
		for b: int in ladder.ramps.size():
			var gentler: SlopeLadder.RampInfo = ladder.ramps[a]
			var steeper: SlopeLadder.RampInfo = ladder.ramps[b]
			if gentler.terrain != steeper.terrain or steeper.angle_degrees <= gentler.angle_degrees:
				continue
			for results: Array[Dictionary] in [standing, run_up]:
				if results[b].climbed and not results[a].climbed:
					ordering_ok = false
	report.check("Terrain ramps: steeper is never easier (same terrain)", ordering_ok)


# --- The physics tank on terrain -------------------------------------------------

func _physics_tank_terrain() -> void:
	var firm: Dictionary = await _physics_drive(Vector3(0.0, 0.1, 41.0))
	var sand: Dictionary = await _physics_drive(sand_patch.global_position + Vector3(0.0, 0.1, 6.0))
	var mud: Dictionary = await _physics_drive(mud_patch.global_position + Vector3(0.0, 0.1, 6.0))
	report.check("Physics tank: top speed mud < sand < firm", mud.top < sand.top and sand.top < firm.top,
			"after 3 s: firm %.1f, sand %.1f, mud %.1f m/s" % [firm.top, sand.top, mud.top])
	report.check("Physics tank: knows the ground under each tread",
			mud.ground == mud_patch.terrain and sand.ground == sand_patch.terrain and firm.ground == null)
	report.check("Physics tank: the hull picture sinks in mud, more than in sand",
			mud.sink > sand.sink and sand.sink > firm.sink + 0.05,
			"sank firm %.2f, sand %.2f, mud %.2f m" % [firm.sink, sand.sink, mud.sink])
	# Just inside the mud patch's right-hand edge: left tread in mud, right tread out.
	var edge_x: float = mud_patch.global_position.x + mud_patch.size.x / 2.0
	var tank: PhysicsTank = runner.spawn_test_physics_tank(Vector3(edge_x, 0.1, mud_patch.global_position.z + 8.0))
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	var start_forward: Vector3 = -tank.global_basis.z
	for frame: int in 2 * DrivingTests.FPS:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
	var forward: Vector3 = -tank.global_basis.z
	var turned: float = rad_to_deg(Vector3(start_forward.x, 0.0, start_forward.z).signed_angle_to(
			Vector3(forward.x, 0.0, forward.z), Vector3.UP))
	await runner.remove_test_tanks()
	report.check("Physics tank: left tread in mud, right on firm ground: pulls left, toward the mud",
			turned > 3.0, "turned %.1f° in 2 s (positive = left)" % turned)


## A physics tank (saved tuning) driven full forward for 3 s from `where`.
## Returns its speed, the ground under its left tread, and how far the hull sank.
func _physics_drive(where: Vector3) -> Dictionary:
	var tank: PhysicsTank = runner.spawn_test_physics_tank(where)
	runner.watch_tank(tank)
	await runner.wait_physics_frames(60)
	for frame: int in 3 * DrivingTests.FPS:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
	var result: Dictionary = {"top": tank.forward_speed, "ground": tank.left_terrain, "sink": tank.sink_depth()}
	await runner.remove_test_tanks()
	return result
