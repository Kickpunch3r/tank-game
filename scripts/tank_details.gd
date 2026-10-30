class_name TankDetails
extends Node3D
## Extra looks for the physics tank: a sloped front plate, road wheels that
## turn, and track links that move at each tread's speed. Looks only: the
## tank drives the same without them. Built by script; can be switched off
## from the Tab panel (Graphics > Tank details).
##
## Put it inside the tank's Visual/Hull node. It reads the tank's
## left_tread_speed and right_tread_speed every frame.

const TREAD_SHADER: Shader = preload("res://art/tread.gdshader")

## Road wheels per side, their radius, and how far apart the end ones are.
const WHEELS_PER_SIDE: int = 5
const WHEEL_RADIUS: float = 0.32
const WHEEL_SPAN: float = 3.8
## Where the treads are (matches the tread boxes in the tank scene).
const TREAD_X: float = 1.5
const TREAD_SIZE := Vector3(0.6, 0.9, 5.0)
const TREAD_Y: float = 0.45

## How far each tread has moved (left, right), in metres.
var travel: Array[float] = [0.0, 0.0]

var _tank: Node3D
var _wheels: Array[Node3D] = []
var _tread_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	add_to_group(GraphicsOptions.TANK_DETAILS_GROUP)
	_tank = _find_tank()
	_build_front_plate()
	for side: float in [-1.0, 1.0]:
		_build_tread(side)
		_build_wheels(side)
	visible = GraphicsOptions.tank_details


func _process(delta: float) -> void:
	if _tank == null or not visible:
		return
	var speeds: Array[float] = [_tank.get(&"left_tread_speed"), _tank.get(&"right_tread_speed")]
	for side: int in 2:
		travel[side] += speeds[side] * delta
		_tread_materials[side].set_shader_parameter(&"travel", travel[side])
	for index: int in _wheels.size():
		# Wheels roll forward (turn about -x) as their tread moves forward.
		_wheels[index].rotation.x = -travel[0 if index < WHEELS_PER_SIDE else 1] / WHEEL_RADIUS


func _find_tank() -> Node3D:
	var node: Node = get_parent()
	while node != null and not (&"left_tread_speed" in node):
		node = node.get_parent()
	return node as Node3D


## A wedge in front of the hull box, sloping down and forward.
func _build_front_plate() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = 1.2
	var top_back := 1.1
	var bottom := 0.5
	var back_z := -2.3
	var front_z := -2.7
	# Corners: left/right x top-back, bottom-back, bottom-front.
	var corners: Array[Vector3] = []
	for x: float in [-half, half]:
		corners.append_array([Vector3(x, top_back, back_z), Vector3(x, bottom, back_z), Vector3(x, bottom, front_z)])
	var faces: Array = [
		[0, 2, 5, 3],  # sloped face
		[1, 4, 5, 2],  # bottom
		[0, 3, 4, 1],  # back (against the hull)
	]
	for face: Array in faces:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		for point: Vector3 in [a, b, c, a, c, d]:
			tool.add_vertex(point)
	for triangle: Array in [[0, 1, 2], [3, 5, 4]]:  # the two ends
		for index: int in triangle:
			tool.add_vertex(corners[index])
	tool.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.38, 0.46)
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plate := MeshInstance3D.new()
	plate.name = "FrontPlate"
	plate.mesh = tool.commit()
	plate.material_override = material
	add_child(plate)


## A box just over the plain tread, with the moving track pattern.
func _build_tread(side: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = TREAD_SIZE + Vector3(0.02, 0.02, 0.02)
	var material := ShaderMaterial.new()
	material.shader = TREAD_SHADER
	_tread_materials.append(material)
	var tread := MeshInstance3D.new()
	tread.name = "TrackLeft" if side < 0.0 else "TrackRight"
	tread.mesh = mesh
	tread.material_override = material
	tread.position = Vector3(side * TREAD_X, TREAD_Y, 0.0)
	add_child(tread)


## Road wheels on the outside of the tread, each with a hub bar so you can
## see it turn.
func _build_wheels(side: float) -> void:
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = WHEEL_RADIUS
	wheel_mesh.bottom_radius = WHEEL_RADIUS
	wheel_mesh.height = 0.08
	wheel_mesh.radial_segments = 12
	wheel_mesh.rings = 1
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.25, 0.3, 0.34)
	wheel_material.roughness = 0.8
	var hub_mesh := BoxMesh.new()
	hub_mesh.size = Vector3(0.1, WHEEL_RADIUS * 1.7, 0.1)
	var hub_material := StandardMaterial3D.new()
	hub_material.albedo_color = Color(0.12, 0.12, 0.12)
	for index: int in WHEELS_PER_SIDE:
		var wheel := Node3D.new()
		wheel.name = "Wheel%s%d" % ["Left" if side < 0.0 else "Right", index]
		wheel.position = Vector3(side * (TREAD_X + TREAD_SIZE.x / 2.0 + 0.05), WHEEL_RADIUS + 0.05,
				-WHEEL_SPAN / 2.0 + WHEEL_SPAN * index / (WHEELS_PER_SIDE - 1))
		var disc := MeshInstance3D.new()
		disc.mesh = wheel_mesh
		disc.material_override = wheel_material
		disc.rotation.z = PI / 2.0  # axle along x
		wheel.add_child(disc)
		var hub := MeshInstance3D.new()
		hub.mesh = hub_mesh
		hub.material_override = hub_material
		hub.position.x = side * 0.05
		wheel.add_child(hub)
		add_child(wheel)
		_wheels.append(wheel)
