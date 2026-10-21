class_name CourseBuilder
extends Node3D
## Builds the test course's ground (and, from milestone 4, the ramps) when the
## scene starts. Building from code keeps sizes and angles exact and easy to change.

const GROUND_MATERIAL_SHADER: Shader = preload("res://art/checker_ground.gdshader")

## Width (X) and length (Z) of the flat ground, in metres.
@export var ground_size: Vector2 = Vector2(200.0, 200.0)

## How thick the ground slab is, in metres. Thick so nothing tunnels through it.
@export var ground_thickness: float = 2.0


func _ready() -> void:
	_build_ground()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	# Top surface sits at y = 0.
	body.position = Vector3(0.0, -ground_thickness / 2.0, 0.0)
	add_child(body)

	var size := Vector3(ground_size.x, ground_thickness, ground_size.y)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	var material := ShaderMaterial.new()
	material.shader = GROUND_MATERIAL_SHADER
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	body.add_child(visual)
