class_name SlopeLadder
extends Node3D
## Builds a row of ramps of increasing steepness when the scene starts, from
## the list in `ramp_list_path` (a plain text file you can edit without Godot).
##
## Ramps sit side by side, left to right along X. Each one starts at this
## node's position (its base line) and rises away from the start field,
## toward -Z. Tests ask this node where each ramp's base and top are.

## Group every row of ramps joins, so the Tab panel can list their ramps.
const GROUP: StringName = &"slope_ladders"

## The text file listing each ramp's angle and whether it has a ledge.
@export_file("*.txt") var ramp_list_path: String = "res://levels/slope_ladder.txt"

## Length of each ramp's slope surface, in metres (measured along the slope).
@export var ramp_length: float = 20.0

## Width of each ramp, in metres.
@export var ramp_width: float = 8.0

## Flat ground between neighbouring ramps, in metres.
@export var ramp_gap: float = 4.0

## Length of the flat platform on top of ramps that have a ledge, in metres.
@export var ledge_length: float = 10.0

## Distance of flat run-up in front of each ramp, used by the tests, in metres.
@export var run_up_length: float = 70.0


## What the builder knows about one ramp, in world coordinates.
class RampInfo:
	## Steepness in degrees.
	var angle_degrees: float
	## True if there is a flat platform on top.
	var has_ledge: bool
	## What the ramp's surface is made of (null = ordinary firm ground).
	var terrain: TerrainType
	## Middle of the ramp's bottom edge, on the ground.
	var base_position: Vector3
	## Middle of the ramp's top edge (where the slope ends).
	var top_position: Vector3
	## Where a tank starts for a run-up at this ramp.
	var run_up_start: Vector3


var ramps: Array[RampInfo] = []


func _ready() -> void:
	add_to_group(GROUP)
	ramps = _read_ramp_list()
	for index: int in ramps.size():
		_place_ramp(index)
		_build_ramp(ramps[index], index)


## Reads lines like "25  ledge" or "30  no ledge", optionally followed by a
## terrain name ("20  no ledge  mud" uses terrain/mud.tres).
## Skips blank lines and # notes.
func _read_ramp_list() -> Array[RampInfo]:
	var result: Array[RampInfo] = []
	var file := FileAccess.open(ramp_list_path, FileAccess.READ)
	if file == null:
		push_error("SlopeLadder: cannot open ramp list %s" % ramp_list_path)
		return result
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		line_number += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		var words: PackedStringArray = line.split(" ", false)
		if not words[0].is_valid_float():
			push_error("SlopeLadder: line %d: '%s' does not start with an angle" % [line_number, line])
			continue
		var ramp := RampInfo.new()
		ramp.angle_degrees = words[0].to_float()
		var rest: String = " ".join(words.slice(1)).to_lower()
		var terrain_name: String = ""
		if rest.begins_with("no ledge"):
			ramp.has_ledge = false
			terrain_name = rest.trim_prefix("no ledge").strip_edges()
		elif rest.begins_with("ledge"):
			ramp.has_ledge = true
			terrain_name = rest.trim_prefix("ledge").strip_edges()
		else:
			push_warning("SlopeLadder: line %d: expected 'ledge' or 'no ledge', got '%s'; using ledge" % [line_number, rest])
			ramp.has_ledge = true
		if not terrain_name.is_empty():
			ramp.terrain = _load_terrain(terrain_name, line_number)
		result.append(ramp)
	return result


func _load_terrain(terrain_name: String, line_number: int) -> TerrainType:
	var path: String = "res://terrain/%s.tres" % terrain_name
	if not ResourceLoader.exists(path):
		push_error("SlopeLadder: line %d: no terrain file %s" % [line_number, path])
		return null
	return load(path) as TerrainType


## Where a tank should stand to face ramp `index`, `distance` metres back from
## it. At distance 0 the tank's round bottom (radius `tank_radius`) just touches
## the slope, with no run-in. (A sphere resting on flat ground touches a slope
## of angle a when its centre is radius x tan(a / 2) in front of the bottom edge.)
## Where `tank` (either kind) stands at rest at the foot of ramp `index`,
## `distance` metres back. Each kind of tank says how close it can stand.
func start_position_for(index: int, distance: float, tank: Node3D) -> Vector3:
	var ramp: RampInfo = ramps[index]
	var touching: float = tank.call(&"standing_start_distance", ramp.angle_degrees)
	return ramp.base_position + Vector3(0.0, 0.05, touching + distance)


func start_position(index: int, distance: float, tank_radius: float) -> Vector3:
	var ramp: RampInfo = ramps[index]
	var touching: float = tank_radius * tan(deg_to_rad(ramp.angle_degrees) / 2.0) + 0.05
	return ramp.base_position + Vector3(0.0, 0.05, touching + distance)


## Works out where ramp number `index` sits in the world.
func _place_ramp(index: int) -> void:
	var ramp: RampInfo = ramps[index]
	var pitch: float = ramp_width + ramp_gap
	var x: float = (index - (ramps.size() - 1) / 2.0) * pitch
	var angle: float = deg_to_rad(ramp.angle_degrees)
	ramp.base_position = global_position + Vector3(x, 0.0, 0.0)
	ramp.top_position = ramp.base_position + Vector3(0.0, ramp_length * sin(angle), -ramp_length * cos(angle))
	ramp.run_up_start = ramp.base_position + Vector3(0.0, 0.0, run_up_length)


func _build_ramp(ramp: RampInfo, index: int) -> void:
	var angle: float = deg_to_rad(ramp.angle_degrees)
	var run: float = ramp_length * cos(angle)
	var rise: float = ramp_length * sin(angle)
	var local_base: Vector3 = to_local(ramp.base_position)

	var body := StaticBody3D.new()
	body.name = "Ramp%02d_%ddeg" % [index + 1, roundi(ramp.angle_degrees)]
	add_child(body)
	var material := StandardMaterial3D.new()
	material.albedo_color = ramp.terrain.colour if ramp.terrain != null else _ramp_colour(index)
	material.roughness = 0.85

	# The slope: a right-angled wedge. PrismMesh with left_to_right = 0 puts the
	# high side on its left (-X); turning it -90 degrees about Y points that
	# high side away from the start field (-Z), with its width along X.
	var wedge := PrismMesh.new()
	wedge.left_to_right = 0.0
	wedge.size = Vector3(run, rise, ramp_width)
	wedge.material = material
	var wedge_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)),
			local_base + Vector3(0.0, rise / 2.0, -run / 2.0))
	_add_solid(body, wedge, wedge_transform, "Slope")

	if ramp.has_ledge:
		var ledge := BoxMesh.new()
		ledge.size = Vector3(ramp_width, rise, ledge_length)
		ledge.material = material
		var ledge_transform := Transform3D(Basis.IDENTITY,
				local_base + Vector3(0.0, rise / 2.0, -run - ledge_length / 2.0))
		_add_solid(body, ledge, ledge_transform, "Ledge")

	if ramp.terrain != null:
		# Terrain patches lying along the slope (and on the ledge), so treads
		# on the ramp use its terrain. The ramp is already coloured.
		_add_terrain_patch(body, ramp.terrain, Vector2(ramp_width, ramp_length),
				Transform3D(Basis(Vector3.RIGHT, angle), local_base + Vector3(0.0, rise / 2.0, -run / 2.0)))
		if ramp.has_ledge:
			_add_terrain_patch(body, ramp.terrain, Vector2(ramp_width, ledge_length),
					Transform3D(Basis.IDENTITY, local_base + Vector3(0.0, rise, -run - ledge_length / 2.0)))

	var label := Label3D.new()
	label.name = "AngleLabel"
	label.text = "%d°\n%s" % [roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge"]
	if ramp.terrain != null:
		label.text += "\n" + ramp.terrain.display_name.to_lower()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 160
	label.outline_size = 24
	label.pixel_size = 0.015
	label.position = local_base + Vector3(0.0, 4.0, 3.0)
	TestLabels.add(label)
	body.add_child(label)


func _add_terrain_patch(body: StaticBody3D, terrain: TerrainType, patch_size: Vector2, where: Transform3D) -> void:
	var patch := TerrainPatch.new()
	patch.name = "TerrainPatch"
	patch.terrain = terrain
	patch.size = patch_size
	patch.show_visual = false
	patch.transform = where
	body.add_child(patch)


## Adds a mesh you can see and a matching collision shape, both at `where`.
func _add_solid(body: StaticBody3D, mesh: PrimitiveMesh, where: Transform3D, part_name: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = part_name + "Visual"
	visual.mesh = mesh
	visual.transform = where
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = part_name + "Collision"
	collision.shape = mesh.create_convex_shape()
	collision.transform = where
	body.add_child(collision)


## Green for the gentlest ramp, through yellow, to red for the steepest.
func _ramp_colour(index: int) -> Color:
	var t: float = 0.0 if ramps.size() < 2 else float(index) / (ramps.size() - 1)
	return Color.from_hsv(0.33 * (1.0 - t), 0.75, 0.85)
