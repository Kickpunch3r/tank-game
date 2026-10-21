class_name TankTread
extends RefCounted
## One tread's speed, and the rules that change it each physics frame.
## This is where momentum and slopes come from.
##
## Each physics frame the tread is in one of three states:
## - Braking (brake held): pushes against its motion to stop and hold still,
##   even on slopes, as hard as max_drive_accel (pulling_power / weight) and its grip allow.
## - Idling (lever at 0): the engine doesn't push, and the tread is held back
##   by idle_drag (plus rolling resistance and terrain drag), so it slows by
##   itself. Slopes steeper than the drag can resist still pull it.
## - Driving (lever not at 0): pushes toward the lever's target speed, limited
##   by the engine (max_drive_accel, engine power fade, warm-up) and its grip.
##   While turning, that target is lowered (turn scrub, worked out by the tank).

## Current speed along the tank's forward direction, in metres per second.
## Negative = moving backwards.
var speed: float = 0.0

## True if, this frame, the tread wanted to push harder than its grip allowed.
var traction_capped: bool = false

## How hard this tread's engine is able to push right now, in m/s per second.
## Climbs toward what's asked for over the warm-up time; drops at once.
var engine_output: float = 0.0


## Move the tread's speed one frame.
## input: lever push, -1 to 1. slope: ground angle along the tank, in radians,
## positive when nose-up. terrain: the ground under this tread, or null for
## ordinary firm ground. braking: true while the brake is held.
## turn_hold: fraction of the lever's target speed the tread can reach while
## the tank is turning (1 = driving straight; see Tank, turn scrub).
func update(input: float, slope: float, tuning: TankTuning, delta: float,
		terrain: TerrainType = null, braking: bool = false, turn_hold: float = 1.0) -> void:
	var terrain_grip: float = 1.0
	var drag: float = 0.0
	var terrain_top_speed: float = 1.0
	if terrain != null:
		terrain_grip = terrain.grip
		drag = terrain.drag
		terrain_top_speed = terrain.top_speed

	# Gravity pulls the tread back down the slope.
	var gravity_accel: float = -tuning.g * sin(slope)
	var drive_accel: float = 0.0
	traction_capped = false

	if braking or input != 0.0:
		var target_speed: float = 0.0 if braking else input * tuning.top_speed * terrain_top_speed * turn_hold
		# The push needed to reach the target speed this frame, including
		# holding against gravity (so the brake holds the tank on slopes).
		var wanted_accel: float = (target_speed - speed) / delta - gravity_accel
		drive_accel = clampf(wanted_accel, -tuning.max_drive_accel, tuning.max_drive_accel)

		if not braking:
			# Engine power: when pushing the way the tread is already going
			# (speeding up), the push fades at higher speeds.
			if speed != 0.0 and signf(drive_accel) == signf(speed):
				var limit: float = tuning.max_drive_accel * engine_pull(absf(speed), tuning)
				drive_accel = signf(drive_accel) * minf(absf(drive_accel), limit)
			drive_accel = _apply_warm_up(drive_accel, input, tuning, delta)

		# Grip cap: on steeper ground the treads press down less, so they grip less.
		# traction_coeff is tan(grip angle), so the cap equals gravity's pull
		# exactly on a slope as steep as the grip angle.
		var grip_limit: float = tuning.traction_coeff * terrain_grip * tuning.g * cos(slope)
		traction_capped = absf(drive_accel) > grip_limit
		if traction_capped:
			drive_accel = signf(drive_accel) * grip_limit

	if braking or input == 0.0:
		# The engine isn't driving, so it will need to warm up again.
		engine_output = 0.0

	speed += (drive_accel + gravity_accel) * delta

	# Rolling resistance (plus the terrain's drag, plus idle drag when the
	# lever is at 0): a pull toward zero that never overshoots it.
	var resistance: float = tuning.rolling_resistance + drag
	if input == 0.0 and not braking:
		resistance += tuning.idle_drag
	speed = move_toward(speed, 0.0, resistance * delta)


## Warm-up: when the engine is asked to push the way the lever points, it can
## only give as much as it has built up. Its output climbs toward what's asked
## for (from nothing to full in warm_up_time seconds) and drops at once.
## Pushes against the lever's direction (holding back to the target speed,
## e.g. downhill) are not delayed.
func _apply_warm_up(drive_accel: float, input: float, tuning: TankTuning, delta: float) -> float:
	var asked: float = absf(drive_accel)
	var pushing_with_lever: bool = signf(drive_accel) == signf(input)
	if tuning.warm_up_time <= 0.0 or not pushing_with_lever:
		engine_output = asked if pushing_with_lever else engine_output
		return drive_accel
	if asked > engine_output:
		engine_output = move_toward(engine_output, asked, tuning.max_drive_accel / tuning.warm_up_time * delta)
	else:
		engine_output = asked
	return signf(drive_accel) * minf(asked, engine_output)


## Fraction of full push available at this speed (1 = full strength).
## Full up to power_falloff_start of top speed, then fading in a straight line
## to power_at_top_speed at top speed.
static func engine_pull(current_speed: float, tuning: TankTuning) -> float:
	if tuning.power_falloff_start >= 1.0 or tuning.top_speed <= 0.0:
		return 1.0
	var fraction_of_top: float = current_speed / tuning.top_speed
	if fraction_of_top <= tuning.power_falloff_start:
		return 1.0
	var fade: float = (fraction_of_top - tuning.power_falloff_start) / (1.0 - tuning.power_falloff_start)
	return lerpf(1.0, tuning.power_at_top_speed, clampf(fade, 0.0, 1.0))


func stop() -> void:
	speed = 0.0
	traction_capped = false
	engine_output = 0.0
