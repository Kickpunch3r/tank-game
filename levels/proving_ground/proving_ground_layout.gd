class_name ProvingGroundLayout
extends RefCounted
## The plan of the Proving Ground level, in one place: where everything is,
## how high the ground is, and what terrain it has. The generator
## (tools/generate_proving_ground.gd) paints height.png and terrain.png from
## it, and the tests use the same routes to drive the tank through the level.
##
## After generating, the images can be edited by hand in Photoshop; this plan
## then only describes the original layout.
##
## Coordinates are world metres with the level's middle at (0, 0); north = -Z
## (the top of the images). 1 pixel = 1 m.
##
## Layout:
## - Spawn (south, a little west of the middle), facing north up a short road to a fork.
## - Test area (east of the spawn): the ramp row (5°-55°), the ledge strip,
##   steps and crest, and a mud and a sand square, all on flat ground.
## - High route (west): climbs onto a ridge, runs along a sandy ledge above a
##   cliff and a lake, then comes down to the goal plateau.
## - Low route (middle): through a mud basin, across the river at a shallow
##   muddy ford, over sand dunes, then up to the goal plateau.
## - Goal plateau (north): where both routes meet; steep sides elsewhere.
## - Impassable: the mountain rim, the ridge's cliff, the river's steep banks,
##   a steep cone hill and a cliff-sided mesa.
## - Dressing (2026-10-31): a dune sea (south-west), a big lake the river runs
##   into (too deep = back to the start), big rocks along the high road, a
##   misty pine forest (north-east), a boulder field, small rocks to drive
##   over, and scattered trees and bushes. See scenery().

## Image size in pixels (= metres).
const WIDTH: int = 448
const DEPTH: int = 384
## Height of pure white in the height image, in metres. 51 makes each of the
## 255 grey steps exactly 0.2 m, so flat areas come out at exact heights.
const MAX_HEIGHT: float = 51.0

## Ordinary ground height, and the water surface.
const BASE: float = 4.0
const WATER_LEVEL: float = 2.6
## River and lake bed, and the ford's bed (just under the water).
const RIVER_BED: float = 0.4
const FORD_BED: float = 2.2

const SPAWN := Vector2(-10.0, 150.0)
const FORK := Vector2(-10.0, 70.0)
const GOAL := Vector2(-40.0, -145.0)
const GOAL_HEIGHT: float = 12.0
const GOAL_RADIUS: float = 24.0
const FORD := Vector2(-10.0, -55.0)

## The flat test area east of the spawn: x from, x to, z from, z to.
const TEST_AREA := Rect2(30.0, -42.0, 168.0, 210.0)
## Where the ramp row's base line and the comparison features sit.
const RAMPS_AT := Vector2(110.0, 120.0)
const RAMPS_RUN_UP: float = 45.0
const FEATURES_AT := Vector2(110.0, 10.0)
## Test squares of mud and sand in the test area (centre, half size).
const TEST_MUD := Vector2(45.0, 60.0)
const TEST_SAND := Vector2(45.0, 28.0)
const TEST_SQUARE_HALF: float = 8.0

## Routes: points (x, z, path height). Path width in metres.
const ROAD: Array[Vector3] = [Vector3(-10.0, 150.0, 4.0), Vector3(-10.0, 70.0, 4.0)]
const HIGH_ROUTE: Array[Vector3] = [
	Vector3(-10.0, 70.0, 4.0), Vector3(-70.0, 50.0, 6.0), Vector3(-130.0, 30.0, 10.0), Vector3(-160.0, -8.0, 18.0),
	Vector3(-160.0, -72.0, 18.0), Vector3(-128.0, -112.0, 16.0), Vector3(-90.0, -136.0, 12.0),
	Vector3(-40.0, -145.0, 12.0),
]
const LOW_ROUTE: Array[Vector3] = [
	Vector3(-10.0, 70.0, 4.0), Vector3(-25.0, 25.0, 3.6), Vector3(-25.0, -15.0, 3.2),
	Vector3(-14.0, -40.0, 3.0), Vector3(-10.0, -55.0, 2.2), Vector3(-6.0, -70.0, 3.2),
	Vector3(-5.0, -104.0, 5.0), Vector3(-18.0, -128.0, 12.0), Vector3(-40.0, -145.0, 12.0),
]
const PATH_WIDTH: float = 10.0
## The ridge ledge (part of the high route) is narrower, with a cliff beside it.
const LEDGE_WIDTH: float = 7.0
## How far the ground eases from a path back to the land around it.
const PATH_SHOULDER: float = 9.0

## The river: points (x, z), from the north-east mountains to the lake.
const RIVER: Array[Vector2] = [
	Vector2(205.0, -105.0), Vector2(140.0, -75.0), Vector2(60.0, -58.0),
	Vector2(-10.0, -55.0), Vector2(-60.0, -45.0), Vector2(-105.0, -32.0),
]
const RIVER_HALF_WIDTH: float = 7.0
## The lake the river runs into: deepest inside LAKE_RADIUS, its bed shelving
## gently up to normal ground at LAKE_SHORE (so you can drive in), and deeper
## than DEEP_WATER_RADIUS sends the tank back to the start.
const LAKE := Vector2(-100.0, -25.0)
const LAKE_RADIUS: float = 24.0
const LAKE_SHORE: float = 42.0
const DEEP_WATER_RADIUS: float = 29.0
## Within this distance of the ford, the river banks are gentle.
const FORD_REACH: float = 16.0

## The ridge the high route runs along: west of this x, between these z.
const RIDGE_EAST_EDGE: float = -152.0
const RIDGE_Z_FROM: float = -105.0
const RIDGE_Z_TO: float = 15.0
const RIDGE_HEIGHT: float = 18.0

## Impassable hills: a steep cone and a cliff-sided mesa.
const CONE := Vector2(-85.0, -92.0)
const CONE_HEIGHT: float = 22.0
const CONE_SLOPE_DEGREES: float = 55.0
const MESA := Vector2(70.0, -135.0)
const MESA_RADIUS: float = 26.0
const MESA_HEIGHT: float = 16.0

## Mud basin on the low route, and sand dunes.
const MUD_BASIN := Vector2(-28.0, -12.0)
const MUD_BASIN_RADIUS: float = 22.0
const DUNES := Rect2(-38.0, -98.0, 66.0, 26.0)

## Width of the mountain rim, from the edge inward.
const RIM: float = 24.0

## The dune sea: big sand dunes filling the south-west.
const DUNE_SEA := Rect2(-198.0, 90.0, 152.0, 78.0)
const DUNE_SEA_HEIGHT: float = 2.6
## The misty pine forest (north-east), and the boulder field near the cone.
const FOREST := Rect2(106.0, -166.0, 90.0, 58.0)
## Kept clear of scenery: the flat run-up east of the cone.
const CONE_RUN_UP := Rect2(-85.0, -98.0, 55.0, 12.0)
const BOULDER_FIELD := Vector2(-55.0, -108.0)
const BOULDER_FIELD_RADIUS: float = 13.0
## A patch of small rocks to drive over, in the test area.
const RUBBLE := Vector2(40.0, 100.0)
const RUBBLE_HALF: float = 7.0

var _noise := FastNoiseLite.new()


func _init() -> void:
	_noise.seed = 11
	_noise.frequency = 0.02


## Ground height in metres at (x, z), before the level's smoothing.
func height_at(x: float, z: float) -> float:
	var at := Vector2(x, z)
	# Gentle lowland.
	var h: float = BASE + 1.2 * _noise.get_noise_2d(x, z)
	h = maxf(h, _ridge(at))
	h = maxf(h, _cone(at))
	h = maxf(h, _mesa(at))
	h = maxf(h, _goal_plateau(at))
	h = _flatten_for_paths(at, h)
	h = _dunes(at, h)
	h = _dune_sea(at, h)
	h = _flat_areas(at, h)
	h = _river(at, h)
	h = _lake(at, h)
	h = maxf(h, _rim(at))
	return clampf(h, 0.0, MAX_HEIGHT)


## Terrain painted at (x, z): "mud", "sand" or "" (firm ground).
func terrain_at(x: float, z: float) -> String:
	var at := Vector2(x, z)
	if _in_square(at, TEST_MUD) or at.distance_to(MUD_BASIN) < MUD_BASIN_RADIUS or at.distance_to(FORD) < FORD_REACH:
		return "mud"
	if _in_square(at, TEST_SAND) or DUNES.has_point(at) or DUNE_SEA.grow(-3.0).has_point(at):
		return "sand"
	# The ridge ledge: sand on the high route's narrow stretch.
	var ledge: Dictionary = _nearest_on_path(at, HIGH_ROUTE.slice(3, 5))
	if ledge.distance < LEDGE_WIDTH / 2.0 + 1.0:
		return "sand"
	return ""


## Every route as a list of points (x, z) to drive through, spawn to goal.
func route_points(high: bool) -> Array[Vector2]:
	var points: Array[Vector2] = [SPAWN]
	for point: Vector3 in (HIGH_ROUTE if high else LOW_ROUTE):
		points.append(Vector2(point.x, point.y))
	return points


# --- Shapes ------------------------------------------------------------------

func _ridge(at: Vector2) -> float:
	if at.x > RIDGE_EAST_EDGE + 6.0:
		return 0.0
	# Fades in and out at the north and south ends.
	var along: float = minf(at.y - RIDGE_Z_FROM, RIDGE_Z_TO - at.y)
	if along < -30.0:
		return 0.0
	var ends: float = smoothstep(-30.0, 0.0, along)
	# The east face is a cliff: 14 m down in 6 m.
	var face: float = smoothstep(RIDGE_EAST_EDGE + 6.0, RIDGE_EAST_EDGE, at.x)
	return lerpf(BASE, RIDGE_HEIGHT, face * ends)


func _cone(at: Vector2) -> float:
	var distance: float = at.distance_to(CONE)
	return CONE_HEIGHT - distance * tan(deg_to_rad(CONE_SLOPE_DEGREES))


func _mesa(at: Vector2) -> float:
	var distance: float = at.distance_to(MESA)
	# Flat top, then a cliff (16 m down in 4 m).
	return lerpf(MESA_HEIGHT, 0.0, smoothstep(MESA_RADIUS, MESA_RADIUS + 4.0, distance))


func _goal_plateau(at: Vector2) -> float:
	var distance: float = at.distance_to(GOAL)
	# Steep sides (about 45°) except where the routes come up.
	return GOAL_HEIGHT - maxf(distance - GOAL_RADIUS, 0.0) * tan(deg_to_rad(45.0))


func _rim(at: Vector2) -> float:
	var to_edge: float = minf(minf(at.x + WIDTH / 2.0, WIDTH / 2.0 - at.x), minf(at.y + DEPTH / 2.0, DEPTH / 2.0 - at.y))
	var rise: float = smoothstep(RIM + 4.0, 2.0, to_edge)
	# 0 away from the edges, so it never fills in the river or dips.
	return rise * (BASE + 32.0 + 5.0 * _noise.get_noise_2d(at.x * 2.0, at.y * 2.0))


## Lay each route's path at its own height, easing back to the land beside it.
func _flatten_for_paths(at: Vector2, h: float) -> float:
	for route: Array[Vector3] in [ROAD, HIGH_ROUTE, LOW_ROUTE]:
		var nearest: Dictionary = _nearest_on_path(at, route)
		var half: float = (LEDGE_WIDTH if _on_ledge(nearest) else PATH_WIDTH) / 2.0
		if nearest.distance < half:
			h = nearest.height
		elif nearest.distance < half + PATH_SHOULDER:
			var ease: float = smoothstep(half, half + PATH_SHOULDER, nearest.distance)
			# Beside the ridge ledge, the land stays as it is (the cliff).
			if not _on_ledge(nearest):
				h = lerpf(nearest.height, h, ease)
	return h


func _on_ledge(nearest: Dictionary) -> bool:
	return nearest.route_size == HIGH_ROUTE.size() and nearest.segment == 3


## Ripples on the sand dunes (on the low route too: it rolls over them).
func _dunes(at: Vector2, h: float) -> float:
	if not DUNES.grow(6.0).has_point(at):
		return h
	var fade: float = minf(1.0, minf(minf(at.x - DUNES.position.x + 6.0, DUNES.end.x + 6.0 - at.x),
			minf(at.y - DUNES.position.y + 6.0, DUNES.end.y + 6.0 - at.y)) / 6.0)
	return h + fade * 0.5 * sin(at.y * 0.45 + 0.3 * sin(at.x * 0.2))


## The spawn and the test area: exactly flat at BASE.
func _flat_areas(at: Vector2, h: float) -> float:
	var spawn_blend: float = smoothstep(26.0, 16.0, at.distance_to(SPAWN))
	h = lerpf(h, BASE, spawn_blend)
	var inside: float = minf(minf(at.x - TEST_AREA.position.x, TEST_AREA.end.x - at.x),
			minf(at.y - TEST_AREA.position.y, TEST_AREA.end.y - at.y))
	return lerpf(h, BASE, smoothstep(-8.0, 0.0, inside))


## The river: deep, with steep banks, except at the shallow ford.
func _river(at: Vector2, h: float) -> float:
	var distance: float = INF
	for index: int in RIVER.size() - 1:
		distance = minf(distance, _distance_to_segment(at, RIVER[index], RIVER[index + 1]))
	var near_ford: float = smoothstep(FORD_REACH, FORD_REACH * 0.5, at.distance_to(FORD))
	var bed: float = lerpf(RIVER_BED, FORD_BED, near_ford)
	# Steep banks (about 60°) normally; long and gentle at the ford.
	var bank: float = lerpf(2.0, 12.0, near_ford)
	if distance < RIVER_HALF_WIDTH:
		return minf(h, bed)
	if distance < RIVER_HALF_WIDTH + bank:
		var rise: float = (distance - RIVER_HALF_WIDTH) / bank
		return minf(h, lerpf(bed, maxf(h, bed), rise))
	return h


## The lake: a deep middle, and a bed shelving gently (about 11°) up to the shore.
func _lake(at: Vector2, h: float) -> float:
	var distance: float = at.distance_to(LAKE)
	if distance >= LAKE_SHORE:
		return h
	var rise: float = smoothstep(LAKE_RADIUS, LAKE_SHORE, distance)
	return minf(h, lerpf(RIVER_BED, BASE, rise))


## Big rolling sand dunes, fading out at the edges of the dune sea.
func _dune_sea(at: Vector2, h: float) -> float:
	var inside: float = minf(minf(at.x - DUNE_SEA.position.x, DUNE_SEA.end.x - at.x),
			minf(at.y - DUNE_SEA.position.y, DUNE_SEA.end.y - at.y))
	if inside <= 0.0:
		return h
	var fade: float = smoothstep(0.0, 14.0, inside)
	# Crests running roughly north-south, wandering with the noise; peaky tops.
	var phase: float = at.x * 0.15 + at.y * 0.04 + 1.6 * _noise.get_noise_2d(at.x * 0.7, at.y * 0.7)
	var crest: float = pow(0.5 + 0.5 * sin(phase), 1.5)
	return h + fade * DUNE_SEA_HEIGHT * crest


func _in_square(at: Vector2, centre: Vector2) -> bool:
	return absf(at.x - centre.x) <= TEST_SQUARE_HALF and absf(at.y - centre.y) <= TEST_SQUARE_HALF


## Nearest point on a route: distance to it, the path height there, and which
## segment it is on.
func _nearest_on_path(at: Vector2, route: Array[Vector3]) -> Dictionary:
	var best: Dictionary = {"distance": INF, "height": BASE, "segment": -1, "route_size": route.size()}
	for index: int in route.size() - 1:
		var a := Vector2(route[index].x, route[index].y)
		var b := Vector2(route[index + 1].x, route[index + 1].y)
		var t: float = _segment_fraction(at, a, b)
		var distance: float = at.distance_to(a.lerp(b, t))
		if distance < best.distance:
			best = {"distance": distance, "height": lerpf(route[index].z, route[index + 1].z, t),
					"segment": index, "route_size": route.size()}
	return best


func _segment_fraction(at: Vector2, a: Vector2, b: Vector2) -> float:
	var along: Vector2 = b - a
	if along.length_squared() < 0.0001:
		return 0.0
	return clampf((at - a).dot(along) / along.length_squared(), 0.0, 1.0)


func _distance_to_segment(at: Vector2, a: Vector2, b: Vector2) -> float:
	return at.distance_to(a.lerp(b, _segment_fraction(at, a, b)))


# --- Scenery -------------------------------------------------------------------

## Everything placed on the ground, the same every time (fixed random seed).
## Each list holds dictionaries with "at" (Vector2, x and z) and sizes:
## - pines (forest) and trees (scattered): "height", "radius" (canopy); solid.
## - bushes: "size"; drive-through.
## - big_rocks (high road), boulders (boulder field), small_rocks (rubble patch
##   and scattered): "size" (Vector3, metres), "turn" (radians); solid.
## - buoys: on the lake, marking the deep water.
func scenery() -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = 31
	var result: Dictionary = {"pines": [], "trees": [], "bushes": [], "big_rocks": [],
			"boulders": [], "small_rocks": [], "buoys": []}
	_place_pines(random, result.pines)
	_place_big_rocks(random, result.big_rocks)
	for index: int in 26:
		var angle: float = random.randf() * TAU
		var at: Vector2 = BOULDER_FIELD + Vector2(cos(angle), sin(angle)) * sqrt(random.randf()) * BOULDER_FIELD_RADIUS
		if _open_ground(at, 2.0):
			result.boulders.append(_rock(random, at, 1.0, 2.2))
	for index: int in 40:
		var at := RUBBLE + Vector2(random.randf_range(-RUBBLE_HALF, RUBBLE_HALF), random.randf_range(-RUBBLE_HALF, RUBBLE_HALF))
		result.small_rocks.append(_rock(random, at, 0.25, 0.5))
	# Scattered over the open lowland, on a jittered grid.
	for item: Array in [["trees", 20.0, 0.55], ["bushes", 9.0, 0.45], ["small_rocks", 15.0, 0.25]]:
		var spacing: float = item[1]
		for gx: int in int(WIDTH / spacing):
			for gz: int in int(DEPTH / spacing):
				if random.randf() > item[2]:
					continue
				var at := Vector2(-WIDTH / 2.0 + (gx + random.randf()) * spacing, -DEPTH / 2.0 + (gz + random.randf()) * spacing)
				if not _open_ground(at, 3.0 if item[0] == "trees" else 1.5) or FOREST.grow(4.0).has_point(at):
					continue
				match item[0]:
					"trees":
						result.trees.append({"at": at, "height": random.randf_range(5.0, 8.0), "radius": random.randf_range(2.0, 3.0)})
					"bushes":
						result.bushes.append({"at": at, "size": random.randf_range(0.6, 1.3)})
					"small_rocks":
						result.small_rocks.append(_rock(random, at, 0.25, 0.5))
	for index: int in 24:
		var angle: float = TAU * index / 24.0
		result.buoys.append({"at": LAKE + Vector2(cos(angle), sin(angle)) * (DEEP_WATER_RADIUS + 1.0)})
	return result


func _rock(random: RandomNumberGenerator, at: Vector2, smallest: float, largest: float) -> Dictionary:
	var radius: float = random.randf_range(smallest, largest)
	return {"at": at, "size": Vector3(radius * random.randf_range(0.9, 1.4), radius * random.randf_range(0.6, 1.0),
			radius * random.randf_range(0.9, 1.4)), "turn": random.randf() * TAU}


## The pine forest: a jittered grid with clearings to drive through, kept
## back from the river.
func _place_pines(random: RandomNumberGenerator, pines: Array) -> void:
	var spacing: float = 7.5
	for gx: int in int(FOREST.size.x / spacing):
		for gz: int in int(FOREST.size.y / spacing):
			var at: Vector2 = FOREST.position + Vector2((gx + random.randf()) * spacing, (gz + random.randf()) * spacing)
			# Clearings where the noise is high.
			if _noise.get_noise_2d(at.x * 3.0, at.y * 3.0) > 0.25 or _river_distance(at) < RIVER_HALF_WIDTH + 8.0:
				continue
			if height_at(at.x, at.y) > BASE + 6.0:
				continue
			pines.append({"at": at, "height": random.randf_range(7.0, 12.0), "radius": random.randf_range(1.6, 2.4)})


## Big rocks around the foot of the high road's raised stretches, and two on
## top beside the road (leaving a lane wider than the tank).
func _place_big_rocks(random: RandomNumberGenerator, rocks: Array) -> void:
	for segment: int in [0, 1, 2, 4, 5, 6]:
		var a := Vector2(HIGH_ROUTE[segment].x, HIGH_ROUTE[segment].y)
		var b := Vector2(HIGH_ROUTE[segment + 1].x, HIGH_ROUTE[segment + 1].y)
		var along: Vector2 = (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		var count: int = int(a.distance_to(b) / 18.0)
		for step: int in count:
			var at: Vector2 = a.lerp(b, (step + random.randf_range(0.2, 0.8)) / count)
			var away: float = PATH_WIDTH / 2.0 + PATH_SHOULDER + random.randf_range(1.5, 4.0)
			at += side * away * (1.0 if (step + segment) % 2 == 0 else -1.0)
			if _open_ground(at, 2.5, 0.0):
				rocks.append(_rock(random, at, 1.8, 3.2))
	# The two on top: to one side of the road, about 4.2 m from its middle.
	for item: Array in [[1, 0.5, 1.0], [5, 0.5, -1.0]]:
		var a := Vector2(HIGH_ROUTE[item[0]].x, HIGH_ROUTE[item[0]].y)
		var b := Vector2(HIGH_ROUTE[item[0] + 1].x, HIGH_ROUTE[item[0] + 1].y)
		var along: Vector2 = (b - a).normalized()
		var at: Vector2 = a.lerp(b, item[1]) + Vector2(-along.y, along.x) * 4.2 * item[2]
		rocks.append({"at": at, "size": Vector3(1.4, 1.2, 1.6), "turn": random.randf() * TAU})


## Somewhere free for scenery: clear of the routes (by `clearance` beyond
## their shoulders), the test area, the spawn, water, steep ground, the hills,
## the dunes and the mud. route_margin: how far beyond a path's edge to keep.
func _open_ground(at: Vector2, clearance: float, route_margin: float = PATH_SHOULDER) -> bool:
	var to_edge: float = minf(minf(at.x + WIDTH / 2.0, WIDTH / 2.0 - at.x), minf(at.y + DEPTH / 2.0, DEPTH / 2.0 - at.y))
	if to_edge < RIM + 6.0:
		return false
	for route: Array[Vector3] in [ROAD, HIGH_ROUTE, LOW_ROUTE]:
		if _nearest_on_path(at, route).distance < PATH_WIDTH / 2.0 + route_margin + clearance:
			return false
	if TEST_AREA.grow(8.0).has_point(at) or at.distance_to(SPAWN) < 30.0:
		return false
	if at.distance_to(LAKE) < LAKE_SHORE + clearance or _river_distance(at) < RIVER_HALF_WIDTH + 6.0 + clearance:
		return false
	# A clear run-up east of the cone, so you can try (and fail) to drive up it.
	if CONE_RUN_UP.grow(clearance).has_point(at):
		return false
	if at.distance_to(GOAL) < GOAL_RADIUS + 14.0 or at.distance_to(CONE) < 16.0 or at.distance_to(MESA) < MESA_RADIUS + 6.0:
		return false
	if at.x < RIDGE_EAST_EDGE + 8.0 and at.y > RIDGE_Z_FROM - 30.0 and at.y < RIDGE_Z_TO + 30.0:
		return false
	if DUNE_SEA.grow(4.0).has_point(at) or DUNES.grow(4.0).has_point(at) or at.distance_to(MUD_BASIN) < MUD_BASIN_RADIUS + 4.0:
		return false
	# Not on slopes steeper than about 20°.
	var h: float = height_at(at.x, at.y)
	if absf(height_at(at.x + 2.0, at.y) - h) > 0.75 or absf(height_at(at.x, at.y + 2.0) - h) > 0.75:
		return false
	return h > WATER_LEVEL + 0.6


func _river_distance(at: Vector2) -> float:
	var distance: float = INF
	for index: int in RIVER.size() - 1:
		distance = minf(distance, _distance_to_segment(at, RIVER[index], RIVER[index + 1]))
	return distance
