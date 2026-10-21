class_name Tank
extends CharacterBody3D
## The tank's body: it moves and collides. What it looks like lives in the
## child "Visual" node, so the art can be swapped without touching this script.
## It never reads the keyboard or gamepad: all driving input comes from its
## DriverStation child.
##
## The body itself only ever turns left and right; it never tilts. The hull
## picture tilts to the ground separately (see hull_tilt.gd).

## How hard the tank is pressed into the ground while driving, in metres per
## second. A technical fix, not a feel setting: see _drive_on_ground().
const GROUND_PRESS_SPEED: float = 1.0

## All the driving numbers. If left empty, the defaults in tank_tuning.gd are used.
@export var tuning: TankTuning

@onready var driver_station: DriverStation = $DriverStation

var left_tread := TankTread.new()
var right_tread := TankTread.new()

# Read-only results of the last physics frame, for the readout, tests and hull tilt.
## Average of the two tread speeds, in metres per second.
var forward_speed: float = 0.0
## Ground angle along the tank, in degrees, positive when nose-up.
var slope_degrees: float = 0.0
## The ground's "up" direction under the tank (straight up when airborne).
var ground_normal: Vector3 = Vector3.UP
## The terrain under each tread (null = ordinary firm ground, or in the air).
var left_terrain: TerrainType = null
var right_terrain: TerrainType = null

## Where reset puts the tank. Starts as where the tank was placed.
var _spawn_transform: Transform3D
## The level's normal starting place (the Tab panel's "Start field").
var _home_transform: Transform3D

## Emitted when the tank drives into a wall or cliff (once per hit).
signal bumped

## True while driving into a wall, so a hit is only announced once.
var _was_against_wall: bool = false

## True while in the air, so the first frame back on the ground counts as a landing.
var _airborne: bool = false
## How fast the tank was falling just before it landed, in metres per second.
var _fall_speed: float = 0.0


func _ready() -> void:
	if tuning == null:
		tuning = TankTuning.new()
	_spawn_transform = global_transform
	_home_transform = global_transform


func _physics_process(delta: float) -> void:
	if driver_station.reset_requested:
		reset_to_spawn()
		return

	if is_on_floor():
		if _airborne:
			_land()
		_drive_on_ground(delta)
	else:
		_fall(delta)
	move_and_slide()
	if is_on_wall():
		_blocked_by_wall()
	else:
		_was_against_wall = false


## Something too steep to drive on (a wall, a cliff, a rock) is in the way.
func _blocked_by_wall() -> void:
	# The treads can't keep turning at a speed the tank isn't really moving:
	# slow them to match, so the tank stalls against the wall instead of
	# pushing at full speed.
	# Only when driving into the wall: rolling or reversing away from it is free.
	var forward: Vector3 = -global_basis.z
	var driving_direction: Vector3 = forward * signf(forward_speed)
	if absf(forward_speed) > 0.01 and get_wall_normal().dot(driving_direction) < -0.1:
		# A hit worth announcing (e.g. to buzz a phone): the first frame of
		# contact, at a real speed.
		if not _was_against_wall and absf(forward_speed) > 1.0:
			bumped.emit()
		_was_against_wall = true
		var real_forward_speed: float = get_real_velocity().dot(forward)
		var kept: float = clampf(real_forward_speed / forward_speed, 0.0, 1.0)
		left_tread.speed *= kept
		right_tread.speed *= kept
		forward_speed = (left_tread.speed + right_tread.speed) / 2.0
	# Sliding up a wall must not throw the tank into the air: keep any
	# upward speed only while the tank is still on drivable ground.
	if not is_on_floor():
		velocity.y = minf(velocity.y, 0.0)


func _drive_on_ground(delta: float) -> void:
	ground_normal = get_floor_normal()

	# The tank's forward direction, laid flat along the ground.
	var forward: Vector3 = -global_basis.z
	var ground_forward: Vector3 = (forward - ground_normal * forward.dot(ground_normal)).normalized()
	var slope: float = asin(clampf(ground_forward.y, -1.0, 1.0))
	slope_degrees = rad_to_deg(slope)

	# Each tread checks the ground under itself, so one tread in mud drags
	# that side and pulls the tank toward the mud.
	left_terrain = TerrainPatch.terrain_at(get_tree(), _tread_position(-1.0))
	right_terrain = TerrainPatch.terrain_at(get_tree(), _tread_position(1.0))
	left_tread.update(driver_station.left_tread, slope, tuning, delta, left_terrain)
	right_tread.update(driver_station.right_tread, slope, tuning, delta, right_terrain)

	forward_speed = (left_tread.speed + right_tread.speed) / 2.0
	# Right tread faster than left = turn left (positive yaw), and the reverse.
	var yaw_rate: float = (right_tread.speed - left_tread.speed) / tuning.track_width
	yaw_rate *= 1.0 - tuning.turn_resistance
	rotate_y(yaw_rate * delta)

	# Pressing lightly into the ground keeps Godot counting the tank as "on the
	# floor" on slopes; without it, contact flickers on and off every frame.
	velocity = ground_forward * forward_speed - ground_normal * GROUND_PRESS_SPEED


## Where a tread touches the ground: side = -1 for left, 1 for right.
func _tread_position(side: float) -> Vector3:
	return global_transform * Vector3(side * tuning.track_width / 2.0, 0.0, 0.0)


## How far the hull picture sinks into soft ground: the average of both treads.
func sink_depth() -> float:
	var left_sink: float = left_terrain.sink_depth if left_terrain != null else 0.0
	var right_sink: float = right_terrain.sink_depth if right_terrain != null else 0.0
	return (left_sink + right_sink) / 2.0


## In the air: keep moving the way we were going, fall, and don't drive.
func _fall(delta: float) -> void:
	_airborne = true
	ground_normal = Vector3.UP
	left_terrain = null
	right_terrain = null
	velocity.y -= tuning.g * tuning.air_gravity_scale * delta
	_fall_speed = maxf(-velocity.y, 0.0)


## First frame back on the ground: a hard landing costs some tread speed.
func _land() -> void:
	_airborne = false
	# A 10 m/s fall counts as fully hard; softer landings lose proportionally less.
	var hardness: float = clampf(_fall_speed / 10.0, 0.0, 1.0)
	var keep: float = 1.0 - tuning.landing_speed_loss * hardness
	left_tread.speed *= keep
	right_tread.speed *= keep
	_fall_speed = 0.0


## Choose where reset puts the tank from now on.
func set_spawn(where: Transform3D) -> void:
	_spawn_transform = where


## Where reset currently puts the tank.
func get_spawn() -> Transform3D:
	return _spawn_transform


## The level's normal starting place. Starts as where the tank was placed;
## a level can move it (e.g. to its start marker).
func get_home() -> Transform3D:
	return _home_transform


func set_home(where: Transform3D) -> void:
	_home_transform = where


## Radius of the round bottom of the tank's collision shape, in metres.
func contact_radius() -> float:
	var shape := ($Collision as CollisionShape3D).shape as CapsuleShape3D
	return shape.radius


## Is either tread trying to push harder than its grip allows this frame?
func is_traction_capped() -> bool:
	return left_tread.traction_capped or right_tread.traction_capped


## Put the tank back where it started, standing still.
func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	left_tread.stop()
	right_tread.stop()
	forward_speed = 0.0
	slope_degrees = 0.0
	ground_normal = Vector3.UP
	_airborne = false
	_fall_speed = 0.0
	left_terrain = null
	right_terrain = null
