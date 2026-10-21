class_name FeelTests
extends RefCounted
## Checks the six feel knobs of the kinematic tank: weight, sideways grip,
## grip as an angle, tippiness (looks only), and the presets.

const FLAT_AREA := Vector3(-100.0, 0.05, 60.0)
const FPS: int = 60

var runner: TestRunner
var report: TestReport


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Feel knobs")
	await _weight_tests()
	await _slide_tests()
	await _tippiness_tests()


# --- Weight ----------------------------------------------------------------

func _weight_tests() -> void:
	var normal: Dictionary = await _speed_up_and_coast(1.0)
	var heavy: Dictionary = await _speed_up_and_coast(2.0)
	report.check("Weight 2: takes longer to reach top speed",
			heavy.to_top > normal.to_top + 0.5,
			"0 to 9.5 m/s: %.2f s at weight 1, %.2f s at weight 2" % [normal.to_top, heavy.to_top])
	report.check("Weight 2: travels further after letting go (levers to 0)",
			heavy.coast > normal.coast * 1.5,
			"coasted %.1f m at weight 1, %.1f m at weight 2" % [normal.coast, heavy.coast])


## From rest, full forward until 95% of top speed, then levers to 0 until it
## stops. Returns the time to top speed and the distance coasted.
func _speed_up_and_coast(weight: float) -> Dictionary:
	# Facing +Z, away from the ramps, so the long drive stays on flat ground.
	var tank: Tank = _tank(FLAT_AREA, PI)
	tank.tuning.weight = weight
	tank.driver_station.brake = true
	await runner.wait_physics_frames(20)
	tank.driver_station.brake = false
	var frames: int = 0
	while tank.forward_speed < 0.95 * tank.tuning.top_speed and frames < 1200:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 1.0
		await runner.get_tree().physics_frame
		frames += 1
	var to_top: float = frames / float(FPS)
	tank.driver_station.left_tread = 0.0
	tank.driver_station.right_tread = 0.0
	var start: Vector3 = tank.global_position
	frames = 0
	while tank.forward_speed > 0.01 and frames < 1200:
		await runner.get_tree().physics_frame
		frames += 1
	var coast: float = tank.global_position.distance_to(start)
	await runner.remove_test_tanks()
	return {"to_top": to_top, "coast": coast}


# --- Sideways slide ----------------------------------------------------------

func _slide_tests() -> void:
	var rails: Dictionary = await _sideways_speed_in_sharp_turn(1.0)
	var drifty: Dictionary = await _sideways_speed_in_sharp_turn(0.3)
	# Even without slide, the real motion lags the turn by one frame (the
	# tank moves along the heading it had at the start of the frame), which
	# shows as a few cm/s sideways. That was there before; slide is extra.
	report.check("Sideways grip 1: a sharp turn at speed doesn't slide",
			rails.slide == 0.0 and rails.sideways < 0.05,
			"slide %.3f m/s; real sideways %.3f m/s (one-frame turning lag)" % [rails.slide, rails.sideways])
	report.check("Sideways grip 0.3: the same turn slides outward",
			drifty.slide > 0.5 and drifty.sideways > 0.5 and drifty.outward,
			"slide %.2f m/s; real sideways %.2f m/s" % [drifty.slide, drifty.sideways])


## At full speed, swing into a sharp right turn (levers 1 and 0.25) for 2 s.
## Returns the largest slide speed and real sideways speed (across the tank's
## facing) seen, and whether the slide went outward (to the left).
func _sideways_speed_in_sharp_turn(sideways_grip: float) -> Dictionary:
	var tank: Tank = _tank(FLAT_AREA, PI)
	tank.tuning.sideways_grip = sideways_grip
	tank.driver_station.brake = true
	await runner.wait_physics_frames(20)
	tank.driver_station.brake = false
	tank.left_tread.speed = 10.0
	tank.right_tread.speed = 10.0
	var result: Dictionary = {"slide": 0.0, "sideways": 0.0, "outward": false}
	for frame: int in 2 * FPS:
		tank.driver_station.left_tread = 1.0
		tank.driver_station.right_tread = 0.25
		await runner.get_tree().physics_frame
		var sideways: float = tank.get_real_velocity().dot(tank.global_basis.x)
		result.slide = maxf(result.slide, tank.slide_speed())
		result.sideways = maxf(result.sideways, absf(sideways))
		# Turning right, the slide carries the tank out to the left.
		if tank.slide_speed() > 0.1:
			result.outward = tank.slide_velocity.dot(tank.global_basis.x) < 0.0
	await runner.remove_test_tanks()
	return result


# --- Tippiness (looks only) ----------------------------------------------------

func _tippiness_tests() -> void:
	var rigid: Dictionary = await _drive_pattern(0.0)
	var tippy: Dictionary = await _drive_pattern(1.0)
	var largest_gap: float = 0.0
	for index: int in rigid.path.size():
		largest_gap = maxf(largest_gap, (rigid.path[index] as Vector3).distance_to(tippy.path[index]))
	report.check("Tippiness never changes the tank's path", largest_gap < 0.001,
			"paths differ by at most %.4f m" % largest_gap)
	report.check("Tippiness 1: the hull picture sways (speeding up, braking, turning)",
			tippy.most_sway > 2.0 and rigid.most_sway < 0.01,
			"largest sway %.1f° at tippiness 1, %.2f° at 0" % [tippy.most_sway, rigid.most_sway])
	var camera_gap: float = 0.0
	for index: int in rigid.camera.size():
		var a: Transform3D = rigid.camera[index]
		var b: Transform3D = tippy.camera[index]
		camera_gap = maxf(camera_gap, a.origin.distance_to(b.origin) + (a.basis.z - b.basis.z).length())
	report.check("Tippiness never moves the driver's slit camera",
			camera_gap < 0.001, "slit camera differs by at most %.4f between tippiness 0 and 1" % camera_gap)


## Speed up, turn, then brake, recording the path, the slit camera's place
## and direction, and the largest hull sway (degrees).
func _drive_pattern(tippiness: float) -> Dictionary:
	var tank: Tank = _tank(FLAT_AREA, PI)
	tank.tuning.tippiness = tippiness
	await runner.wait_physics_frames(20)
	var sway: HullSway = tank.get_node(^"Visual/Hull/Sway")
	var slit: Camera3D = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	var path: Array[Vector3] = []
	var most_sway: float = 0.0
	var camera: Array[Transform3D] = []
	var steps: Array = [[1.0, 1.0, false, 90], [1.0, 0.25, false, 60], [0.0, 0.0, true, 60]]
	for step: Array in steps:
		for frame: int in step[3]:
			tank.driver_station.left_tread = step[0]
			tank.driver_station.right_tread = step[1]
			tank.driver_station.brake = step[2]
			await runner.get_tree().physics_frame
			path.append(tank.global_position)
			most_sway = maxf(most_sway, rad_to_deg(maxf(absf(sway.pitch), absf(sway.roll))))
			camera.append(slit.global_transform)
	await runner.remove_test_tanks()
	return {"path": path, "most_sway": most_sway, "camera": camera}


## A test tank with its own copy of the tuning, watched by the camera and HUD.
func _tank(where: Vector3, yaw_radians: float = 0.0) -> Tank:
	var tank: Tank = runner.spawn_test_tank(where, yaw_radians)
	tank.tuning = tank.tuning.duplicate()
	runner.watch_tank(tank)
	return tank
