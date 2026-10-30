class_name ComparisonFeatures
extends Node3D
## Builds three test features for comparing the two tanks, when the scene
## starts. Each has its own lane, driven toward -Z from a start point:
## - Ledge strip: a raised platform beside a drop, long enough to drive along
##   it with one tread over the edge (a gentle ramp leads up onto it).
## - Steps: blocks of increasing height to drive up onto and off.
## - Crest: a slope that tips over into a downslope, to show weight transfer.
## The Tab panel lists each start point as a reset point.

## Group this node joins, so the Tab panel can list its start points.
const GROUP: StringName = &"comparison_features"

## Height of the ledge strip's platform, in metres.
@export var ledge_height: float = 1.2
## Heights of the steps, in metres, in the order you meet them.
@export var step_heights: Array[float] = [0.2, 0.4, 0.6]
## Height of the crest, in metres, and the angle of both its slopes.
@export var crest_height: float = 3.5
@export var crest_angle_degrees: float = 15.0

## Lanes, side by side along X (metres from this node).
const LEDGE_LANE_X: float = -27.0
const STEPS_LANE_X: float = 0.0
const CREST_LANE_X: float = 25.0
## Platform width and length, and its far edge (toward +X) where the drop is.
const LEDGE_WIDTH: float = 6.0
const LEDGE_LENGTH: float = 50.0
## Where every lane's start point is, along Z.
const START_Z: float = 35.0


func _ready() -> void:
	add_to_group(GROUP)
	_build_ledge_strip()
	_build_steps()
	_build_crest()


## The places the Tab panel offers as reset points: [{name, transform}].
func reset_points() -> Array[Dictionary]:
	return [
		{"name": "Ledge strip", "transform": _start_at(LEDGE_LANE_X)},
		{"name": "Steps 0.2 / 0.4 / 0.6 m", "transform": _start_at(STEPS_LANE_X)},
		{"name": "Crest %d°" % roundi(crest_angle_degrees), "transform": _start_at(CREST_LANE_X)},
	]


## On the ledge strip's platform, with the right tread hanging over the drop
## (for the tests). `over_edge`: how far the tank's middle is past the edge.
func ledge_edge_transform(over_edge: float, along: float = 15.0) -> Transform3D:
	var edge_x: float = LEDGE_LANE_X + LEDGE_WIDTH / 2.0
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(edge_x + over_edge, ledge_height + 0.1, along))


## Where the ledge strip's platform ends (the drop), in world X.
func ledge_edge_x() -> float:
	return to_global(Vector3(LEDGE_LANE_X + LEDGE_WIDTH / 2.0, 0.0, 0.0)).x


func _start_at(lane_x: float) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(lane_x, 0.3, START_Z))


func _build_ledge_strip() -> void:
	var body := _body("LedgeStrip", Color(0.55, 0.5, 0.42))
	var material: Material = body.get_meta(&"material")
	var platform := BoxMesh.new()
	platform.size = Vector3(LEDGE_WIDTH, ledge_height, LEDGE_LENGTH)
	platform.material = material
	var far_end: float = -LEDGE_LENGTH / 2.0 - 5.0
	var near_end: float = far_end + LEDGE_LENGTH
	_add_solid(body, platform, Transform3D(Basis.IDENTITY,
			Vector3(LEDGE_LANE_X, ledge_height / 2.0, (far_end + near_end) / 2.0)), "Platform")
	# A gentle ramp up onto the platform from the start side.
	var ramp_run: float = ledge_height / tan(deg_to_rad(10.0))
	_add_wedge(body, material, Vector3(LEDGE_LANE_X, 0.0, near_end + ramp_run), ramp_run, ledge_height, LEDGE_WIDTH, "Ramp")
	_add_label(body, "Ledge strip\n(drive along the edge)", Vector3(LEDGE_LANE_X, ledge_height + 4.0, near_end + ramp_run))


func _build_steps() -> void:
	var body := _body("Steps", Color(0.5, 0.55, 0.6))
	var material: Material = body.get_meta(&"material")
	var block_length: float = 8.0
	var gap: float = 7.0
	var z: float = START_Z - 20.0
	for index: int in step_heights.size():
		var height: float = step_heights[index]
		var block := BoxMesh.new()
		block.size = Vector3(8.0, height, block_length)
		block.material = material
		_add_solid(body, block, Transform3D(Basis.IDENTITY,
				Vector3(STEPS_LANE_X, height / 2.0, z - block_length / 2.0)), "Step%d" % (index + 1))
		z -= block_length + gap
	var heights: PackedStringArray = []
	for height: float in step_heights:
		heights.append("%.1f" % height)
	_add_label(body, "Steps\n%s m" % " / ".join(heights), Vector3(STEPS_LANE_X, 4.0, START_Z - 16.0))


func _build_crest() -> void:
	var body := _body("Crest", Color(0.6, 0.5, 0.35))
	var material: Material = body.get_meta(&"material")
	var half_run: float = crest_height / tan(deg_to_rad(crest_angle_degrees))
	# A symmetric wedge: PrismMesh with its peak in the middle (left_to_right
	# 0.5), turned -90 degrees about Y so it runs along Z.
	var prism := PrismMesh.new()
	prism.left_to_right = 0.5
	prism.size = Vector3(half_run * 2.0, crest_height, 8.0)
	prism.material = material
	var base_z: float = START_Z - 15.0
	_add_solid(body, prism, Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)),
			Vector3(CREST_LANE_X, crest_height / 2.0, base_z - half_run)), "Hill")
	_add_label(body, "Crest\n%d°" % roundi(crest_angle_degrees), Vector3(CREST_LANE_X, 4.0, base_z + 2.0))


## A right-angled wedge rising toward -Z, its low edge at `low_edge`.
func _add_wedge(body: StaticBody3D, material: Material, low_edge: Vector3, run: float, rise: float,
		width: float, part_name: String) -> void:
	var wedge := PrismMesh.new()
	wedge.left_to_right = 0.0
	wedge.size = Vector3(run, rise, width)
	wedge.material = material
	_add_solid(body, wedge, Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)),
			low_edge + Vector3(0.0, rise / 2.0, -run / 2.0)), part_name)


func _body(body_name: String, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	body.set_meta(&"material", material)
	add_child(body)
	return body


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


func _add_label(body: StaticBody3D, text: String, where: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 160
	label.outline_size = 24
	label.pixel_size = 0.015
	label.position = where
	TestLabels.add(label)
	body.add_child(label)
