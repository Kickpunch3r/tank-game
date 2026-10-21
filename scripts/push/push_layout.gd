class_name PushLayout
extends RefCounted
## Which Push 3 pad does what. Pads are an 8 x 8 grid: column 0 = left,
## row 0 = bottom. Each pad sends MIDI note 36 + row x 8 + column
## (36 = bottom-left, 99 = top-right).
##
##   row 7   .  .  .  .  .  .  .  .     (free, for later)
##   row 6   L  L  .  .  .  .  R  R     level +3 (full forward)
##   row 5   L  L  .  .  .  .  R  R     level +2
##   row 4   L  L  .  B  B  .  R  R     level +1
##   row 3   L  L  .  B  B  .  R  R     level 0
##   row 2   L  L  .  .  .  .  R  R     level -1
##   row 1   L  L  .  .  .  .  R  R     level -2
##   row 0   L  L  .  .  .  .  R  R     level -3 (full back)
##
## L / R = left / right tread lever (two columns wide, easy to hit without
## looking), B = brake (a 2 x 2 square in the middle). The lever levels are
## the shared TreadLevels.

const FIRST_NOTE: int = 36
const COLUMNS: int = 8
const ROWS: int = 8

const LEFT_LEVER_COLUMNS: Array[int] = [0, 1]
const RIGHT_LEVER_COLUMNS: Array[int] = [6, 7]
## Rows 0 to 6 are the 7 notches; this row is level 0.
const ZERO_ROW: int = 3
const BRAKE_COLUMNS: Array[int] = [3, 4]
const BRAKE_ROWS: Array[int] = [3, 4]

## What a pad is for.
enum Kind { NONE, LEFT_LEVER, RIGHT_LEVER, BRAKE }


static func note_for(column: int, row: int) -> int:
	return FIRST_NOTE + row * COLUMNS + column


## What a MIDI note's pad does: {"kind": Kind, "level": int (levers only)}.
static func describe(note: int) -> Dictionary:
	var index: int = note - FIRST_NOTE
	if index < 0 or index >= COLUMNS * ROWS:
		return {"kind": Kind.NONE, "level": 0}
	return describe_pad(index % COLUMNS, index / COLUMNS)


static func describe_pad(column: int, row: int) -> Dictionary:
	var level: int = row - ZERO_ROW
	var on_lever_rows: bool = absi(level) <= TreadLevels.MAX_LEVEL
	if on_lever_rows and LEFT_LEVER_COLUMNS.has(column):
		return {"kind": Kind.LEFT_LEVER, "level": level}
	if on_lever_rows and RIGHT_LEVER_COLUMNS.has(column):
		return {"kind": Kind.RIGHT_LEVER, "level": level}
	if BRAKE_COLUMNS.has(column) and BRAKE_ROWS.has(row):
		return {"kind": Kind.BRAKE, "level": 0}
	return {"kind": Kind.NONE, "level": 0}


## The lever level (-3 to 3) whose push is closest to `value` (-1 to 1).
static func nearest_level(value: float) -> int:
	var best: int = 0
	for level: int in range(-TreadLevels.MAX_LEVEL, TreadLevels.MAX_LEVEL + 1):
		if absf(TreadLevels.value_for(level) - value) < absf(TreadLevels.value_for(best) - value):
			best = level
	return best
