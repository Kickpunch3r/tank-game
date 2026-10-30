class_name TankFeel
extends Resource
## Shared helpers for the feel knobs of both tanks (TankTuning and
## PhysicsTankTuning): the six knob names they have in common, how sideways
## grip turns into a slide fade rate, and the Tab panel's row format.
## (It used to hold the feel presets too; those were removed when the Heavy
## physics tank was chosen.)

## The six knobs both tanks share, by name, with the same meaning in each.
const KNOB_NAMES: Array[StringName] = [
	&"weight", &"top_speed", &"pulling_power", &"grip", &"sideways_grip", &"tippiness",
]


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
