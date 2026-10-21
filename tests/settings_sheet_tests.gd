class_name SettingsSheetTests
extends RefCounted
## Checks that docs/tuning_settings.csv (the spreadsheet explaining every
## tuning setting) is complete and up to date: every physics tank setting and
## every Tab panel setting is listed, in the right section, with the default
## that is actually saved. If this fails after adding or moving a setting,
## update the spreadsheet.

const SHEET_PATH: String = "res://docs/tuning_settings.csv"

var runner: TestRunner
var report: TestReport
# "Thing|code name" -> {"section": String, "default": String}
var rows: Dictionary = {}


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Tuning settings spreadsheet (docs/tuning_settings.csv)")
	_read_sheet()
	report.check("Spreadsheet opens and has rows", not rows.is_empty(), "%d settings listed" % rows.size())

	# Physics tank: every setting in the file, section from the Tab panel's groups.
	var physics: PhysicsTankTuning = load("res://tuning/physics_tank_tuning.tres")
	var knob_names: Array[StringName] = []
	for row: Dictionary in physics.panel_settings():
		if String(row.group).begins_with("Feel knobs"):
			knob_names.append(row.property)
	var problems: PackedStringArray = []
	for property: Dictionary in physics.get_property_list():
		var editable: bool = property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR
		if not editable:
			continue
		var name: StringName = property.name
		var section: String = "Feel knob" if knob_names.has(name) else "Advanced"
		_check_row("Physics tank", name, section, physics.get(name), problems)
	report.check("Every physics tank setting is listed, in the right section, with its saved default",
			problems.is_empty(), "; ".join(problems))

	# Kinematic tank: every Tab panel row.
	problems = []
	var kinematic: TankTuning = load("res://tuning/tank_tuning.tres")
	for row: Dictionary in kinematic.panel_settings():
		var section: String = "Feel knob" if String(row.group).begins_with("Feel knobs") else "Advanced"
		_check_row("Kinematic tank", row.property, section, kinematic.get(row.property), problems)
	report.check("Every kinematic tank setting in the Tab panel is listed, with its saved default",
			problems.is_empty(), "; ".join(problems))

	# The Tab panel's other rows: camera, slit, level ground, terrain.
	problems = []
	var camera := ChaseCamera.new()
	for name: StringName in [&"follow_distance", &"follow_height", &"look_height", &"follow_smoothing", &"look_smoothing"]:
		_check_row("Chase camera", name, "Camera", camera.get(name), problems)
	camera.free()
	var slit := DriverSlitCamera.new()
	_check_row("Driver slit", &"slit_height", "View", slit.slit_height, problems)
	slit.free()
	var level := LevelTerrain.new()
	for name: StringName in [&"metres_per_pixel", &"max_height", &"smoothing"]:
		_check_row("Level ground", name, "Level", level.get(name), problems)
	level.free()
	for terrain_name: String in ["mud", "sand"]:
		var terrain: TerrainType = load("res://terrain/%s.tres" % terrain_name)
		for name: StringName in [&"grip", &"drag", &"top_speed", &"sink_depth"]:
			_check_row("Terrain: %s" % terrain.display_name, name, "Terrain", terrain.get(name), problems)
	report.check("Camera, slit, level ground and terrain settings are listed, with their defaults",
			problems.is_empty(), "; ".join(problems))


func _check_row(thing: String, name: StringName, section: String, value: Variant, problems: PackedStringArray) -> void:
	var key: String = "%s|%s" % [thing, name]
	if not rows.has(key):
		problems.append("%s: %s missing" % [thing, name])
		return
	var row: Dictionary = rows[key]
	if row.section != section:
		problems.append("%s: %s is under '%s', should be '%s'" % [thing, name, row.section, section])
	if not is_equal_approx(float(row.default), float(value)):
		problems.append("%s: %s default says %s, saved value is %s" % [thing, name, row.default, value])


func _read_sheet() -> void:
	var file := FileAccess.open(SHEET_PATH, FileAccess.READ)
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	var thing_column: int = header.find("Thing")
	var section_column: int = header.find("Section")
	var code_column: int = header.find("Code name")
	var default_column: int = header.find("Default")
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() <= maxi(maxi(thing_column, section_column), maxi(code_column, default_column)):
			continue
		rows["%s|%s" % [line[thing_column], line[code_column]]] = {
			"section": line[section_column], "default": line[default_column]}
