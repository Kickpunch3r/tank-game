class_name TankTuning
extends Resource
## Every number that changes how the tank drives, in one place.
## Edit them by clicking tuning/tank_tuning.tres and changing values in the Inspector.
##
## How slopes come out of these numbers: the tank can only hold a slope if its
## grip (traction_coeff) is at least tan(slope angle). With traction_coeff 0.55
## that limit is about 29 degrees. Steeper than that, it can only climb by
## arriving fast and coasting up before gravity stops it.

@export_group("Speed")
## Top speed of each tread, in metres per second (10 m/s is 36 km/h).
@export var max_tread_speed: float = 10.0

## The hardest each tread's engine can push, in metres per second, per second.
## Higher = quicker to speed up and better at climbing, until grip runs out.
@export var max_drive_accel: float = 5.0

## Speed each tread loses to friction, in metres per second, per second.
## Small. It only matters when nothing else is slowing the tank.
@export var rolling_resistance: float = 0.1

## How hard a tread at level 0 resists rolling, in metres per second lost
## each second: the idling engine and gearbox hold it back. So with one lever
## at 0 the tank swings round that tread, and with both at 0 it comes to a
## stop by itself (3 = about 3.3 s from 10 m/s). Unlike the brake, it can't
## hold the tank on slopes steeper than about atan(idle_drag / g) (18° at 3).
@export var idle_drag: float = 3.0

@export_group("Engine power")
## Where the engine starts to run out of pull, as a fraction of top speed.
## Below this speed the treads push at full strength (max_drive_accel); above
## it the push fades toward power_at_top_speed. 1 = never fades (no limit).
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

@export_group("Grip and gravity")
## How well the treads grip the ground. 0 = ice, 1 = very grippy.
## The tank's push is capped at traction_coeff x g x cos(slope), so grip also
## sets the steepest slope the tank can sit on without sliding back.
@export var traction_coeff: float = 0.55

## Gravity, in metres per second, per second. Earth is 9.8.
@export var g: float = 9.8

@export_group("Turning")
## Distance between the two treads, in metres. Wider = turns more slowly
## for the same difference in tread speed.
@export var track_width: float = 3.0

## How much turning is held back, from 0 (turns freely) to 1 (cannot turn).
## Raise it to make spinning in place feel heavier.
@export_range(0.0, 1.0) var turn_resistance: float = 0.75

## How much turning holds the tank back: the treads scrape sideways over the
## ground. While turning, the speed the treads can reach is divided by
## (1 + turn_scrub x turning speed in radians per second), so the engine can't
## make it back. 0 = turning costs nothing. Driving straight is never affected.
## Sharper turns lose the most: at 2, a one-tread pivot creeps round and
## spinning on the spot is slow and heavy.
@export var turn_scrub: float = 2.0

@export_group("Air and landing")
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

@export_group("Looks")
## How quickly the hull tilts to match the ground. Higher = snappier,
## lower = smoother and floatier. Only affects the picture, not the driving.
@export var tilt_smoothing: float = 8.0
