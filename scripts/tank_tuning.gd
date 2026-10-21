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

@export_group("Looks")
## How quickly the hull tilts to match the ground. Higher = snappier,
## lower = smoother and floatier. Only affects the picture, not the driving.
@export var tilt_smoothing: float = 8.0
