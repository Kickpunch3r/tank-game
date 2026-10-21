class_name PhysicsTank
extends RigidBody3D
## A physics-based tank, to compare with the kinematic Tank by feel.
## It reads only its DriverStation child, exactly like the kinematic tank.
##
## How it works:
## - The body is a rigid box (with a sloped nose and tail) that Godot's physics
##   moves. It doesn't touch the ground in normal driving: it rides on 8 springs.
## - 4 probes per tread look straight down from the hull. Each one that finds
##   ground within its spring's length pushes the hull up at its own place,
##   like a spring and shock absorber. So when one tread drops off a ledge,
##   that side loses its push and the tank tilts, teeters or falls.
## - Each grounded probe also pushes the tank along (its share of its tread's
##   drive) and holds it against sliding sideways. Both together are capped at
##   tan(grip) x how hard that probe is pressed down, so a lightly loaded probe
##   grips less.
##
## What it looks like lives in the child "Visual" node (no tilting script: the
## whole body tilts for real).

## All the driving numbers. If left empty, the defaults are used.
@export var tuning: PhysicsTankTuning

## Where the spring tops sit on the hull (left/right, height, front/back), in
## metres from the tank's origin (the middle of the tread bottoms).
const TREAD_HALF_WIDTH: float = 1.5
const SPRING_TOP_HEIGHT: float = 0.85
const PROBE_ZS: Array[float] = [-1.875, -0.625, 0.625, 1.875]
const PROBE_COUNT: int = 8

## Emitted when the tank drives into something hard at speed (once per hit).
signal bumped

@onready var driver_station: DriverStation = $DriverStation

## Read-only results of the last physics frame, for the HUD and tests.
## Speed along the hull's forward direction, in metres per second.
var forward_speed: float = 0.0
## Each tread's speed over the ground, in metres per second.
var left_tread_speed: float = 0.0
var right_tread_speed: float = 0.0
## Each probe: is it touching the ground, and how squashed is its spring
## (0 = not at all, 1 = fully). Probes 0-3 are the left tread, front to back,
## and 4-7 the right.
var probe_grounded: Array[bool] = []
var probe_compression: Array[float] = []
## True if a tread wanted more push (or sideways hold) than its grip allowed.
var left_grip_saturated: bool = false
var right_grip_saturated: bool = false

var _probes: Array[RayCast3D] = []
var _spawn_transform: Transform3D
var _home_transform: Transform3D
var _was_hit: bool = false
var _previous_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	if tuning == null:
		tuning = PhysicsTankTuning.new()
	can_sleep = false
	continuous_cd = true
	_build_probes()
	apply_tuning()
	_spawn_transform = global_transform
	_home_transform = global_transform


## Use the current tuning values that Godot itself needs (mass, centre of
## mass, damping). Called every frame too, so live changes take effect.
func apply_tuning() -> void:
	mass = tuning.mass()
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, tuning.centre_of_mass_height(), 0.0)
	# Replace Godot's project-wide damping rather than add to it, so these
	# values are the whole story.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = tuning.linear_damping
	angular_damp = tuning.angular_damping


func _build_probes() -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in PROBE_ZS:
			var probe := RayCast3D.new()
			probe.name = "Probe%s%d" % ["Left" if side < 0.0 else "Right", _probes.size() % 4 + 1]
			probe.position = Vector3(side * TREAD_HALF_WIDTH, SPRING_TOP_HEIGHT, z)
			probe.target_position = Vector3(0.0, -tuning.spring_length, 0.0)
			probe.exclude_parent = true
			probe.enabled = true
			add_child(probe)
			_probes.append(probe)
			probe_grounded.append(false)
			probe_compression.append(0.0)


func _physics_process(delta: float) -> void:
	if driver_station.reset_requested:
		reset_to_spawn()
		return
	apply_tuning()
	var gravity: Vector3 = get_gravity()
	var g: float = gravity.length()
	var up: Vector3 = global_basis.y
	var forward: Vector3 = -global_basis.z
	var centre: Vector3 = global_transform * center_of_mass
	var stiffness: float = tuning.spring_stiffness(PROBE_COUNT, g)
	var damping: float = tuning.spring_damping(PROBE_COUNT, g)
	var friction: float = tuning.traction_coeff()

	# Pass 1: springs. Which probes touch, and how hard each is pressed down.
	var contacts: Array[Dictionary] = []
	var grounded_per_tread: Array[int] = [0, 0]
	for index: int in PROBE_COUNT:
		var probe: RayCast3D = _probes[index]
		probe.target_position = Vector3(0.0, -tuning.spring_length, 0.0)
		probe.force_raycast_update()
		probe_grounded[index] = probe.is_colliding()
		probe_compression[index] = 0.0
		if not probe.is_colliding():
			continue
		var point: Vector3 = probe.get_collision_point()
		var length_now: float = probe.global_position.distance_to(point)
		var squash: float = clampf(tuning.spring_length - length_now, 0.0, tuning.spring_length)
		probe_compression[index] = squash / tuning.spring_length
		var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(point - centre)
		# Squashing (moving down into the ground) is resisted, rebounding is slowed.
		var spring_force: float = maxf(stiffness * squash - damping * point_velocity.dot(up), 0.0)
		contacts.append({"index": index, "point": point, "normal": probe.get_collision_normal(),
				"velocity": point_velocity, "press": spring_force})
		grounded_per_tread[index / 4] += 1
		apply_force(up * spring_force, point - global_position)

	# Pass 2: drive and sideways hold, shared out over each tread's grounded probes.
	left_tread_speed = _tread_speed(-1.0, centre)
	right_tread_speed = _tread_speed(1.0, centre)
	forward_speed = linear_velocity.dot(forward)
	var tread_accel: Array[float] = [
		_tread_accel(driver_station.left_tread, left_tread_speed, forward, gravity, delta),
		_tread_accel(driver_station.right_tread, right_tread_speed, forward, gravity, delta),
	]
	var saturated: Array[bool] = [false, false]
	var sideways_rate: float = tuning.sideways_rate()
	for contact: Dictionary in contacts:
		var tread: int = contact.index / 4
		var normal: Vector3 = contact.normal
		var along: Vector3 = (forward - normal * forward.dot(normal)).normalized()
		var across: Vector3 = along.cross(normal).normalized()
		var mass_share: float = mass / PROBE_COUNT
		var drive: float = tread_accel[tread] * (mass / 2.0) / grounded_per_tread[tread]
		# Resist sliding sideways, and hold against gravity pulling sideways
		# on a side slope (like a brake, but across the treads).
		var sideways_speed: float = (contact.velocity as Vector3).dot(across)
		var sideways: float = -mass_share * (sideways_rate * sideways_speed + gravity.dot(across))
		var push: Vector3 = along * drive + across * sideways
		var limit: float = friction * contact.press
		if push.length() > limit:
			push = push.normalized() * limit
			saturated[tread] = true
		apply_force(push, (contact.point as Vector3) - global_position)
	left_grip_saturated = saturated[0]
	right_grip_saturated = saturated[1]
	_check_for_hit()


## Speed over the ground of the middle of one tread (side -1 left, 1 right).
func _tread_speed(side: float, centre: Vector3) -> float:
	var middle: Vector3 = global_transform * Vector3(side * TREAD_HALF_WIDTH, 0.0, 0.0)
	var velocity: Vector3 = linear_velocity + angular_velocity.cross(middle - centre)
	return velocity.dot(-global_basis.z)


## How hard one tread wants to push, in m/s per second (for its half of the
## mass). The same three states as the kinematic tank's treads:
## braking (brake held), idling (lever at 0) and driving.
func _tread_accel(lever: float, speed: float, forward: Vector3, gravity: Vector3, delta: float) -> float:
	var strongest: float = tuning.max_drive_accel()
	# Gravity's pull along the tank (negative = pulling it backwards, uphill).
	var gravity_along: float = gravity.dot(forward)
	var accel: float = 0.0
	if driver_station.brake or lever != 0.0:
		var target: float = 0.0 if driver_station.brake else lever * tuning.top_speed
		# Chase the target speed, and hold against gravity (so the brake holds
		# the tank on slopes and the push fades as the treads reach top speed).
		accel = clampf((target - speed) * tuning.throttle_response - gravity_along, -strongest, strongest)
	# Rolling resistance, plus idle drag with the lever at 0: never past a stop.
	var resistance: float = tuning.rolling_resistance
	if lever == 0.0 and not driver_station.brake:
		resistance += tuning.idle_drag / maxf(tuning.weight, 0.01)
	accel -= signf(speed) * minf(resistance, absf(speed) / delta)
	return accel


## A sudden loss of speed means the tank hit something (for buzzing a phone).
func _check_for_hit() -> void:
	var lost: float = (_previous_velocity - linear_velocity).length()
	var hit: bool = lost > 3.0 and _previous_velocity.length() > 1.0
	if hit and not _was_hit:
		bumped.emit()
	_was_hit = hit
	_previous_velocity = linear_velocity


# --- Shared with the kinematic tank (used by the rig, HUD, panel, tests) ------

## Put the tank somewhere, standing still.
func place_at(where: Transform3D) -> void:
	# Moving a rigid body: set the transform on the physics server too, so
	# Godot doesn't carry on from the old place.
	global_transform = where
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, where)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_previous_velocity = Vector3.ZERO
	forward_speed = 0.0
	left_tread_speed = 0.0
	right_tread_speed = 0.0


func reset_to_spawn() -> void:
	place_at(_spawn_transform)


func set_spawn(where: Transform3D) -> void:
	_spawn_transform = where


func get_spawn() -> Transform3D:
	return _spawn_transform


func get_home() -> Transform3D:
	return _home_transform


func set_home(where: Transform3D) -> void:
	_home_transform = where


## How far in front of a ramp's base this tank's middle sits when it is at
## rest with its front probes at the foot of the slope.
func standing_start_distance(_angle_degrees: float) -> float:
	return -PROBE_ZS[0] + 0.15


## Hull pitch (nose up positive) and roll (leaning right positive), in degrees.
func pitch_degrees() -> float:
	return rad_to_deg(asin(clampf((-global_basis.z).y, -1.0, 1.0)))


func roll_degrees() -> float:
	return rad_to_deg(asin(clampf(-global_basis.x.y, -1.0, 1.0)))


## Ground angle along the tank, as the hull lies on it (degrees, nose up positive).
func slope_degrees() -> float:
	return pitch_degrees()


func is_traction_capped() -> bool:
	return left_grip_saturated or right_grip_saturated


func display_name() -> String:
	return "Physics tank"


## Lines for the debug display.
func debug_lines() -> PackedStringArray:
	var lines: PackedStringArray = [
		"Tank: PHYSICS   (T = swap)",
		"Left tread:  input %+.2f   speed %+5.1f m/s   grip %s" % [driver_station.left_tread,
				left_tread_speed, "SATURATED" if left_grip_saturated else "ok"],
		"Right tread: input %+.2f   speed %+5.1f m/s   grip %s" % [driver_station.right_tread,
				right_tread_speed, "SATURATED" if right_grip_saturated else "ok"],
		"Forward speed: %+5.1f m/s   Brake: %s" % [forward_speed, "ON" if driver_station.brake else "off"],
		"Hull pitch %+5.1f°   roll %+5.1f°" % [pitch_degrees(), roll_degrees()],
		"Probes (front to back; # = touching, number = spring squash %):",
	]
	for row: int in 4:
		lines.append("   L %s   R %s" % [_probe_text(row), _probe_text(row + 4)])
	return lines


func _probe_text(index: int) -> String:
	if not probe_grounded[index]:
		return ".  --- "
	return "#  %3d%%" % roundi(probe_compression[index] * 100.0)
