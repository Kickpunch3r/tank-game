class_name ThrottleDisplay
extends CanvasLayer
## Two simple throttle bars, bottom-left and bottom-right of the screen: one
## per tread, with its 7 notches (3 forward, stop, 3 back). The lit notches show
## where the lever is. The top notch is the turbo: drawn bigger, in orange, and
## it flashes while engaged. (Turbo is the look of the full level; it pushes no
## harder than before.)
##
## It shows what the active tank is actually being told (its DriverStation),
## so it follows the keyboard, the phone and the Push 3. It sits above the
## driver's slit mask, so it shows in both views.

## The rig, to find the tank being driven.
@export var rig: PlayerRig

## Distance from the bottom of the screen, in pixels (leaves room for the
## phone status line).
@export var bottom_margin: float = 44.0

## Distance from the left and right edges, in pixels.
@export var side_margin: float = 24.0

const NOTCH_WIDTH: float = 92.0
const NOTCH_HEIGHT: float = 44.0
const TURBO_HEIGHT: float = 68.0
const GAP: float = 8.0
## Size of the L / R and BRAKE text.
const FONT_SIZE: int = 32
## Turbo flashes this many times a second while engaged.
const FLASHES_PER_SECOND: float = 3.0

const DIM := Color(0.15, 0.15, 0.15, 0.55)
const ZERO_DIM := Color(0.4, 0.4, 0.4, 0.6)
const FORWARD := Color(0.3, 0.9, 0.35)
const REVERSE := Color(0.3, 0.6, 1.0)
const STOPPED := Color(0.95, 0.95, 0.95)
const TURBO := Color(1.0, 0.55, 0.1)
const TURBO_DIM := Color(0.45, 0.25, 0.05, 0.6)
const TURBO_FLASH := Color(1.0, 0.95, 0.7)
const BRAKE := Color(1.0, 0.2, 0.15)

var _canvas: Control
var _time: float = 0.0


func _ready() -> void:
	# Above the slit mask (5), below the debug display (10) and Tab panel (20).
	layer = 6
	_canvas = Control.new()
	_canvas.name = "Bars"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bars)
	add_child(_canvas)


func _process(delta: float) -> void:
	_time += delta
	# Redrawn from the station's state every frame.
	_canvas.queue_redraw()


## Each lever's level, from -3 (full back) to 3 (turbo): x = left, y = right.
func levels() -> Vector2i:
	var station: DriverStation = _station()
	if station == null:
		return Vector2i.ZERO
	return Vector2i(level_for(station.left_tread), level_for(station.right_tread))


## True while the brake is held.
func braking() -> bool:
	var station: DriverStation = _station()
	return station != null and station.brake


## The nearest notch to a lever value (a gamepad stick can sit between notches).
static func level_for(value: float) -> int:
	var best: int = 0
	var best_gap: float = INF
	for level: int in range(-TreadLevels.MAX_LEVEL, TreadLevels.MAX_LEVEL + 1):
		var gap: float = absf(TreadLevels.value_for(level) - value)
		if gap < best_gap:
			best_gap = gap
			best = level
	return best


func _station() -> DriverStation:
	if rig == null or not is_instance_valid(rig.active_tank):
		return null
	return rig.active_tank.get(&"driver_station") as DriverStation


func _draw_bars() -> void:
	var current: Vector2i = levels()
	var bottom: float = _canvas.size.y - bottom_margin
	_draw_bar(Vector2(side_margin, bottom), current.x, "L")
	_draw_bar(Vector2(_canvas.size.x - side_margin - NOTCH_WIDTH, bottom), current.y, "R")


## One bar, its bottom-left corner at `corner`.
func _draw_bar(corner: Vector2, level: int, side_name: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var y: float = corner.y
	# From full back (bottom) to turbo (top).
	for notch: int in range(-TreadLevels.MAX_LEVEL, TreadLevels.MAX_LEVEL + 1):
		var turbo: bool = notch == TreadLevels.MAX_LEVEL
		var height: float = TURBO_HEIGHT if turbo else NOTCH_HEIGHT
		y -= height
		_canvas.draw_rect(Rect2(corner.x, y, NOTCH_WIDTH, height), _notch_colour(notch, level))
		y -= GAP
	# The side's name under the bar, and BRAKE over it while braking.
	_canvas.draw_string(font, Vector2(corner.x, corner.y + FONT_SIZE + 2.0), side_name,
			HORIZONTAL_ALIGNMENT_CENTER, NOTCH_WIDTH, FONT_SIZE, Color(1, 1, 1, 0.85))
	if braking():
		_canvas.draw_string(font, Vector2(corner.x - 20.0, y - 10.0), "BRAKE",
				HORIZONTAL_ALIGNMENT_CENTER, NOTCH_WIDTH + 40.0, FONT_SIZE, BRAKE)


## Lit from the stop notch up (or down) to the lever's level, like a meter.
func _notch_colour(notch: int, level: int) -> Color:
	var turbo: bool = notch == TreadLevels.MAX_LEVEL
	if braking():
		return BRAKE if notch == 0 else (TURBO_DIM if turbo else DIM)
	if notch == 0:
		return STOPPED if level == 0 else ZERO_DIM
	var lit: bool = (level > 0 and notch > 0 and notch <= level) or (level < 0 and notch < 0 and notch >= level)
	if turbo:
		if not lit:
			return TURBO_DIM
		# Engaged: flashes between orange and a bright yellow-white.
		return TURBO.lerp(TURBO_FLASH, turbo_flash_amount())
	if not lit:
		return DIM
	return FORWARD if notch > 0 else REVERSE

## How far the engaged turbo notch is through its flash: 0 = orange, 1 = bright.
func turbo_flash_amount() -> float:
	return 0.5 + 0.5 * sin(TAU * FLASHES_PER_SECOND * _time)
