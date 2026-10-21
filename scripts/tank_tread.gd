class_name TankTread
extends RefCounted
## One tread's speed, and the rules that change it each physics frame.
## This is where momentum and slopes come from.

## Current speed along the tank's forward direction, in metres per second.
## Negative = moving backwards.
var speed: float = 0.0

## True if, this frame, the tread wanted to push harder than its grip allowed.
var traction_capped: bool = false


## Move the tread's speed one frame toward what the driver asks for.
## input: driver's push, -1 to 1. slope: ground angle along the tank, in
## radians, positive when nose-up.
func update(input: float, slope: float, tuning: TankTuning, delta: float) -> void:
	var target_speed: float = input * tuning.max_tread_speed
	# Gravity pulls the tread back down the slope.
	var gravity_accel: float = -tuning.g * sin(slope)

	# The push needed to reach the target speed this frame, including holding
	# against gravity. Letting go (target 0) therefore acts as a brake.
	var wanted_accel: float = (target_speed - speed) / delta - gravity_accel
	var drive_accel: float = clampf(wanted_accel, -tuning.max_drive_accel, tuning.max_drive_accel)

	# Grip cap: on steeper ground the treads press down less, so they grip less.
	var grip_limit: float = tuning.traction_coeff * tuning.g * cos(slope)
	traction_capped = absf(drive_accel) > grip_limit
	if traction_capped:
		drive_accel = signf(drive_accel) * grip_limit

	speed += (drive_accel + gravity_accel) * delta

	# Rolling resistance: a small pull toward zero that never overshoots it.
	speed = move_toward(speed, 0.0, tuning.rolling_resistance * delta)


func stop() -> void:
	speed = 0.0
	traction_capped = false
