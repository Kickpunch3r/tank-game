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

## Where reset puts the tank. Starts as where the tank was placed.
var _spawn_transform: Transform3D

## True while in the air, so the first frame back on the ground counts as a landing.
var _airborne: bool = false
## How fast the tank was falling just before it landed, in metres per second.
var _fall_speed: float = 0.0


func _ready() -> void:
	if tuning == null:
		tuning = TankTuning.new()
	_spawn_transform = global_transform


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


func _drive_on_ground(delta: float) -> void:
	ground_normal = get_floor_normal()

	# The tank's forward direction, laid flat along the ground.
	var forward: Vector3 = -global_basis.z
	var ground_forward: Vector3 = (forward - ground_normal * forward.dot(ground_normal)).normalized()
	var slope: float = asin(clampf(ground_forward.y, -1.0, 1.0))
	slope_degrees = rad_to_deg(slope)

	left_tread.update(driver_station.left_tread, slope, tuning, delta)
	right_tread.update(driver_station.right_tread, slope, tuning, delta)

	forward_speed = (left_tread.speed + right_tread.speed) / 2.0
	# Right tread faster than left = turn left (positive yaw), and the reverse.
	var yaw_rate: float = (right_tread.speed - left_tread.speed) / tuning.track_width
	yaw_rate *= 1.0 - tuning.turn_resistance
	rotate_y(yaw_rate * delta)

	# Pressing lightly into the ground keeps Godot counting the tank as "on the
	# floor" on slopes; without it, contact flickers on and off every frame.
	velocity = ground_forward * forward_speed - ground_normal * GROUND_PRESS_SPEED


## In the air: keep moving the way we were going, fall, and don't drive.
func _fall(delta: float) -> void:
	_airborne = true
	ground_normal = Vector3.UP
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


## The starting place the tank was given in the scene, before any set_spawn().
func get_spawn() -> Transform3D:
	return _spawn_transform


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
