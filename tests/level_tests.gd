class_name LevelTests
extends RefCounted
## Checks the painted level builder: heights come out where the image says,
## smoothing works, and the starter level runs with the player rig, the tank
## at the start, and settings that rebuild the ground.
## Runs last: it removes the test course to make room for the starter level.

const STARTER_LEVEL: String = "res://levels/starter/starter.tscn"
## Far from the test course, so the small test ground can't touch it.
const TEST_GROUND_AT := Vector3(3000.0, 0.0, 0.0)

var runner: TestRunner
var report: TestReport


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Level builder")
	await _heights_match_image()
	await _smoothing_softens()
	await _starter_level()


## A small image with known greys: the ground must stand exactly that high.
func _heights_match_image() -> void:
	var image := Image.create(33, 33, false, Image.FORMAT_L8)
	image.fill(Color(0.0, 0.0, 0.0))
	# A 9 x 9 block of 50% grey around pixel (24, 8), so a ray can land on a flat part.
	for z: int in range(4, 13):
		for x: int in range(20, 29):
			image.set_pixel(x, z, Color(0.5, 0.5, 0.5))
	var level := LevelTerrain.new()
	level.position = TEST_GROUND_AT
	level.metres_per_pixel = 2.0
	level.max_height = 20.0
	level.smoothing = 0
	runner.add_child(level)
	level.build_from_image(image)
	await runner.wait_physics_frames(3)

	# Pixel (24, 8) is 8 px right of centre and 8 px up (north): x +16 m, z -16 m.
	var grey_spot: Vector3 = TEST_GROUND_AT + Vector3(16.0, 0.0, -16.0)
	var black_spot: Vector3 = TEST_GROUND_AT + Vector3(-16.0, 0.0, 16.0)
	var grey_hit: float = _ray_height(grey_spot)
	var black_hit: float = _ray_height(black_spot)
	# Read the grey back: 50% is stored as 127 or 128 of 255 depending on rounding.
	var want_grey: float = 20.0 * image.get_pixel(24, 8).get_luminance()
	report.check("Ground height matches the image (grey 50% = 10 m with max 20 m)",
			absf(grey_hit - want_grey) < 0.05 and absf(black_hit) < 0.05,
			"grey spot %.2f m (want %.2f), black spot %.2f m" % [grey_hit, want_grey, black_hit])
	report.check("Metres per pixel sets the level's size", level.ground_size().is_equal_approx(Vector2(64.0, 64.0)),
			"%s m for 33 px at 2 m per pixel" % level.ground_size())
	report.check("height_at agrees with the ground you drive on",
			absf(level.height_at(grey_spot) - grey_hit) < 0.05)
	level.queue_free()
	await runner.wait_physics_frames(2)


## One bright pixel: smoothing spreads it into its neighbours.
func _smoothing_softens() -> void:
	var image := Image.create(9, 9, false, Image.FORMAT_L8)
	image.fill(Color(0.0, 0.0, 0.0))
	image.set_pixel(4, 4, Color(1.0, 1.0, 1.0))
	var level := LevelTerrain.new()
	level.position = TEST_GROUND_AT
	level.max_height = 9.0
	level.smoothing = 1
	runner.add_child(level)
	level.build_from_image(image)
	var peak: float = level.height_at(TEST_GROUND_AT)
	report.check("Smoothing softens a sharp spike (one pass: 9 m spike becomes 1 m)",
			absf(peak - 1.0) < 0.01, "peak %.2f m" % peak)
	level.queue_free()
	await runner.wait_physics_frames(2)


func _starter_level() -> void:
	if not ResourceLoader.exists(STARTER_LEVEL):
		report.check("Starter level exists", false, STARTER_LEVEL)
		return
	# Make room: the starter level sits where the test course is.
	await runner.remove_test_tanks()
	runner.course.queue_free()
	await runner.wait_physics_frames(3)

	var level: LevelRoot = (load(STARTER_LEVEL) as PackedScene).instantiate()
	runner.add_child(level)
	await runner.wait_physics_frames(60)
	var tank: Tank = level.tank
	report.check("Running a level adds the player rig and tank", tank != null and level.has_node(^"PlayerRig"))
	if tank == null:
		return

	var start: Vector3 = level.start.global_position
	var ground: float = level.terrain.height_at(tank.global_position)
	report.check("Tank starts at the start marker, on the ground",
			Vector2(tank.global_position.x, tank.global_position.z).distance_to(Vector2(start.x, start.z)) < 0.5
			and tank.is_on_floor() and absf(tank.global_position.y - ground) < 0.3,
			"tank %s, ground %.2f m" % [tank.global_position, ground])

	# Drive forward along the flat strip for 5 seconds.
	var station: DriverStation = tank.driver_station
	station.listen_to_input_sources = false
	var lowest_gap: float = 99.0
	for frame: int in 300:
		station.left_tread = 1.0
		station.right_tread = 1.0
		await runner.get_tree().physics_frame
		lowest_gap = minf(lowest_gap, tank.global_position.y - level.terrain.height_at(tank.global_position))
	var travelled: float = Vector2(tank.global_position.x - start.x, tank.global_position.z - start.z).length()
	report.check("Drives across the level without sinking into the ground",
			travelled > 30.0 and lowest_gap > -0.3,
			"travelled %.0f m, lowest point %.2f m relative to the ground" % [travelled, lowest_gap])

	# Changing a level setting in the Tab panel rebuilds the ground and puts the tank back.
	station.left_tread = 0.0
	station.right_tread = 0.0
	var panel: TuningPanel = level.get_node(^"PlayerRig/TuningPanel")
	var before: float = level.terrain.height_at(level.start.global_position + Vector3(0.0, 0.0, -150.0))
	var started: int = Time.get_ticks_msec()
	level.terrain.rebuild()
	report.add_line("INFO  one rebuild of the 256 x 256 starter ground took %d ms" % (Time.get_ticks_msec() - started))
	panel.set_setting(&"max_height", 60.0)
	await runner.wait_physics_frames(60)
	var after: float = level.terrain.height_at(level.start.global_position + Vector3(0.0, 0.0, -150.0))
	report.check("Tab panel: changing max height rebuilds the ground", after > before * 1.5,
			"a mesa point went from %.1f m to %.1f m" % [before, after])
	report.check("After a rebuild, the tank is back at the start on the new ground",
			Vector2(tank.global_position.x, tank.global_position.z).distance_to(Vector2(start.x, start.z)) < 0.5
			and tank.global_position.y - level.terrain.height_at(tank.global_position) > -0.3,
			"tank %s, ground there %.2f m, start %s" % [tank.global_position, level.terrain.height_at(tank.global_position), start])
	# Bug found by the developer: at max height 60 and 2 m per pixel, driving
	# straight at the mesa's south cliff made the tank bounce on the spot.
	panel.set_setting(&"metres_per_pixel", 2.0)
	await runner.wait_physics_frames(60)
	var highest_above_ground: float = 0.0
	var take_offs: int = 0
	var was_on_floor: bool = true
	for frame: int in 20 * 60:
		station.left_tread = 1.0
		station.right_tread = 1.0
		await runner.get_tree().physics_frame
		highest_above_ground = maxf(highest_above_ground,
				tank.global_position.y - level.terrain.height_at(tank.global_position))
		if was_on_floor and not tank.is_on_floor():
			take_offs += 1
		was_on_floor = tank.is_on_floor()
	report.check("Driving into a cliff stops the tank: no bouncing, no launching",
			highest_above_ground < 1.5 and take_offs <= 3,
			"highest %.2f m above the ground, left the ground %d times in 20 s" % [highest_above_ground, take_offs])
	station.left_tread = 0.0
	station.right_tread = 0.0
	panel._on_reset_to_saved_pressed()
	await runner.wait_physics_frames(60)
	await _physics_tank_in_level(level)


## T works in painted levels too: the physics tank takes over at the start,
## drives on the painted ground, and R puts it back at the level's start.
func _physics_tank_in_level(level: LevelRoot) -> void:
	var rig: PlayerRig = level.get_node(^"PlayerRig")
	var physics_tank: PhysicsTank = rig.get_node(^"PhysicsTank")
	var start: Vector3 = level.start.global_position
	rig.swap_tank()
	var station: DriverStation = physics_tank.driver_station
	station.listen_to_input_sources = false
	await runner.wait_physics_frames(120)
	var gap: float = physics_tank.global_position.y - level.terrain.height_at(physics_tank.global_position)
	report.check("Level: T swaps to the physics tank, which settles on the ground at the start",
			rig.active_tank == physics_tank and absf(gap) < 0.3
			and Vector2(physics_tank.global_position.x, physics_tank.global_position.z).distance_to(Vector2(start.x, start.z)) < 1.0,
			"physics tank %s, %.2f m from the ground" % [physics_tank.global_position, gap])
	var lowest_gap: float = 99.0
	for frame: int in 300:
		station.left_tread = 1.0
		station.right_tread = 1.0
		await runner.get_tree().physics_frame
		lowest_gap = minf(lowest_gap, physics_tank.global_position.y - level.terrain.height_at(physics_tank.global_position))
	var travelled: float = Vector2(physics_tank.global_position.x - start.x, physics_tank.global_position.z - start.z).length()
	station.left_tread = 0.0
	station.right_tread = 0.0
	station.reset_requested = true
	await runner.get_tree().physics_frame
	station.reset_requested = false
	await runner.wait_physics_frames(2)
	var back_home: bool = Vector2(physics_tank.global_position.x, physics_tank.global_position.z).distance_to(Vector2(start.x, start.z)) < 0.5
	report.check("Level: the physics tank drives on the painted ground, and reset brings it back to the start",
			travelled > 25.0 and lowest_gap > -0.5 and back_home,
			"travelled %.0f m, lowest point %.2f m relative to the ground, back at start: %s" % [travelled, lowest_gap, back_home])
	rig.swap_tank()


func _ray_height(where: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(where + Vector3.UP * 200.0, where + Vector3.DOWN * 200.0)
	var hit: Dictionary = runner.get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else -999.0
