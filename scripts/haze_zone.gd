class_name HazeZone
extends Node3D
## An area that is always misty (the Proving Ground's pine forest). Put it in
## the middle of the area, on the ground, and set its size.
##
## - From outside, soft mist sheets hang among the trees, so it looks misty.
## - When the camera is inside, the level's fog thickens, easing in over
##   `edge` metres at the border, and thins again as you leave.
## It is always misty, even with the Tab panel's Haze switched off (that
## switch only affects the haze over the rest of the level).

## Width (X) and length (Z) of the area, in metres.
@export var size: Vector2 = Vector2(100.0, 70.0)

## How high the mist sheets reach, in metres above this node.
@export var height: float = 12.0

## Fog density with the camera well inside (the level's normal haze is about 0.001).
@export var inside_density: float = 0.03

## Over how many metres the fog thickens at the border.
@export var edge: float = 20.0

## How many mist sheets hang in the area.
@export var mist_sheets: int = 28

const MIST_SHADER: Shader = preload("res://art/mist.gdshader")

var _environment: Environment
var _outside_density: float = 0.0


func _ready() -> void:
	for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_environment = (node as WorldEnvironment).environment
		break
	if _environment != null:
		_outside_density = _environment.fog_density
	_build_mist()


func _process(_delta: float) -> void:
	if _environment == null:
		return
	var inside: float = camera_inside_amount()
	var outside_density: float = _outside_density if GraphicsOptions.haze else 0.0
	_environment.fog_enabled = GraphicsOptions.haze or inside > 0.001
	_environment.fog_density = lerpf(outside_density, inside_density, inside)


## How far inside the area the camera is: 0 = outside, 1 = well inside.
func camera_inside_amount() -> float:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var local: Vector3 = to_local(camera.global_position)
	var inside: float = minf(size.x / 2.0 - absf(local.x), size.y / 2.0 - absf(local.z))
	return smoothstep(-edge * 0.5, edge * 0.5, inside)


func _build_mist() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = mist_sheets
	for index: int in mist_sheets:
		var sheet_size := Vector2(random.randf_range(22.0, 34.0), random.randf_range(8.0, height))
		var where := Vector3(random.randf_range(-0.5, 0.5) * size.x, sheet_size.y * 0.45,
				random.randf_range(-0.5, 0.5) * size.y)
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3(sheet_size.x, sheet_size.y, 1.0)), where))
	var material := ShaderMaterial.new()
	material.shader = MIST_SHADER
	var mist := MultiMeshInstance3D.new()
	mist.name = "Mist"
	mist.multimesh = multimesh
	mist.material_override = material
	# The sheets turn to face the camera in the shader, so don't let Godot
	# skip them for being out of view by their unturned size.
	mist.custom_aabb = AABB(Vector3(-size.x, -5.0, -size.y), Vector3(size.x * 2.0, height + 10.0, size.y * 2.0))
	add_child(mist)
