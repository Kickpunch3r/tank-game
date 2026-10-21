extends SceneTree
## Generates levels/starter/height.png: a 256 x 256 starter level showing a
## variety of ground in different areas. After this, the image is meant to be
## edited by hand in Photoshop; running this again overwrites it.
##
## Run: <godot console exe> --headless --path . --script res://tools/generate_starter_heightmap.gd
##
## Map (top of image = north = -Z in the game; 1 pixel = 1 m by default):
##   - Rim: painted mountains all round the edge (the level's boundary).
##   - South centre: flat start area, with a flat strip running north toward the mesa
##     (a road later).
##   - North-west: a long steep ridge with a lower pass through the middle.
##   - North-east: gentle rolling hills.
##   - North centre: a mesa (flat-topped hill) with a different steepness on each side:
##     north 15°, east 25°, west 35°, south a sheer cliff.
##   - West: a shallow basin (a mud pond later).
##   - South-east: rippled dunes (sand later).

const SIZE: int = 256
## Must match the level's LevelTerrain max_height for the heights below to be in metres.
const MAX_HEIGHT: float = 30.0
const BASE: float = 2.0
const OUTPUT: String = "res://levels/starter/height.png"

var noise := FastNoiseLite.new()


func _initialize() -> void:
	noise.seed = 7
	noise.frequency = 0.05
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for z: int in SIZE:
		for x: int in SIZE:
			var metres: float = height_at(float(x), float(z))
			image.set_pixel(x, z, Color.from_hsv(0.0, 0.0, clampf(metres / MAX_HEIGHT, 0.0, 1.0)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/starter"))
	var error: Error = image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("Saved %s (%s)" % [OUTPUT, error_string(error)])
	quit()


func height_at(x: float, z: float) -> float:
	var h: float = BASE
	h += _rolling_hills(x, z)
	h += _ridge_with_pass(x, z)
	h += _dunes(x, z)
	h -= _basin(x, z)
	h = maxf(h, _mesa(x, z))
	# Flat start area and the strip running north from it.
	var flat: float = maxf(_disc(x, z, Vector2(128, 222), 18.0, 8.0), _strip(x, z))
	h = lerpf(h, BASE, flat)
	h = maxf(h, _mountain_rim(x, z))
	return h


## Mountains rising toward every edge, rugged with noise.
func _mountain_rim(x: float, z: float) -> float:
	var to_edge: float = minf(minf(x, SIZE - 1 - x), minf(z, SIZE - 1 - z))
	var rise: float = smoothstep(26.0, 2.0, to_edge)
	return BASE + rise * (24.0 + 5.0 * noise.get_noise_2d(x, z))


func _rolling_hills(x: float, z: float) -> float:
	var area: float = _box(x, z, Rect2(160, 30, 70, 75), 14.0)
	return area * (2.5 + 2.5 * sin(x * 0.12) * sin(z * 0.1 + 1.0))


## A ridge running north-south (about 35° sides) with a pass dropping to 6 m.
func _ridge_with_pass(x: float, z: float) -> float:
	# Tapers off over 20 px at its north and south ends.
	var area: float = _box(x, z, Rect2(25, 45, 70, 50), 20.0)
	var across: float = absf(x - 60.0)
	var ridge: float = maxf(0.0, 18.0 - across * tan(deg_to_rad(35.0)))
	var pass_dip: float = 12.0 * _bump(z, 70.0, 10.0)
	return area * maxf(0.0, ridge - pass_dip)


## Ripples like wind-blown dunes: gentle on one side, steeper on the other.
func _dunes(x: float, z: float) -> float:
	var area: float = _box(x, z, Rect2(158, 140, 72, 65), 12.0)
	var phase: float = fposmod((x + z * 0.4) / 16.0, 1.0)
	var ripple: float = phase / 0.75 if phase < 0.75 else (1.0 - phase) / 0.25
	return area * 3.0 * ripple


func _basin(x: float, z: float) -> float:
	return 2.0 * _disc(x, z, Vector2(62, 165), 24.0, 14.0)


## Flat top 10 m high; each side has its own steepness.
func _mesa(x: float, z: float) -> float:
	var centre := Vector2(128, 78)
	var offset := Vector2(x, z) - centre
	var top_radius: float = 14.0
	var beyond: float = offset.length() - top_radius
	if beyond <= 0.0:
		return BASE + 10.0
	# Which side: north is -Z (up the image).
	var side_angle: float
	if absf(offset.y) > absf(offset.x):
		side_angle = 15.0 if offset.y < 0.0 else 85.0
	else:
		side_angle = 25.0 if offset.x > 0.0 else 35.0
	return BASE + maxf(0.0, 10.0 - beyond * tan(deg_to_rad(side_angle)))


func _strip(x: float, z: float) -> float:
	return _box(x, z, Rect2(122, 125, 12, 100), 3.0)


# --- Shape helpers: 1 inside, fading to 0 over `soft` pixels outside --------

func _box(x: float, z: float, rect: Rect2, soft: float) -> float:
	var dx: float = maxf(rect.position.x - x, x - rect.end.x)
	var dz: float = maxf(rect.position.y - z, z - rect.end.y)
	return smoothstep(soft, 0.0, maxf(maxf(dx, dz), 0.0))


func _disc(x: float, z: float, centre: Vector2, radius: float, soft: float) -> float:
	return smoothstep(radius + soft, radius, Vector2(x, z).distance_to(centre))


func _bump(value: float, centre: float, width: float) -> float:
	return smoothstep(width, 0.0, absf(value - centre))
