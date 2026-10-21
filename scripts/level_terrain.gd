@tool
class_name LevelTerrain
extends Node3D
## Builds a level's ground from a greyscale height image painted in Photoshop
## (or any paint program): black = lowest, white = `max_height`. It builds in
## the editor too, and rebuilds by itself when the image file is saved.
##
## The ground is centred on this node. Row 0 of the image (its top edge) is
## the far side of the level (-Z). Nothing generated here is saved into the
## scene: the image is the only thing to edit.
##
## Note: Godot 4.6 reads 16-bit PNGs as 8-bit, so heights come in 256 steps
## (12 cm each at 30 m max height). `smoothing` softens those steps.

## Group the level's terrain joins, so the player rig and Tab panel can find it.
const GROUP: StringName = &"level_terrain"

const GROUND_SHADER: Shader = preload("res://art/checker_ground.gdshader")

## Seconds to wait after the last setting change before rebuilding.
const REBUILD_DELAY: float = 0.4

## The height image (PNG). Black = 0 m, white = max_height.
@export_file("*.png") var height_image_path: String = "":
	set(value):
		height_image_path = value
		_queue_rebuild()

## Size of one pixel on the ground, in metres. 1 = a 256 px image is 256 m across.
@export_range(0.25, 8.0, 0.25) var metres_per_pixel: float = 1.0:
	set(value):
		metres_per_pixel = value
		_queue_rebuild()

## Height of pure white, in metres.
@export_range(1.0, 200.0, 0.5) var max_height: float = 30.0:
	set(value):
		max_height = value
		_queue_rebuild()

## How many times the heights are softened (each pass blends every point with
## its neighbours). 0 = exactly as painted. 1 to 3 hides the 8-bit steps.
@export_range(0, 10) var smoothing: int = 2:
	set(value):
		smoothing = value
		_queue_rebuild()

## Rebuild now (the ground also rebuilds by itself when the image is saved).
@export_tool_button("Rebuild") var rebuild_action: Callable = rebuild

## Emitted after every rebuild, so the start point can sit on the new ground.
signal rebuilt

var _heights := PackedFloat32Array()
var _width: int = 0
var _depth: int = 0
var _body: StaticBody3D
var _image_modified_time: int = 0
var _seconds_since_check: float = 0.0
# Seconds left before a rebuild after a setting changed (-1 = none waiting).
var _rebuild_countdown: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	rebuild()


func _process(delta: float) -> void:
	if _rebuild_countdown >= 0.0:
		_rebuild_countdown -= delta
		if _rebuild_countdown < 0.0:
			rebuild()
	# In the editor: notice when the image is saved from Photoshop.
	if Engine.is_editor_hint():
		_seconds_since_check += delta
		if _seconds_since_check >= 1.0:
			_seconds_since_check = 0.0
			if _image_file_time() != _image_modified_time:
				rebuild()


## Build (or rebuild) the ground from the height image.
func rebuild() -> void:
	if not is_inside_tree():
		return
	_rebuild_countdown = -1.0
	_image_modified_time = _image_file_time()
	var image: Image = _load_height_image()
	if image == null:
		return
	build_from_image(image)


## Build the ground from an image already in memory (the tests use this).
func build_from_image(image: Image) -> void:
	_width = image.get_width()
	_depth = image.get_height()
	_heights = _read_heights(image)
	for i: int in smoothing:
		_heights = _smoothed(_heights)
	if _body != null:
		_body.queue_free()
	_body = StaticBody3D.new()
	_body.name = "Ground"
	add_child(_body)
	_body.add_child(_make_collision())
	_body.add_child(_make_visual())
	rebuilt.emit()


## Ground height in metres at a world position (between pixels it blends
## the four nearest). Outside the image it uses the nearest edge.
func height_at(world_position: Vector3) -> float:
	if _heights.is_empty():
		return global_position.y
	var local: Vector3 = to_local(world_position)
	var px: float = clampf(local.x / metres_per_pixel + (_width - 1) / 2.0, 0.0, _width - 1.0)
	var pz: float = clampf(local.z / metres_per_pixel + (_depth - 1) / 2.0, 0.0, _depth - 1.0)
	var x0: int = floori(px)
	var z0: int = floori(pz)
	var x1: int = mini(x0 + 1, _width - 1)
	var z1: int = mini(z0 + 1, _depth - 1)
	var fx: float = px - x0
	var fz: float = pz - z0
	var top: float = lerpf(_height(x0, z0), _height(x1, z0), fx)
	var bottom: float = lerpf(_height(x0, z1), _height(x1, z1), fx)
	return global_position.y + lerpf(top, bottom, fz)


## Size of the level on the ground, in metres (X and Z).
func ground_size() -> Vector2:
	return Vector2((_width - 1) * metres_per_pixel, (_depth - 1) * metres_per_pixel)


func _load_height_image() -> Image:
	if height_image_path.is_empty():
		return null
	# Read the raw file, not Godot's imported texture, which may be compressed.
	var image := Image.load_from_file(ProjectSettings.globalize_path(height_image_path))
	if image == null:
		push_error("LevelTerrain: cannot read %s" % height_image_path)
	return image


func _image_file_time() -> int:
	if height_image_path.is_empty() or not FileAccess.file_exists(height_image_path):
		return 0
	return FileAccess.get_modified_time(height_image_path)


func _read_heights(image: Image) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(_width * _depth)
	for z: int in _depth:
		for x: int in _width:
			# Brightness, so a colour image still works (grey is what's intended).
			heights[z * _width + x] = image.get_pixel(x, z).get_luminance() * max_height
	return heights


## One softening pass: each point becomes the average of itself and its
## neighbours (a 3 x 3 blur).
func _smoothed(heights: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(heights.size())
	for z: int in _depth:
		for x: int in _width:
			var total: float = 0.0
			var count: int = 0
			for dz: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx: int = x + dx
					var nz: int = z + dz
					if nx >= 0 and nx < _width and nz >= 0 and nz < _depth:
						total += heights[nz * _width + nx]
						count += 1
			result[z * _width + x] = total / count
	return result


func _height(x: int, z: int) -> float:
	return _heights[z * _width + x]


func _make_collision() -> CollisionShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = _width
	shape.map_depth = _depth
	# A height map's points are always 1 unit apart, so the whole shape is
	# scaled evenly by metres_per_pixel (even scaling is safe for physics),
	# with the heights divided by the same amount to keep them right.
	var scaled := PackedFloat32Array()
	scaled.resize(_heights.size())
	for i: int in _heights.size():
		scaled[i] = _heights[i] / metres_per_pixel
	shape.map_data = scaled
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.scale = Vector3.ONE * metres_per_pixel
	return collision


func _make_visual() -> MeshInstance3D:
	var half_x: float = (_width - 1) / 2.0
	var half_z: float = (_depth - 1) / 2.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in _depth:
		for x: int in _width:
			tool.add_vertex(Vector3((x - half_x) * metres_per_pixel, _height(x, z), (z - half_z) * metres_per_pixel))
	for z: int in _depth - 1:
		for x: int in _width - 1:
			var a: int = z * _width + x
			var b: int = a + 1
			var c: int = a + _width
			var d: int = c + 1
			# Clockwise when seen from above, which Godot treats as the front.
			tool.add_index(a)
			tool.add_index(b)
			tool.add_index(c)
			tool.add_index(b)
			tool.add_index(d)
			tool.add_index(c)
	tool.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = tool.commit()
	visual.material_override = material
	return visual


## Rebuild shortly after the last change. Dragging a slider changes a setting
## many times a second, and a rebuild takes a moment, so wait until it settles.
func _queue_rebuild() -> void:
	_rebuild_countdown = REBUILD_DELAY
