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

	# Engine power: when pushing the way the tread is already going (speeding
	# up), the push fades at higher speeds. Braking is never limited.
	if speed != 0.0 and signf(drive_accel) == signf(speed):
		var limit: float = tuning.max_drive_accel * engine_pull(absf(speed), tuning)
		drive_accel = signf(drive_accel) * minf(absf(drive_accel), limit)

	# Grip cap: on steeper ground the treads press down less, so they grip less.
	var grip_limit: float = tuning.traction_coeff * tuning.g * cos(slope)
	traction_capped = absf(drive_accel) > grip_limit
	if traction_capped:
		drive_accel = signf(drive_accel) * grip_limit

	speed += (drive_accel + gravity_accel) * delta

	# Rolling resistance: a small pull toward zero that never overshoots it.
	speed = move_toward(speed, 0.0, tuning.rolling_resistance * delta)


## Fraction of full push available at this speed (1 = full strength).
## Full up to power_falloff_start of top speed, then fading in a straight line
## to power_at_top_speed at top speed.
static func engine_pull(current_speed: float, tuning: TankTuning) -> float:
	if tuning.power_falloff_start >= 1.0 or tuning.max_tread_speed <= 0.0:
		return 1.0
	var fraction_of_top: float = current_speed / tuning.max_tread_speed
	if fraction_of_top <= tuning.power_falloff_start:
		return 1.0
	var fade: float = (fraction_of_top - tuning.power_falloff_start) / (1.0 - tuning.power_falloff_start)
	return lerpf(1.0, tuning.power_at_top_speed, clampf(fade, 0.0, 1.0))


func stop() -> void:
	speed = 0.0
	traction_capped = false
