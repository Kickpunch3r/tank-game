class_name DriverStation
extends Node
## The driver's seat. The tank reads only these values, never the keyboard or
## gamepad directly, so any kind of controller can drive it.
##
## Each physics frame the station asks its DriverInputSource children what they
## read and combines them: for each tread, whichever source is pushed hardest
## wins. Reset fires if any source pressed it.
## Exception: if any source is taking over (e.g. a phone that is actively
## driving), only the sources taking over are listened to for the treads.

## Left tread push, from -1 (full back) to 1 (full forward).
var left_tread: float = 0.0

## Right tread push, from -1 (full back) to 1 (full forward).
var right_tread: float = 0.0

## True for one physics frame when a reset was asked for.
var reset_requested: bool = false

## When false, the station ignores its input sources and keeps whatever values
## were written into it. Tests turn this off to drive the tank directly.
@export var listen_to_input_sources: bool = true


func _ready() -> void:
	# Run before the tank each physics frame, so the tank sees this frame's input.
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if listen_to_input_sources:
		_combine_input_sources()


func _combine_input_sources() -> void:
	var sources: Array[DriverInputSource] = []
	var any_taking_over: bool = false
	for child: Node in get_children():
		var source := child as DriverInputSource
		if source != null:
			sources.append(source)
			any_taking_over = any_taking_over or source.takes_over()
	var combined_left: float = 0.0
	var combined_right: float = 0.0
	var any_reset: bool = false
	for source: DriverInputSource in sources:
		any_reset = any_reset or source.is_reset_just_pressed()
		if any_taking_over and not source.takes_over():
			continue
		combined_left = _stronger_push(combined_left, source.get_left_tread())
		combined_right = _stronger_push(combined_right, source.get_right_tread())
	left_tread = clampf(combined_left, -1.0, 1.0)
	right_tread = clampf(combined_right, -1.0, 1.0)
	reset_requested = any_reset


func _stronger_push(a: float, b: float) -> float:
	return b if absf(b) > absf(a) else a
