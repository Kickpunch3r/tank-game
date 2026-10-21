class_name PhysicsTankTuning
extends Resource
## Every number that changes how the physics tank drives, in one place.
## Edit them by clicking tuning/physics_tank_tuning.tres.
##
## The first six are the feel knobs, with the same names and meanings as the
## kinematic tank's (TankTuning), so a preset like "heavy" means the same in
## both. Everything under "Advanced" is worked out once and usually stays.
## The springs' stiffness and damping are not values at all: they are worked
## out from weight (see spring_stiffness() and spring_damping()).

@export_group("Feel knobs")
## How heavy the tank feels. 1 = the normal tank, 2 = twice as heavy.
## Sets the mass: heavier = slower to speed up, brake and turn, more momentum.
@export_range(0.1, 10.0, 0.05, "or_greater") var weight: float = 1.0

## Top speed of each tread, in metres per second (10 m/s is 36 km/h). The
## treads' push fades to nothing as they reach it.
@export_range(0.0, 50.0, 0.5, "or_greater") var top_speed: float = 10.0

## How hard the treads push, in metres per second per second, for a tank of
## weight 1 (the real push is pulling_power / weight). Also the brake's strength.
@export_range(0.0, 30.0, 0.1, "or_greater") var pulling_power: float = 5.0

## The steepest slope the treads can hold, in degrees. Each contact point can
## push at most tan(grip) x how hard it is pressed into the ground, so a
## lifted tread or a steep slope loses grip by itself.
@export_range(0.0, 80.0, 0.01) var grip: float = 28.8108

## How much the tank resists sliding sideways, from 0 (ice) to 1 (as firm as
## its grip allows). Same meaning as the kinematic tank's.
@export_range(0.0, 1.0, 0.01) var sideways_grip: float = 1.0

## How easily it tips, from 0 (centre of mass very low: stable) to 1 (high:
## tippy). Unlike the kinematic tank's, this is real: it changes how the body
## rocks, leans and whether it rolls over.
@export_range(0.0, 1.0, 0.01) var tippiness: float = 0.3

@export_group("Advanced (do not usually touch)")
## Mass of a tank of weight 1, in kilograms.
@export var base_mass: float = 30000.0

## How far the hull sinks onto its springs at rest, as a fraction of the
## spring length. The springs' stiffness is worked out from this and weight.
@export_range(0.02, 0.6) var target_sag: float = 0.15

## How quickly the springs stop bouncing, as a fraction of "critical"
## damping (1 = settles without bouncing at all, lower = bouncier).
@export_range(0.05, 2.0) var damping_ratio: float = 0.45

## Length of each spring with no weight on it, in metres.
@export var spring_length: float = 1.0

## How quickly the treads chase the speed the levers ask for, per second.
## Higher = snappier throttle. The push is still capped by pulling_power.
@export var throttle_response: float = 5.0

## Speed each tread loses to friction, in metres per second, per second.
@export var rolling_resistance: float = 0.1

## How hard a tread at level 0 resists rolling, in metres per second lost each
## second, for a tank of weight 1 (divided by weight). Same as the kinematic tank's.
@export var idle_drag: float = 3.0

## How strongly the contact points resist sideways sliding at sideways_grip 1,
## per second. Sideways grip scales it (see TankFeel.slide_decay_rate).
@export var slide_decay_scale: float = 3.0

## How strongly the treads resist being dragged sideways at sideways_grip 1,
## per second. It is also what makes turning heavy: a turning tank drags the
## front and back of its treads sideways. Lower = spins faster but drifts
## more in turns. (Above about 30 the force overshoots in one physics frame.)
@export var max_sideways_rate: float = 6.0

## Height of the centre of mass above the tread bottoms, in metres, at
## tippiness 0 and at tippiness 1.
@export var low_centre_of_mass: float = 0.2
@export var high_centre_of_mass: float = 2.2

## Slowing of the whole body, as Godot's linear and angular damping. Small:
## just enough to calm tiny wobbles.
@export var linear_damping: float = 0.0
@export var angular_damping: float = 0.1


## The tank's mass in kilograms.
func mass() -> float:
	return base_mass * maxf(weight, 0.01)


## The treads' strongest push (and brake), in m/s per second.
func max_drive_accel() -> float:
	return pulling_power / maxf(weight, 0.01)


## Grip as a friction number: tan(grip angle).
func traction_coeff() -> float:
	return tan(deg_to_rad(clampf(grip, 0.0, 89.0)))


## Spring stiffness, in newtons per metre of squash, for one of `probe_count`
## springs: so that the tank's weight squashes each by target_sag of its length.
func spring_stiffness(probe_count: int, gravity: float) -> float:
	var weight_per_probe: float = mass() * gravity / probe_count
	return weight_per_probe / (target_sag * spring_length)


## Spring damping, in newtons per metre per second: damping_ratio of
## "critical" damping for the share of mass on one spring.
func spring_damping(probe_count: int, gravity: float) -> float:
	var mass_per_probe: float = mass() / probe_count
	return damping_ratio * 2.0 * sqrt(spring_stiffness(probe_count, gravity) * mass_per_probe)


## Height of the centre of mass above the tread bottoms, in metres.
func centre_of_mass_height() -> float:
	return lerpf(low_centre_of_mass, high_centre_of_mass, clampf(tippiness, 0.0, 1.5))


## How strongly sideways sliding is resisted, per second.
func sideways_rate() -> float:
	return minf(TankFeel.slide_decay_rate(sideways_grip, slide_decay_scale), max_sideways_rate)


## The steepest slope the engine alone could climb, in degrees.
func engine_limit_degrees(gravity: float = 9.8) -> float:
	return rad_to_deg(asin(clampf(max_drive_accel() / gravity, 0.0, 1.0)))


## The steepest slope the tank can climb from a standstill, in degrees.
func climbable_limit_degrees() -> float:
	return minf(grip, engine_limit_degrees())


## The rows the Tab panel shows for this tuning, knobs first (see TankTuning).
func panel_settings() -> Array[Dictionary]:
	var knobs: String = "Feel knobs (physics tank)"
	var advanced: String = "Advanced, physics tank (do not usually touch)"
	return [
		TankFeel.panel_row(knobs, &"weight", 0.1, 5.0, 0.05, 0.1),
		TankFeel.panel_row(knobs, &"top_speed", 0.0, 50.0, 0.5, 0.1),
		TankFeel.panel_row(knobs, &"pulling_power", 0.0, 30.0, 0.1),
		TankFeel.panel_row(knobs, &"grip", 0.0, 80.0, 0.5, 0.0, 89.0),
		TankFeel.panel_row(knobs, &"sideways_grip", 0.0, 1.0, 0.01, 0.0, 1.0),
		TankFeel.panel_row(knobs, &"tippiness", 0.0, 1.0, 0.01, 0.0, 1.5),
		TankFeel.panel_row(advanced, &"base_mass", 1000.0, 100000.0, 500.0, 1.0),
		# Fractions of the spring: 0 would be infinitely stiff.
		TankFeel.panel_row(advanced, &"target_sag", 0.02, 0.6, 0.01, 0.01, 0.9),
		TankFeel.panel_row(advanced, &"damping_ratio", 0.05, 2.0, 0.05, 0.0),
		TankFeel.panel_row(advanced, &"throttle_response", 0.5, 20.0, 0.5),
		TankFeel.panel_row(advanced, &"rolling_resistance", 0.0, 5.0, 0.05),
		TankFeel.panel_row(advanced, &"idle_drag", 0.0, 10.0, 0.1),
		TankFeel.panel_row(advanced, &"slide_decay_scale", 0.0, 20.0, 0.1),
		TankFeel.panel_row(advanced, &"max_sideways_rate", 0.0, 40.0, 0.5),
		TankFeel.panel_row(advanced, &"low_centre_of_mass", -1.0, 3.0, 0.05, -INF),
		TankFeel.panel_row(advanced, &"high_centre_of_mass", -1.0, 4.0, 0.05, -INF),
		TankFeel.panel_row(advanced, &"linear_damping", 0.0, 2.0, 0.01),
		TankFeel.panel_row(advanced, &"angular_damping", 0.0, 5.0, 0.05),
	]
