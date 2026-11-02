class_name ProvingGroundScenery
extends Node3D
## Dresses the Proving Ground from its plan (ProvingGroundLayout.scenery()):
## the misty forest's pines, big rocks, boulders, small rocks and the lake's
## buoys. Also watches for deep water: a tank in water deeper than
## ProvingGroundLayout.DEEP_WATER_DEPTH is sent back to the start.
##
## Each kind of thing is one MultiMesh (drawn in one go, so it is cheap).
## Pine trunks and rocks are solid (small rocks too: you can drive over them);
## pine branches are not. Rebuilt whenever the ground is rebuilt, so
## everything sits on it.

## The level's ground, for the height under each thing.
@export var level_terrain: LevelTerrain

## Emitted when the deep water sends a tank back to the start.
signal sent_back_to_start(tank: Node3D)

var layout := ProvingGroundLayout.new()
var _rock_points := PackedVector3Array()


func _ready() -> void:
	if level_terrain != null:
		level_terrain.rebuilt.connect(_build)
		_build()


func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var items: Dictionary = layout.scenery()
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)
	_build_pines(items.pines, solid)
	for kind: String in ["big_rocks", "boulders", "small_rocks"]:
		_build_rocks(kind, items[kind], solid)
	_build_buoys(items.buoys)


# --- Pines ----------------------------------------------------------------------

func _build_pines(pines: Array, solid: StaticBody3D) -> void:
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.0
	canopy.bottom_radius = 1.0
	canopy.height = 1.0
	canopy.radial_segments = 7
	canopy.rings = 1
	var canopies: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var colours: Array[Color] = []
	for pine: Dictionary in pines:
		var ground: float = _ground(pine.at)
		var height: float = pine.height
		var radius: float = pine.radius
		# Canopy over the top 80%, trunk showing below.
		canopies.append(Transform3D(Basis.from_scale(Vector3(radius, height * 0.8, radius)),
				Vector3(pine.at.x, ground + height * 0.6, pine.at.y)))
		trunks.append(_trunk(pine.at, ground, height * 0.3, radius * 0.14))
		colours.append(Color(0.13, 0.3, 0.16).lightened(randf_range(-0.1, 0.15)))
		# Only the trunk is solid (the branches above are not).
		_add_cylinder(solid, pine.at, ground, height, radius * 0.14)
	_add_multimesh("Pines", canopy, canopies, colours)
	_add_multimesh("PineTrunks", _trunk_mesh(), trunks, _same_colour(trunks.size(), Color(0.33, 0.24, 0.16)))


func _trunk(at: Vector2, ground: float, height: float, radius: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(radius, height, radius)), Vector3(at.x, ground + height / 2.0, at.y))


func _trunk_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


## A solid upright cylinder (a tree you can't drive through).
func _add_cylinder(solid: StaticBody3D, at: Vector2, ground: float, height: float, radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(at.x, ground + height / 2.0, at.y)
	solid.add_child(collision)


# --- Rocks -----------------------------------------------------------------------

## Low-poly rocks, partly sunk into the ground, each with a matching solid shape.
func _build_rocks(kind: String, rocks: Array, solid: StaticBody3D) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	if _rock_points.is_empty():
		_rock_points = mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
	var transforms: Array[Transform3D] = []
	var colours: Array[Color] = []
	for rock: Dictionary in rocks:
		var size: Vector3 = rock.size
		var where := Transform3D(Basis(Vector3.UP, rock.turn).scaled_local(size),
				Vector3(rock.at.x, _ground(rock.at) + size.y * 0.35, rock.at.y))
		transforms.append(where)
		colours.append(Color(0.47, 0.44, 0.4).lightened(randf_range(-0.12, 0.1)))
		# The rock's size and turn are baked into the shape's points: Godot's
		# physics doesn't support stretching a shape unevenly.
		var points := PackedVector3Array()
		for point: Vector3 in _rock_points:
			points.append(where.basis * point)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = where.origin
		solid.add_child(collision)
	_add_multimesh(kind.to_pascal_case(), mesh, transforms, colours)


# --- The lake ----------------------------------------------------------------------

func _build_buoys(buoys: Array) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var transforms: Array[Transform3D] = []
	for buoy: Dictionary in buoys:
		transforms.append(Transform3D(Basis.IDENTITY, Vector3(buoy.at.x, ProvingGroundLayout.WATER_LEVEL + 0.2, buoy.at.y)))
	var node: MultiMeshInstance3D = _add_multimesh("Buoys", mesh, transforms, _same_colour(transforms.size(), Color(1.0, 0.45, 0.1)))
	(node.material_override as StandardMaterial3D).emission_enabled = true
	(node.material_override as StandardMaterial3D).emission = Color(1.0, 0.4, 0.05) * 0.4


## A tank in deep water (the lake past its buoys, or the river's channel) is
## sent back to the level's start.
func _physics_process(_delta: float) -> void:
	# The level adds its PlayerRig when it starts, beside this node.
	var rig := get_parent().get_node_or_null(^"PlayerRig") as PlayerRig
	if rig == null or level_terrain == null:
		return
	var tank: Node3D = rig.active_tank
	if is_instance_valid(tank) and is_in_deep_water(tank.global_position):
		send_back_to_start(tank)


## Is this spot in water deeper than ProvingGroundLayout.DEEP_WATER_DEPTH?
func is_in_deep_water(where: Vector3) -> bool:
	var water: float = ProvingGroundLayout.WATER_LEVEL
	return where.y < water and water - level_terrain.height_at(Vector3(where.x, 0.0, where.z)) > ProvingGroundLayout.DEEP_WATER_DEPTH


func send_back_to_start(tank: Node3D) -> void:
	tank.call(&"place_at", tank.call(&"get_home"))
	var keyboard := tank.get_node_or_null(^"DriverStation/KeyboardDriverInput") as KeyboardDriverInput
	if keyboard != null:
		keyboard.clear_levels()
	sent_back_to_start.emit(tank)


# --- Helpers -----------------------------------------------------------------------

func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colours: Array[Color]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colours[index])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.material_override = material
	add_child(node)
	return node


func _same_colour(count: int, colour: Color) -> Array[Color]:
	var colours: Array[Color] = []
	colours.resize(count)
	colours.fill(colour)
	return colours


func _ground(at: Vector2) -> float:
	return level_terrain.height_at(Vector3(at.x, 0.0, at.y))
