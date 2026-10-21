class_name RollingBumps
extends Node3D
## Builds a patch of gentle rolling hills for free driving, centred on this node.
## The hills are made of overlapping waves and fade to flat at the edges, so
## they join the surrounding ground smoothly.

const GROUND_SHADER: Shader = preload("res://art/checker_ground.gdshader")

## Size of the patch along X and Z, in metres. Rounded to whole metres.
@export var patch_size: int = 60

## Height of the tallest hills, in metres.
@export var hill_height: float = 2.0

## Distance from one hilltop to the next, in metres. Shorter = steeper.
@export var hill_spacing: float = 14.0


func _ready() -> void:
	var heights: PackedFloat32Array = _make_heights()
	var body := StaticBody3D.new()
	body.name = "Bumps"
	add_child(body)
	body.add_child(_make_collision(heights))
	body.add_child(_make_visual(heights))


## Height at every whole-metre grid point, row by row along Z.
func _make_heights() -> PackedFloat32Array:
	var points: int = patch_size + 1
	var heights := PackedFloat32Array()
	heights.resize(points * points)
	var wave: float = TAU / hill_spacing
	for row: int in points:
		for column: int in points:
			var x: float = column
			var z: float = row
			# 0 at the patch edges, 1 in the middle, so the hills fade out.
			var fade: float = sin(PI * x / patch_size) * sin(PI * z / patch_size)
			# Two crossing waves, kept between 0 and 1 so nothing dips below the ground.
			var waves: float = 0.5 + 0.25 * sin(wave * x) + 0.25 * sin(wave * 0.8 * z + 1.0)
			heights[row * points + column] = hill_height * fade * waves
	return heights


func _make_collision(heights: PackedFloat32Array) -> CollisionShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = patch_size + 1
	shape.map_depth = patch_size + 1
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	return collision


## A mesh with the same grid points as the collision, so what you see is
## exactly what the tank drives on.
func _make_visual(heights: PackedFloat32Array) -> MeshInstance3D:
	var points: int = patch_size + 1
	var half: float = patch_size / 2.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in points:
		for column: int in points:
			tool.add_vertex(Vector3(column - half, heights[row * points + column], row - half))
	for row: int in patch_size:
		for column: int in patch_size:
			var a: int = row * points + column
			var b: int = a + 1
			var c: int = a + points
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
	material.set_shader_parameter(&"color_a", Color(0.62, 0.66, 0.42))
	material.set_shader_parameter(&"color_b", Color(0.55, 0.59, 0.37))
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = tool.commit()
	visual.material_override = material
	return visual
