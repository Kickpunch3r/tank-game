class_name CourseBuilder
extends Node3D
## Builds the test course's flat ground, boundary walls and kill-plane when the
## scene starts. The ramps (SlopeLadder) and hills (RollingBumps) are separate
## nodes with their own builders. Building from code keeps sizes exact and
## easy to change.

const GROUND_SHADER: Shader = preload("res://art/checker_ground.gdshader")

## Width (X) and length (Z) of the flat ground, centred on this node, in metres.
@export var ground_size: Vector2 = Vector2(300.0, 300.0)

## How thick the ground slab is, in metres. Thick so nothing tunnels through it.
@export var ground_thickness: float = 2.0

## Height of the walls around the edge of the ground, in metres.
@export var wall_height: float = 3.0

## Anything that falls this far below the ground is sent back to the start, in metres.
@export var kill_plane_depth: float = 20.0


func _ready() -> void:
	_build_ground()
	_build_walls()
	_build_kill_plane()


func _build_ground() -> void:
	var size := Vector3(ground_size.x, ground_thickness, ground_size.y)
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	# Top surface sits at y = 0.
	_add_box("Ground", size, Vector3(0.0, -ground_thickness / 2.0, 0.0), material)


func _build_walls() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.42, 0.38)
	var thickness: float = 1.0
	var half_x: float = ground_size.x / 2.0
	var half_z: float = ground_size.y / 2.0
	var y: float = wall_height / 2.0
	var long_x := Vector3(ground_size.x, wall_height, thickness)
	var long_z := Vector3(thickness, wall_height, ground_size.y)
	_add_box("WallNorth", long_x, Vector3(0.0, y, -half_z), material)
	_add_box("WallSouth", long_x, Vector3(0.0, y, half_z), material)
	_add_box("WallWest", long_z, Vector3(-half_x, y, 0.0), material)
	_add_box("WallEast", long_z, Vector3(half_x, y, 0.0), material)


## A flat trigger far below the ground. A tank that touches it goes back to the start.
func _build_kill_plane() -> void:
	var area := Area3D.new()
	area.name = "KillPlane"
	area.position = Vector3(0.0, -kill_plane_depth, 0.0)
	var shape := BoxShape3D.new()
	# Much bigger than the ground, so nothing can fall past its edges.
	shape.size = Vector3(ground_size.x * 4.0, 2.0, ground_size.y * 4.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_kill_plane_body_entered)
	add_child(area)


func _on_kill_plane_body_entered(body: Node3D) -> void:
	if body is Tank:
		# Deferred: moving a body in the middle of a physics callback is unsafe.
		(body as Tank).reset_to_spawn.call_deferred()


## A solid box you can see and collide with.
func _add_box(box_name: String, size: Vector3, where: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = where
	add_child(body)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	body.add_child(visual)
