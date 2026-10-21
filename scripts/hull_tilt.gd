class_name HullTilt
extends Node3D
## Put this on the tank's Visual/Hull node. It smoothly tilts the hull picture
## to match the ground, so the tank pitches and rolls on slopes. The collision
## body stays upright; only the picture moves.
##
## The tank's collision shape has a rounded bottom of radius `contact_radius`.
## On a slope it touches the ground a little to one side of centre, so the hull
## is moved to that touching point to sit flush with the ground.

## Radius of the round bottom of the tank's collision shape, in metres.
## Must match the collision shape in tank.tscn.
@export var contact_radius: float = 1.7

var _tank: Tank


func _ready() -> void:
	_tank = _find_tank()


func _process(delta: float) -> void:
	if _tank == null:
		return
	var target: Transform3D = _target_transform()
	var catch_up: float = 1.0 - exp(-_tank.tuning.tilt_smoothing * delta)
	transform = transform.interpolate_with(target, catch_up)


## The hull's resting transform for the current ground, relative to the tank.
## In the air there is no ground: the hull follows its flight path instead,
## as much as the tuning's nose_dip says (0 = stay level).
func _target_transform() -> Transform3D:
	if not _tank.is_on_floor():
		return Transform3D(Basis(Vector3.RIGHT, _flight_pitch() * _tank.tuning.nose_dip), Vector3.ZERO)
	var up: Vector3 = (_tank.global_basis.inverse() * _tank.ground_normal).normalized()
	# Keep the hull facing the tank's way, laid along the tilted ground.
	var back: Vector3 = Vector3.BACK - up * Vector3.BACK.dot(up)
	back = back.normalized()
	var right: Vector3 = up.cross(back).normalized()
	var tilted := Basis(right, up, back)
	# Point where the round bottom touches the ground.
	var sphere_centre := Vector3(0.0, contact_radius, 0.0)
	var contact_point: Vector3 = sphere_centre - up * contact_radius
	# Soft ground (mud, sand) lets the hull sink in a little.
	return Transform3D(tilted, contact_point - up * _tank.sink_depth())


## Angle of the tank's flight path, in radians: positive = climbing, negative
## = falling. Driving backwards through the air, the tail leads instead.
func _flight_pitch() -> float:
	var local_velocity: Vector3 = _tank.global_basis.inverse() * _tank.velocity
	var forward_speed: float = -local_velocity.z
	if absf(forward_speed) < 0.5:
		return 0.0
	return atan2(local_velocity.y, absf(forward_speed)) * signf(forward_speed)


func _find_tank() -> Tank:
	var node: Node = get_parent()
	while node != null:
		if node is Tank:
			return node
		node = node.get_parent()
	return null
