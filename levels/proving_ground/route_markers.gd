class_name RouteMarkers
extends Node3D
## Marks the Proving Ground's routes on the ground: a short post on each side
## of the path every few metres (orange for the high route, blue for the low
## route, white for the road).
## Built from the level's plan (ProvingGroundLayout) when the ground is built,
## and again whenever it is rebuilt.

## The level's ground, for the height under each post.
@export var level_terrain: LevelTerrain

## Distance between posts along a path, in metres.
@export var spacing: float = 14.0

const HIGH_COLOUR := Color(1.0, 0.55, 0.1)
const LOW_COLOUR := Color(0.2, 0.55, 1.0)
const ROAD_COLOUR := Color(0.95, 0.95, 0.95)


func _ready() -> void:
	if level_terrain != null:
		level_terrain.rebuilt.connect(_build)
		_build()


func _build() -> void:
	for child: Node in get_children():
		child.queue_free()
	_mark_route(ProvingGroundLayout.ROAD, ROAD_COLOUR, ProvingGroundLayout.PATH_WIDTH)
	_mark_route(ProvingGroundLayout.HIGH_ROUTE, HIGH_COLOUR, ProvingGroundLayout.PATH_WIDTH)
	_mark_route(ProvingGroundLayout.LOW_ROUTE, LOW_COLOUR, ProvingGroundLayout.PATH_WIDTH)


## Posts on both sides of a route.
func _mark_route(route: Array[Vector3], colour: Color, width: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour * 0.3
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.15
	mesh.bottom_radius = 0.15
	mesh.height = 1.4
	mesh.material = material
	for index: int in route.size() - 1:
		var a := Vector2(route[index].x, route[index].y)
		var b := Vector2(route[index + 1].x, route[index + 1].y)
		var direction: Vector2 = (b - a).normalized()
		var side := Vector2(-direction.y, direction.x) * (width / 2.0 + 1.0)
		var count: int = maxi(1, int(a.distance_to(b) / spacing))
		for step: int in count:
			var at: Vector2 = a.lerp(b, (step + 0.5) / count)
			for offset: Vector2 in [side, -side]:
				var post := MeshInstance3D.new()
				post.mesh = mesh
				var where: Vector2 = at + offset
				post.position = Vector3(where.x, _ground(where) + 0.7, where.y)
				add_child(post)


func _ground(where: Vector2) -> float:
	return level_terrain.height_at(Vector3(where.x, 0.0, where.y))
