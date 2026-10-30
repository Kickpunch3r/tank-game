extends SceneTree
## Generates levels/proving_ground/height.png and terrain.png from the plan in
## levels/proving_ground/proving_ground_layout.gd. After this, the images are
## meant to be edited by hand in Photoshop; running this again overwrites them.
##
## Run: <godot console exe> --headless --path . --script res://tools/generate_proving_ground.gd

const FOLDER: String = "res://levels/proving_ground"
const LAYOUT_SCRIPT: GDScript = preload("res://levels/proving_ground/proving_ground_layout.gd")


func _initialize() -> void:
	var layout: RefCounted = LAYOUT_SCRIPT.new()
	var width: int = LAYOUT_SCRIPT.WIDTH
	var depth: int = LAYOUT_SCRIPT.DEPTH
	var heights := Image.create(width, depth, false, Image.FORMAT_L8)
	var terrain := Image.create(width, depth, false, Image.FORMAT_RGB8)
	# Terrain map colours: the paint_colour of terrain/mud.tres and sand.tres.
	var paint: Dictionary = {"mud": Color(1, 0, 0), "sand": Color(1, 1, 0), "": Color(0.25, 0.25, 0.25)}
	for z: int in depth:
		for x: int in width:
			var world_x: float = x - (width - 1) / 2.0
			var world_z: float = z - (depth - 1) / 2.0
			var metres: float = layout.height_at(world_x, world_z)
			var grey: float = roundf(metres / LAYOUT_SCRIPT.MAX_HEIGHT * 255.0) / 255.0
			heights.set_pixel(x, z, Color(grey, grey, grey))
			terrain.set_pixel(x, z, paint[layout.terrain_at(world_x, world_z)])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	for item: Array in [[heights, "height.png"], [terrain, "terrain.png"]]:
		var path: String = FOLDER + "/" + item[1]
		var error: Error = (item[0] as Image).save_png(ProjectSettings.globalize_path(path))
		print("Saved %s (%s)" % [path, error_string(error)])
	_print_route_grades(layout)
	quit()


## The steepest stretch of each route, measured on the painted heights
## (over 4 m), so it's easy to check the tank can drive them.
func _print_route_grades(layout: RefCounted) -> void:
	for high: bool in [true, false]:
		var points: Array[Vector2] = layout.route_points(high)
		var steepest: float = 0.0
		for index: int in points.size() - 1:
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var steps: int = maxi(1, int(a.distance_to(b) / 4.0))
			for step: int in steps:
				var p: Vector2 = a.lerp(b, float(step) / steps)
				var q: Vector2 = a.lerp(b, float(step + 1) / steps)
				var rise: float = layout.height_at(q.x, q.y) - layout.height_at(p.x, p.y)
				steepest = maxf(steepest, rad_to_deg(atan(absf(rise) / p.distance_to(q))))
		print("%s route: steepest stretch %.1f°" % ["High" if high else "Low", steepest])
