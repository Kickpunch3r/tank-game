class_name ChaseCamera
extends Camera3D
## Third-person camera that follows behind the target and looks at it.
## It only follows the target's heading (left/right turning), never its tilt,
## so the view stays level when the tank drives on slopes.

## The node to follow (the tank).
@export var target: Node3D

## How far behind the target the camera sits, in metres.
@export var follow_distance: float = 12.0

## How high above the target the camera sits, in metres.
@export var follow_height: float = 5.0

## How high above the target's origin the camera aims, in metres.
## Raising this tilts the view up so you see more of what is ahead.
@export var look_height: float = 1.5

## How quickly the camera catches up. Higher = snappier, lower = floatier.
@export var follow_smoothing: float = 4.0


func _ready() -> void:
	if target != null:
		global_position = _desired_position()
		look_at(_look_point(), Vector3.UP)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Frame-rate independent smoothing: move a fraction of the remaining gap each frame.
	var catch_up: float = 1.0 - exp(-follow_smoothing * delta)
	global_position = global_position.lerp(_desired_position(), catch_up)
	look_at(_look_point(), Vector3.UP)


## Where the camera wants to be: behind the target's heading, ignoring its tilt.
func _desired_position() -> Vector3:
	var forward: Vector3 = -target.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	return target.global_position - forward * follow_distance + Vector3.UP * follow_height


func _look_point() -> Vector3:
	return target.global_position + Vector3.UP * look_height
