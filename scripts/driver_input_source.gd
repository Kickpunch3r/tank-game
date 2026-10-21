class_name DriverInputSource
extends Node
## Base for anything that can drive the tank's treads: keyboard, gamepad, and
## later MIDI, serial or giant levers. Put one as a child of a DriverStation.
## Each source only reports what it reads; the station decides what to use.


## Left tread push, from -1 (full back) to 1 (full forward).
func get_left_tread() -> float:
	return 0.0


## Right tread push, from -1 (full back) to 1 (full forward).
func get_right_tread() -> float:
	return 0.0


## True only on the frame the reset control is first pressed.
func is_reset_just_pressed() -> bool:
	return false


## True while this source should be the only one listened to (e.g. a phone
## that is actively driving). Most sources never take over.
func takes_over() -> bool:
	return false
