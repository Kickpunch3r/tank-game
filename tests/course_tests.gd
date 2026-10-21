class_name CourseTests
extends RefCounted
## Checks the built course's shape by casting rays straight down onto it.

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func run() -> void:
	var report: TestReport = runner.report
	report.heading("Course shape")
	var ladder: SlopeLadder = runner.course.get_node(^"SlopeLadder")
	report.check("Ramp list read from the text file", ladder.ramps.size() > 0, "%d ramps" % ladder.ramps.size())

	for ramp: SlopeLadder.RampInfo in ladder.ramps:
		var middle: Vector3 = ramp.base_position.lerp(ramp.top_position, 0.5)
		var on_slope: Dictionary = _ray_down(middle)
		var at_base: Dictionary = _ray_down(ramp.base_position + Vector3(0.0, 0.0, 0.3))
		var past_top: Dictionary = _ray_down(ramp.top_position + Vector3(0.0, 0.0, -3.0))
		var measured_angle: float = -1.0
		if not on_slope.is_empty():
			measured_angle = rad_to_deg(on_slope.normal.angle_to(Vector3.UP))
		var base_flush: bool = not at_base.is_empty() and absf(at_base.position.y) < 0.01
		var ledge_found: bool = not past_top.is_empty() and absf(past_top.position.y - ramp.top_position.y) < 0.05
		report.check("%2d° ramp: exact angle, flush base, %s" % [
				roundi(ramp.angle_degrees), "ledge on top" if ramp.has_ledge else "no ledge"],
				absf(measured_angle - ramp.angle_degrees) < 0.1 and base_flush and ledge_found == ramp.has_ledge,
				"measured %.2f°" % measured_angle)

	var bumps: RollingBumps = runner.course.get_node(^"RollingBumps")
	var inner: Dictionary = _ray_down(bumps.global_position + Vector3(3.0, 0.0, -7.0))
	var edge: Dictionary = _ray_down(bumps.global_position + Vector3(bumps.patch_size / 2.0 - 0.5, 0.0, 0.0))
	report.check("Bumps rise inside and fade to flat at the edge",
			not inner.is_empty() and inner.position.y > 0.3 and not edge.is_empty() and edge.position.y < 0.15)
	var bump_visual: MeshInstance3D = bumps.get_node(^"Bumps/Visual")
	var normals: PackedVector3Array = bump_visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var facing_down: int = 0
	for normal: Vector3 in normals:
		if normal.y < 0.0:
			facing_down += 1
	report.check("Bumps mesh faces upward", facing_down == 0, "%d normals face down" % facing_down)


func _ray_down(where: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(where.x, 60.0, where.z), Vector3(where.x, -10.0, where.z))
	# Ignore tanks: only the course itself counts.
	query.collision_mask = 0xFFFFFFFF
	var space: PhysicsDirectSpaceState3D = runner.course.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Tank:
		return {}
	return hit
