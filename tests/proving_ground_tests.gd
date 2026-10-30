class_name ProvingGroundTests
extends RefCounted
## Checks the Proving Ground level (the game's main scene): it starts with the
## physics tank at the spawn, the test area is flat and complete, the terrain
## map and river are where the plan says, the cliffs and steep hills can't be
## driven up, and both routes can be driven from the spawn to the goal.

const LEVEL: String = "res://levels/proving_ground/proving_ground.tscn"
const FPS: int = 60

var runner: TestRunner
var report: TestReport
var level: LevelRoot
var layout := ProvingGroundLayout.new()


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Proving Ground (main scene)")
	report.check("It is the game's main scene",
			ProjectSettings.get_setting("application/run/main_scene") == LEVEL)
	var height_image := load("res://levels/proving_ground/height.png") as Image
	var terrain_image := load("res://levels/proving_ground/terrain.png") as Image
	report.check("Its images are imported as Image, so an exported game can read them",
			height_image != null and terrain_image != null
			and height_image.get_size() == Vector2i(ProvingGroundLayout.WIDTH, ProvingGroundLayout.DEPTH))
	# Make room: the level is big and sits where the test course was.
	if is_instance_valid(runner.course):
		await runner.remove_test_tanks()
		runner.course.queue_free()
		await runner.wait_physics_frames(3)
	level = (load(LEVEL) as PackedScene).instantiate()
	runner.add_child(level)
	await runner.wait_physics_frames(120)
	_start_and_test_area()
	_terrain_and_water()
	_steepness()
	await _cliffs_stop_the_tank()
	await _routes()
	level.queue_free()
	await runner.wait_physics_frames(3)


func _start_and_test_area() -> void:
	var rig: PlayerRig = level.get_node(^"PlayerRig")
	var tank: Node3D = rig.active_tank
	var spawn := ProvingGroundLayout.SPAWN
	var facing: Vector3 = -tank.global_basis.z
	report.check("Starts with the physics tank at the spawn, on the ground, facing north",
			tank is PhysicsTank and Vector2(tank.global_position.x, tank.global_position.z).distance_to(spawn) < 1.0
			and absf(tank.global_position.y - _ground(spawn)) < 0.2 and facing.z < -0.95,
			"at %s" % tank.global_position)
	var ladder: SlopeLadder = level.get_node(^"SlopeLadder")
	var flat: bool = true
	for ramp: SlopeLadder.RampInfo in ladder.ramps:
		for offset: float in [3.0, 20.0, ProvingGroundLayout.RAMPS_RUN_UP]:
			var spot := Vector2(ramp.base_position.x, ramp.base_position.z + offset)
			flat = flat and absf(_ground(spot) - ProvingGroundLayout.BASE) < 0.05
	var features: ComparisonFeatures = level.get_node(^"ComparisonFeatures")
	for point: Dictionary in features.reset_points():
		var start: Vector3 = (point.transform as Transform3D).origin
		flat = flat and absf(_ground(Vector2(start.x, start.z)) - ProvingGroundLayout.BASE) < 0.05
	report.check("Test area beside the spawn: 10 ramps and the ledge strip, steps and crest, on flat ground",
			ladder.ramps.size() == 10 and flat and ladder.ramps[0].base_position.x - spawn.x < 80.0,
			"nearest ramp %.0f m east of the spawn" % (ladder.ramps[0].base_position.x - spawn.x))
	var labels_3d: Array[Node] = level.find_children("*", "Label3D", true, false)
	var shown: int = 0
	for label: Node in labels_3d:
		if (label as Label3D).is_visible_in_tree():
			shown += 1
	report.check("Route markers are built, and no floating text shows (test labels start hidden)",
			level.get_node(^"RouteMarkers").get_child_count() > 40 and shown == 0 and not labels_3d.is_empty(),
			"%d labels, %d showing" % [labels_3d.size(), shown])
	var cube: Node3D = level.get_node(^"GoalCube")
	var goal := ProvingGroundLayout.GOAL
	report.check("A gold cube floats above the goal",
			cube is ObjectiveMarker and Vector2(cube.global_position.x, cube.global_position.z).distance_to(goal) < 1.0
			and cube.global_position.y > ProvingGroundLayout.GOAL_HEIGHT + 3.0,
			"at %s" % cube.global_position)


func _terrain_and_water() -> void:
	var mud: TerrainType = load("res://terrain/mud.tres")
	var sand: TerrainType = load("res://terrain/sand.tres")
	var checks: Array = [
		["test area mud square", ProvingGroundLayout.TEST_MUD, mud],
		["test area sand square", ProvingGroundLayout.TEST_SAND, sand],
		["mud basin (low route)", ProvingGroundLayout.MUD_BASIN, mud],
		["the ford", ProvingGroundLayout.FORD, mud],
		["dunes (low route)", ProvingGroundLayout.DUNES.get_center(), sand],
		["ridge ledge (high route)", Vector2(-160.0, -40.0), sand],
		["spawn", ProvingGroundLayout.SPAWN, null],
	]
	var wrong: PackedStringArray = []
	for check: Array in checks:
		var spot: Vector2 = check[1]
		var found: TerrainType = TerrainPatch.terrain_at(runner.get_tree(), Vector3(spot.x, _ground(spot), spot.y))
		if found != check[2]:
			wrong.append(check[0])
	report.check("Terrain map: mud and sand where the plan puts them, firm ground at the spawn",
			wrong.is_empty(), "wrong at: %s" % ", ".join(wrong) if not wrong.is_empty() else "")
	var water: Node3D = level.get_node(^"Water")
	var deep: float = ProvingGroundLayout.WATER_LEVEL - _ground(Vector2(60.0, -58.0))
	var ford: float = ProvingGroundLayout.WATER_LEVEL - _ground(ProvingGroundLayout.FORD)
	report.check("River: deep away from the ford, shallow at the ford",
			absf(water.global_position.y - ProvingGroundLayout.WATER_LEVEL) < 0.01 and deep > 1.5 and ford > 0.1 and ford < 0.6,
			"water %.1f m deep in the river, %.1f m at the ford" % [deep, ford])


## The steepest ground near each feature that should be impassable.
func _steepness() -> void:
	var places: Array = [
		["ridge cliff", Vector2(ProvingGroundLayout.RIDGE_EAST_EDGE + 3.0, -40.0)],
		["cone hill", ProvingGroundLayout.CONE + Vector2(8.0, 0.0)],
		["mesa", ProvingGroundLayout.MESA + Vector2(ProvingGroundLayout.MESA_RADIUS + 2.0, 0.0)],
		["goal plateau side", ProvingGroundLayout.GOAL + Vector2(ProvingGroundLayout.GOAL_RADIUS + 6.0, 0.0)],
		["river bank", Vector2(60.0, -58.0 + ProvingGroundLayout.RIVER_HALF_WIDTH + 1.0)],
	]
	var details: PackedStringArray = []
	var all_steep: bool = true
	for place: Array in places:
		var steepest: float = _steepest_near(place[1], 2.0)
		details.append("%s %.0f°" % [place[0], steepest])
		all_steep = all_steep and steepest > 40.0
	report.check("Cliffs and steep hills are far steeper than the tank can climb (over 40°)", all_steep, ", ".join(details))


## Drive straight at the cone hill and the ridge cliff: the tank must not get up.
func _cliffs_stop_the_tank() -> void:
	var tank: PhysicsTank = (level.get_node(^"PlayerRig") as PlayerRig).active_tank
	# From the east, on dry, firm ground. The cone's foot is about 16 m from its middle.
	var cone: Dictionary = await _drive_at(tank, ProvingGroundLayout.CONE + Vector2(45.0, 0.0), ProvingGroundLayout.CONE)
	# From the lowland east of the ridge, south of the lake; the cliff's foot is at x -146.
	var ridge_foot := Vector2(ProvingGroundLayout.RIDGE_EAST_EDGE + 6.0, -70.0)
	var ridge: Dictionary = await _drive_at(tank, Vector2(-110.0, -70.0), Vector2(-175.0, -70.0), ridge_foot)
	# It must really have driven up to them (not stood still) and still not got up.
	var base: float = ProvingGroundLayout.BASE
	var cone_foot: float = (ProvingGroundLayout.CONE_HEIGHT - base) / tan(deg_to_rad(ProvingGroundLayout.CONE_SLOPE_DEGREES))
	var cone_foot_gap: float = maxf(cone.closest - cone_foot, 0.0)
	# "Can't get up" = gets less than a third of the way up.
	var cone_third: float = base + (ProvingGroundLayout.CONE_HEIGHT - base) / 3.0
	var ridge_third: float = base + (ProvingGroundLayout.RIDGE_HEIGHT - base) / 3.0
	report.check("Driving straight at the cone hill and the ridge cliff: the tank gets there but not a third of the way up",
			cone.highest < cone_third and ridge.highest < ridge_third and cone_foot_gap < 5.0 and ridge.closest_to_foot < 5.0,
			"came within %.1f m of the cone's foot and %.1f m of the cliff's foot; highest: cone %.1f m (top %.0f m), ridge %.1f m (top %.0f m)" % [
				cone_foot_gap, ridge.closest_to_foot, cone.highest, ProvingGroundLayout.CONE_HEIGHT,
				ridge.highest, ProvingGroundLayout.RIDGE_HEIGHT])


## Full speed from `from` toward `to` for 15 s. Returns the highest it got,
## how close (flat distance) it came to `to`, and to `foot` if given.
func _drive_at(tank: PhysicsTank, from: Vector2, to: Vector2, foot: Vector2 = Vector2.INF) -> Dictionary:
	var heading: Vector2 = (to - from).normalized()
	var yaw: float = atan2(-heading.x, -heading.y)
	tank.place_at(Transform3D(Basis(Vector3.UP, yaw), Vector3(from.x, _ground(from) + 0.3, from.y)))
	tank.driver_station.listen_to_input_sources = false
	await runner.wait_physics_frames(60)
	var highest: float = -INF
	var closest: float = INF
	var closest_to_foot: float = INF
	for frame: int in 15 * FPS:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		highest = maxf(highest, tank.global_position.y)
		var here := Vector2(tank.global_position.x, tank.global_position.z)
		closest = minf(closest, here.distance_to(to))
		if foot.is_finite():
			closest_to_foot = minf(closest_to_foot, here.distance_to(foot))
	tank.driver_station.left_tread = 0.0
	tank.driver_station.right_tread = 0.0
	return {"highest": highest, "closest": closest, "closest_to_foot": closest_to_foot}


## Both routes, spawn to goal, steered by a simple autopilot.
func _routes() -> void:
	var tank: PhysicsTank = (level.get_node(^"PlayerRig") as PlayerRig).active_tank
	for high: bool in [true, false]:
		var result: Dictionary = await _drive_route(tank, layout.route_points(high))
		report.check("%s route: drivable from the spawn to the goal" % ("High" if high else "Low"),
				result.done and result.end_height > ProvingGroundLayout.GOAL_HEIGHT - 1.0,
				"%s in %.0f s, ends %.1f m up (goal plateau %.0f m)" % [
					"reached the goal" if result.done else "STUCK at point %d" % result.reached,
					result.seconds, result.end_height, ProvingGroundLayout.GOAL_HEIGHT])


## Steer the levers toward each point in turn; gives up after 150 s.
func _drive_route(tank: PhysicsTank, points: Array[Vector2]) -> Dictionary:
	tank.reset_to_spawn()
	var station: DriverStation = tank.driver_station
	station.listen_to_input_sources = false
	await runner.wait_physics_frames(60)
	var target: int = 1
	var frames: int = 0
	while target < points.size() and frames < 150 * FPS:
		var here := Vector2(tank.global_position.x, tank.global_position.z)
		if here.distance_to(points[target]) < 6.0:
			target += 1
			continue
		var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z)
		var to := Vector3(points[target].x - here.x, 0.0, points[target].y - here.y)
		# Positive = the point is to the left: slow the left tread, speed the right.
		var error: float = forward.signed_angle_to(to, Vector3.UP)
		station.left_tread = clampf(1.0 - 1.6 * error, -0.5, 1.0)
		station.right_tread = clampf(1.0 + 1.6 * error, -0.5, 1.0)
		await runner.get_tree().physics_frame
		frames += 1
	station.left_tread = 0.0
	station.right_tread = 0.0
	return {"done": target >= points.size(), "reached": target - 1, "seconds": frames / float(FPS),
			"end_height": tank.global_position.y}


func _ground(spot: Vector2) -> float:
	return level.terrain.height_at(Vector3(spot.x, 0.0, spot.y))


## Steepest slope (degrees) between points `radius` apart around `centre`.
func _steepest_near(centre: Vector2, radius: float) -> float:
	var steepest: float = 0.0
	for step: int in 16:
		var angle: float = TAU * step / 16.0
		var a: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
		var b: Vector2 = centre - Vector2(cos(angle), sin(angle)) * radius
		var rise: float = absf(_ground(a) - _ground(b))
		steepest = maxf(steepest, rad_to_deg(atan(rise / (2.0 * radius))))
	return steepest
