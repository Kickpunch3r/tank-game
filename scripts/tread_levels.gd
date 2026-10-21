class_name TreadLevels
extends RefCounted
## The notches a tread lever clicks between, used by the keyboard and (sent
## by the game) the phone page, so they always agree. Each lever has 3 levels
## forward and 3 back, plus 0:
##   level  -3    -2     -1     0    1     2    3
##   value  -1   -0.5  -0.25    0  0.25  0.5   1

## Push for levels 1, 2 and 3 (the same backwards, negative).
const VALUES: Array[float] = [0.25, 0.5, 1.0]

## Highest level.
const MAX_LEVEL: int = 3


## The tread push for a level from -3 to 3.
static func value_for(level: int) -> float:
	if level == 0:
		return 0.0
	var index: int = clampi(absi(level), 1, MAX_LEVEL) - 1
	return VALUES[index] * signf(level)


## All 7 notch values from full back to full forward, e.g. for the phone page.
static func all_notches() -> Array[float]:
	var notches: Array[float] = []
	for level: int in range(-MAX_LEVEL, MAX_LEVEL + 1):
		notches.append(value_for(level))
	return notches
