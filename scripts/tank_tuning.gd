class_name TankTuning
extends Resource
## Every number that changes how the kinematic tank drives, in one place.
## Edit them by clicking tuning/tank_tuning.tres and changing values in the Inspector.
##
## The first six are the feel knobs: the ones you are expected to change. They
## have the same names and meanings as the physics tank's. Everything under "Advanced" was tuned
## once and usually stays as it is.
##
## How slopes come out of these numbers: the tank can only hold a slope up to
## its `grip` angle (28.8 degrees by default). Steeper than that, it can only
## climb by arriving fast and coasting up before gravity stops it.

@export_group("Feel knobs")
## How heavy the tank feels. 1 = the normal tank, 2 = twice as heavy.
## Heavier = slower to speed up, brake and turn, coasts further when idling,
## and the hull picture follows the ground more lazily.
@export_range(0.1, 10.0, 0.05, "or_greater") var weight: float = 1.0

## Top speed of each tread, in metres per second (10 m/s is 36 km/h).
## Also sets how far a run-up carries the tank up a steep slope.
@export_range(0.0, 50.0, 0.5, "or_greater") var top_speed: float = 10.0

## How hard the treads push, in metres per second per second, for a tank of
## weight 1. The real push is pulling_power / weight. It is also the brake's
## strength. Higher = quicker take-off and better climbing, until grip runs out.
@export_range(0.0, 30.0, 0.1, "or_greater") var pulling_power: float = 5.0

## The steepest slope the treads can hold, in degrees. Below it the tank can
## stop and hold (with the brake) and, with enough pulling power, climb from a
## standstill. Above it, only a run-up gets it up. 28.8 is the original grip.
@export_range(0.0, 80.0, 0.01) var grip: float = 28.8108

## How much the tank resists sliding sideways when turning at speed.
## 1 = no slide at all (on rails). Lower = part of the speed carries on in the
## old direction and fades away: 0.5 a short drift, 0.2 a long one.
@export_range(0.0, 1.0, 0.01) var sideways_grip: float = 1.0

## How much the hull picture sways, from 0 (rigid) to 1 (very swaying): it
## rocks back when speeding up, dips forward when braking and leans out in
## turns. Looks only: it never changes where the tank goes or the cameras.
@export_range(0.0, 1.0, 0.01) var tippiness: float = 0.0

@export_group("Advanced (do not usually touch)")
## Speed each tread loses to friction, in metres per second, per second.
## Small. It only matters when nothing else is slowing the tank.
@export var rolling_resistance: float = 0.1

## How hard a tread at level 0 resists rolling, in metres per second lost
## each second, for a tank of weight 1 (the real drag is idle_drag / weight):
## the idling engine and gearbox hold it back. So with one lever at 0 the tank
## swings round that tread, and with both at 0 it comes to a stop by itself
## (3 = about 3.3 s from 10 m/s). Unlike the brake, it can't hold the tank on
## slopes steeper than about atan(idle_drag / g) (18° at 3).
@export var idle_drag: float = 3.0

## Where the engine starts to run out of pull, as a fraction of top speed.
## Below this speed the treads push at full strength; above it the push fades
## toward power_at_top_speed. 1 = never fades (no limit).
## Example: 0.5 = full pull up to 5 m/s, then weaker. Only affects speeding up,
## never braking, and slow climbing below this speed is unchanged.
@export_range(0.0, 1.0) var power_falloff_start: float = 1.0

## How much pull is left at top speed, as a fraction of full strength.
## 1 = no fade. 0.3 = only 30% left, so the last stretch to top speed is slow.
## At 0 the tank creeps toward top speed but never quite reaches it.
@export_range(0.0, 1.0) var power_at_top_speed: float = 1.0

## How long each tread's engine takes to warm up from nothing to full push,
## in seconds, whenever you ask for more power. 0 = instant. From a standstill
## or steady driving the push builds up over this time; if the tread is still
## speeding up (the engine already pushing hard), more power comes at once.
## Braking is never delayed.
@export var warm_up_time: float = 0.0

## Gravity, in metres per second, per second. Earth is 9.8.
@export var g: float = 9.8

## Distance between the two treads, in metres. Wider = turns more slowly
## for the same difference in tread speed.
@export var track_width: float = 3.0

## How much turning is held back, from 0 (turns freely) to 1 (cannot turn),
## for a tank of weight 1. A heavier tank turns more slowly still: what is
## left is divided by weight.
@export_range(0.0, 1.0) var turn_resistance: float = 0.75

## How much turning holds the tank back: the treads scrape sideways over the
## ground. While turning, the speed the treads can reach is divided by
## (1 + turn_scrub x turning speed in radians per second), so the engine can't
## make it back. 0 = turning costs nothing. Driving straight is never affected.
## Sharper turns lose the most: at 2, a one-tread pivot creeps round and
## spinning on the spot is slow and heavy.
@export var turn_scrub: float = 2.0

## How quickly a sideways slide fades at sideways_grip 0.5, per second.
## Other sideways_grip values are worked out from it (see TankFeel).
@export var slide_decay_scale: float = 3.0

## Gravity in the air, as a multiple of g. Only affects jumps and falls, not
## slopes. Below 1 = more hang time and floatier jumps; above 1 = heavier.
@export_range(0.1, 3.0) var air_gravity_scale: float = 1.0

## How much the hull tips to follow its flight path in the air, from 0 (eases
## back to level) to 1 (points exactly where it is heading, so it arcs over and
## lands nose-first). Only affects the picture and the slit view.
@export_range(0.0, 1.0) var nose_dip: float = 0.0

## Speed lost on a hard landing, from 0 (none) to 1. At 1, landing from a
## 10 m/s fall (about a 5 m drop) stops the treads dead; softer landings lose
## proportionally less.
@export_range(0.0, 1.0) var landing_speed_loss: float = 0.0

## How quickly the hull tilts to match the ground, for a tank of weight 1
## (divided by weight). Higher = snappier, lower = smoother and floatier.
## Only affects the picture, not the driving.
@export var tilt_smoothing: float = 8.0

## How far the hull sways at tippiness 1, in degrees per (metre per second
## per second) of speeding up, braking or turning. Looks only.
@export var sway_degrees_per_accel: float = 1.5


# --- Worked out from the knobs (read-only in practice) ---------------------
# The older names below are kept so code and notes that use them still work.
# Setting one sets the knob it comes from.

## Top speed of each tread (the top_speed knob).
var max_tread_speed: float:
	get:
		return top_speed
	set(value):
		top_speed = value

## The hardest each tread can push (and brake), in m/s per second:
## pulling_power / weight.
var max_drive_accel: float:
	get:
		return pulling_power / maxf(weight, 0.01)
	set(value):
		pulling_power = value * weight

## Grip as a friction number: tan(grip angle). 0.55 = about 28.8 degrees.
var traction_coeff: float:
	get:
		return tan(deg_to_rad(clampf(grip, 0.0, 89.0)))
	set(value):
		grip = rad_to_deg(atan(value))


## The steepest slope the engine alone could climb, in degrees: where gravity's
## pull down the slope equals the push (pulling_power / weight).
func engine_limit_degrees() -> float:
	return rad_to_deg(asin(clampf(max_drive_accel / g, 0.0, 1.0))) if g > 0.0 else 90.0


## The steepest slope the tank can climb from a standstill, in degrees: the
## lower of the grip angle and the engine's limit.
func climbable_limit_degrees() -> float:
	return minf(grip, engine_limit_degrees())


## Drag on a tread at level 0, after weight: idle_drag / weight.
func effective_idle_drag() -> float:
	return idle_drag / maxf(weight, 0.01)


## What is left of the turn after turn resistance and weight (1 = turns freely).
func turn_factor() -> float:
	return (1.0 - turn_resistance) / maxf(weight, 0.01)


## How quickly the hull picture follows the ground, after weight.
func effective_tilt_smoothing() -> float:
	return tilt_smoothing / maxf(weight, 0.01)


## How fast a sideways slide fades, per second (INF = no slide).
func slide_decay_rate() -> float:
	return TankFeel.slide_decay_rate(sideways_grip, slide_decay_scale)


## The rows the Tab panel shows for this tuning, knobs first. Each row: group
## heading, value name, slider range and step (a comfortable dragging range:
## typed values can go past it), then hard limits only where the maths breaks.
func panel_settings() -> Array[Dictionary]:
	var knobs: String = "Feel knobs"
	var advanced: String = "Advanced (do not usually touch)"
	return [
		# Weight divides things, so it can't be 0.
		TankFeel.panel_row(knobs, &"weight", 0.1, 5.0, 0.05, 0.1),
		TankFeel.panel_row(knobs, &"top_speed", 0.0, 50.0, 0.5, 0.1),
		TankFeel.panel_row(knobs, &"pulling_power", 0.0, 30.0, 0.1),
		# tan() of the angle: 90 degrees would be infinite grip.
		TankFeel.panel_row(knobs, &"grip", 0.0, 80.0, 0.5, 0.0, 89.0),
		TankFeel.panel_row(knobs, &"sideways_grip", 0.0, 1.0, 0.01, 0.0, 1.0),
		TankFeel.panel_row(knobs, &"tippiness", 0.0, 1.0, 0.01),
		TankFeel.panel_row(advanced, &"rolling_resistance", 0.0, 5.0, 0.05),
		TankFeel.panel_row(advanced, &"idle_drag", 0.0, 10.0, 0.1),
		# Fractions of top speed / of full pull: only 0 to 1 make sense.
		TankFeel.panel_row(advanced, &"power_falloff_start", 0.0, 1.0, 0.05, 0.0, 1.0),
		TankFeel.panel_row(advanced, &"power_at_top_speed", 0.0, 1.0, 0.05, 0.0, 1.0),
		TankFeel.panel_row(advanced, &"warm_up_time", 0.0, 2.0, 0.05),
		TankFeel.panel_row(advanced, &"g", 0.0, 50.0, 0.1),
		TankFeel.panel_row(advanced, &"track_width", 0.1, 15.0, 0.1, 0.1),
		# Above 1 the tank would turn the wrong way.
		TankFeel.panel_row(advanced, &"turn_resistance", 0.0, 1.0, 0.01, 0.0, 1.0),
		TankFeel.panel_row(advanced, &"turn_scrub", 0.0, 6.0, 0.1),
		TankFeel.panel_row(advanced, &"slide_decay_scale", 0.0, 20.0, 0.1),
		TankFeel.panel_row(advanced, &"air_gravity_scale", 0.0, 5.0, 0.05),
		TankFeel.panel_row(advanced, &"nose_dip", 0.0, 2.0, 0.05),
		# Above 1 a landing would reverse the treads.
		TankFeel.panel_row(advanced, &"landing_speed_loss", 0.0, 1.0, 0.05, 0.0, 1.0),
		TankFeel.panel_row(advanced, &"tilt_smoothing", 0.0, 60.0, 0.5),
		TankFeel.panel_row(advanced, &"sway_degrees_per_accel", 0.0, 10.0, 0.1),
	]
