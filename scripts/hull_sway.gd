class_name HullSway
extends Node3D
## Put this on the node that holds the hull's meshes (Visual/Hull/Sway). It
## rocks the picture on its suspension, as much as the tuning's `tippiness`
## says: back when speeding up, forward when braking, outward in turns.
##
## Looks only. The tank's body, its path and the cameras never move with it:
## the driver's slit camera sits on Visual/Hull, beside this node, not inside it.

## How quickly the sway follows (radians per second of the spring). Higher =
## stiffer, quicker rocking.
@export var spring_speed: float = 7.0

## How bouncy the sway is: 1 = settles without overshooting, lower = rocks
## past and back a little.
@export_range(0.05, 2.0) var spring_damping: float = 0.55

## The sway never goes past this angle, in degrees.
@export var max_sway_degrees: float = 12.0

## Current sway angles in radians (pitch: positive = nose up; roll: positive
## = leaning left) and how fast they are changing.
var pitch: float = 0.0
var roll: float = 0.0
var _pitch_speed: float = 0.0
var _roll_speed: float = 0.0
var _tank: Tank


func _ready() -> void:
	_tank = _find_tank()


func _process(delta: float) -> void:
	if _tank == null:
		return
	var target: Vector2 = target_angles()
	# A damped spring toward the target, so the hull rocks rather than snaps.
	var stiffness: float = spring_speed * spring_speed
	var damping: float = 2.0 * spring_damping * spring_speed
	_pitch_speed += (stiffness * (target.x - pitch) - damping * _pitch_speed) * delta
	_roll_speed += (stiffness * (target.y - roll) - damping * _roll_speed) * delta
	pitch += _pitch_speed * delta
	roll += _roll_speed * delta
	transform = Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3.ZERO)


## Where the sway is heading right now: x = pitch, y = roll, in radians.
func target_angles() -> Vector2:
	var tuning: TankTuning = _tank.tuning
	if tuning.tippiness <= 0.0 or not _tank.is_on_floor():
		return Vector2.ZERO
	var per_accel: float = deg_to_rad(tuning.sway_degrees_per_accel) * tuning.tippiness
	var limit: float = deg_to_rad(max_sway_degrees)
	# Speeding up forwards rocks the nose up; braking dips it.
	var target_pitch: float = clampf(_tank.forward_accel * per_accel, -limit, limit)
	# Turning pushes the hull outward: turning left (positive turn rate) while
	# going forwards leans it right (negative roll).
	var sideways_accel: float = _tank.forward_speed * _tank.turn_rate
	var target_roll: float = clampf(-sideways_accel * per_accel, -limit, limit)
	return Vector2(target_pitch, target_roll)


func _find_tank() -> Tank:
	var node: Node = get_parent()
	while node != null:
		if node is Tank:
			return node
		node = node.get_parent()
	return null
