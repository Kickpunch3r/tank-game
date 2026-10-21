class_name TankFeel
extends Resource
## A feel preset: just the six feel knobs, with no tank-specific values.
## The same preset file works for the kinematic tank (TankTuning) and the
## physics tank, so "heavy" means the same thing in both.
##
## Applying a preset copies these six values onto a tank's tuning (in memory
## only, like the Tab panel). Everything else in that tuning stays as it was.

## The six knobs, by name. Every tank tuning resource has a value with each
## of these names, meaning the same thing.
const KNOB_NAMES: Array[StringName] = [
	&"weight", &"top_speed", &"pulling_power", &"grip", &"sideways_grip", &"tippiness",
]

## Name shown in the HUD, e.g. "Heavy".
@export var display_name: String = ""

## How heavy the tank feels. 1 = the normal tank, 2 = twice as heavy.
@export_range(0.1, 10.0, 0.05, "or_greater") var weight: float = 1.0

## Top speed of each tread, in metres per second (10 m/s is 36 km/h).
@export_range(0.0, 50.0, 0.5, "or_greater") var top_speed: float = 10.0

## How hard the treads push, in metres per second per second for a tank of
## weight 1 (a heavier tank speeds up and brakes more slowly).
@export_range(0.0, 30.0, 0.1, "or_greater") var pulling_power: float = 5.0

## The steepest slope the treads can hold, in degrees.
@export_range(0.0, 80.0, 0.01) var grip: float = 28.8108

## How much the tank resists sliding sideways in turns: 1 = not at all
## (rails), lower = more drift.
@export_range(0.0, 1.0, 0.01) var sideways_grip: float = 1.0

## How tippy the tank is, from 0 (rigid, stable) to 1 (very swaying).
@export_range(0.0, 1.0, 0.01) var tippiness: float = 0.0


## Copy the six knobs onto a tank's tuning resource.
func apply_to(tuning: Resource) -> void:
	for knob: StringName in KNOB_NAMES:
		tuning.set(knob, get(knob))


## True if a tank's tuning has exactly this preset's six knob values.
func matches(tuning: Resource) -> bool:
	for knob: StringName in KNOB_NAMES:
		if not is_equal_approx(float(tuning.get(knob)), float(get(knob))):
			return false
	return true


## How fast a sideways slide fades away, in "per second" (higher = shorter
## slide), for a sideways_grip value. Shared by both tanks so the knob reads
## the same. 1 = no slide at all (INF).
static func slide_decay_rate(sideways_grip_value: float, decay_scale: float) -> float:
	if sideways_grip_value >= 1.0:
		return INF
	var grip_fraction: float = clampf(sideways_grip_value, 0.0, 1.0)
	# 0.5 -> decay_scale; towards 1 -> very fast; towards 0 -> only the floor.
	return SLIDE_DECAY_FLOOR + decay_scale * grip_fraction / (1.0 - grip_fraction)


## Even with sideways_grip at 0, a slide fades at least this fast (per second),
## so the tank never drifts forever.
const SLIDE_DECAY_FLOOR: float = 0.3


## One row for the Tab panel (see TankTuning.panel_settings()).
static func panel_row(group: String, property: StringName, slider_min: float, slider_max: float,
		step: float, hard_min: float = 0.0, hard_max: float = INF) -> Dictionary:
	return {"group": group, "property": property, "min": slider_min, "max": slider_max,
			"step": step, "hard_min": hard_min, "hard_max": hard_max}
