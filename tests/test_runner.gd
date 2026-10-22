class_name TestRunner
extends Node
## Runs every automated test on the real test course, prints a report, saves it
## to tests/last_results.txt, and (when headless) quits with exit code 1 if
## anything failed.
##
## Headless (fast):
##   <godot console exe> --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
## Only some suites, while working (run everything before committing):
##   ... res://tests/test_runner.tscn -- --only=push,phone
## Suite names: sheet, input, views, panel, feel, physics, phone, usb, push,
## course, driving, brake, terrain, levels.
## To watch: open tests/test_runner.tscn in the editor and press F6.

const COURSE_SCENE: PackedScene = preload("res://scenes/test_course.tscn")
const TANK_SCENE: PackedScene = preload("res://scenes/tank.tscn")
const PHYSICS_TANK_SCENE: PackedScene = preload("res://scenes/physics_tank.tscn")
const RESULTS_PATH: String = "res://tests/last_results.txt"

var course: Node3D
var report := TestReport.new()

## True if any test tank ever had a broken (NaN/infinite) position or fell
## through the ground. Checked every physics frame while test tanks exist.
var sanity_broken_position: bool = false
var sanity_fell_through: bool = false
# Kinematic and physics test tanks.
var _watched_tanks: Array[Node3D] = []
# Suite names given with -- --only=..., empty = run everything.
var _only: PackedStringArray = []


func _read_only_list() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=").split(",", false)


func _wanted(suite: String) -> bool:
	return _only.is_empty() or _only.has(suite)


func _ready() -> void:
	# Phone servers listen on this computer only during tests (no firewall question),
	# on their own ports so a running game or open controller page can't interfere.
	ControllerServer.bind_address_override = "127.0.0.1"
	ControllerServer.http_port_override = 18080
	ControllerServer.websocket_port_override = 18081
	# Never run the real adb during tests (UsbLinkTests uses a pretend one).
	UsbPhoneLink.enabled_in_scenes = false
	# Never open real MIDI or the usual light port during tests (PushTests pretends).
	PushController.open_midi_in_scenes = false
	PushLightSender.port_override = 19080
	course = COURSE_SCENE.instantiate()
	add_child(course)
	# Let the course builders run and physics settle.
	await wait_physics_frames(5)

	report.add_line("Tank game tests  (%s)" % Time.get_datetime_string_from_system(false, true))
	_read_only_list()
	if not _only.is_empty():
		report.add_line("ONLY these suites (a partial run): %s" % ", ".join(_only))
	# Loaded by path, so it runs even before Godot has registered the class.
	if _wanted("sheet"):
		preload("res://tests/settings_sheet_tests.gd").new(self).run()
	if _wanted("input"):
		await InputTests.new(self).run()
	if _wanted("views"):
		await ViewTests.new(self).run()
	if _wanted("panel"):
		await PanelTests.new(self).run()
	if _wanted("feel"):
		await FeelTests.new(self).run_preset_keys()
	if _wanted("physics"):
		await PhysicsTankTests.new(self).run_swap()
	if _wanted("phone"):
		await PhoneTests.new(self).run()
	if _wanted("usb"):
		UsbLinkTests.new(self).run()
	if _wanted("push"):
		await PushTests.new(self).run()
	if _wanted("course"):
		CourseTests.new(self).run()
	if _wanted("driving"):
		await DrivingTests.new(self).run()
	if _wanted("brake"):
		await BrakeTests.new(self).run()
	if _wanted("feel"):
		await FeelTests.new(self).run()
	if _wanted("physics"):
		await PhysicsTankTests.new(self).run()
	if _wanted("terrain"):
		await TerrainTests.new(self).run()
	if _wanted("levels"):
		await LevelTests.new(self).run()

	report.heading("Sanity")
	report.check("No NaN or infinite positions", not sanity_broken_position)
	report.check("No tank fell through the ground", not sanity_fell_through)

	report.add_line("")
	report.add_line(report.summary())
	_save_results()
	_finish()


func _physics_process(_delta: float) -> void:
	for tank: Node3D in _watched_tanks:
		if not is_instance_valid(tank):
			continue
		if not tank.global_position.is_finite():
			sanity_broken_position = true
		# Below the ground slab while over the ground: fell through it.
		# (Tanks thrown outside the walls on purpose are allowed to fall.)
		elif tank.global_position.y < -2.5 and _is_over_ground(tank.global_position):
			sanity_fell_through = true


func _is_over_ground(where: Vector3) -> bool:
	# The course is removed for the last (level) tests.
	if not is_instance_valid(course):
		return false
	var builder := course.get_node(^"CourseBuilder") as CourseBuilder
	return absf(where.x) < builder.ground_size.x / 2.0 and absf(where.z) < builder.ground_size.y / 2.0


func wait_physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


## A fresh tank for a test, driven only by values written into its station.
## Test tanks pass through each other, so side-by-side tests don't interfere.
func spawn_test_tank(where: Vector3, yaw_radians: float = 0.0) -> Tank:
	var tank: Tank = TANK_SCENE.instantiate()
	tank.position = where
	tank.rotation.y = yaw_radians
	course.add_child(tank)
	tank.driver_station.listen_to_input_sources = false
	_keep_apart(tank)
	return tank


## A fresh physics tank for a test, like spawn_test_tank().
func spawn_test_physics_tank(where: Vector3, yaw_radians: float = 0.0) -> PhysicsTank:
	var tank: PhysicsTank = PHYSICS_TANK_SCENE.instantiate()
	tank.position = where
	tank.rotation.y = yaw_radians
	course.add_child(tank)
	tank.driver_station.listen_to_input_sources = false
	_keep_apart(tank)
	return tank


## Test tanks pass through each other (and physics tanks' probes ignore other tanks).
func _keep_apart(tank: PhysicsBody3D) -> void:
	for other: Node3D in _watched_tanks:
		if is_instance_valid(other):
			tank.add_collision_exception_with(other)
			for body: Node in [tank, other]:
				var partner: Node = other if body == tank else tank
				for probe: Node in body.find_children("Probe*", "RayCast3D", false, false):
					(probe as RayCast3D).add_exception(partner as CollisionObject3D)
	_watched_tanks.append(tank)


## Point the chase camera and readout at a tank, so the tests can be watched.
func watch_tank(tank: Node3D) -> void:
	var camera := course.get_node_or_null(^"PlayerRig/ChaseCamera") as ChaseCamera
	if camera != null:
		camera.target = tank
	var hud := course.get_node_or_null(^"PlayerRig/DebugHud") as DebugHud
	if hud != null:
		hud.tank = tank
		hud.station = tank.driver_station


func remove_test_tanks() -> void:
	for tank: Node3D in _watched_tanks:
		# Only tanks the tests added straight to the course (the player's tank is in PlayerRig).
		if is_instance_valid(tank) and tank.get_parent() == course:
			tank.queue_free()
	_watched_tanks.clear()
	await wait_physics_frames(2)


func _save_results() -> void:
	var file := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % RESULTS_PATH)
		return
	file.store_string(report.full_text())


func _finish() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if report.failed > 0 else 0)
		return
	# Watching in the editor: keep the window open and show the summary.
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "TESTS DONE: %s\nFull report: tests/last_results.txt" % report.summary()
	label.position = Vector2(12.0, 200.0)
	label.add_theme_font_size_override(&"font_size", 28)
	layer.add_child(label)
	add_child(layer)
