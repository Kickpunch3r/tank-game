class_name ObjectiveMarker
extends Node3D
## Marks an objective so it can be seen from far away: put it on the marker
## (e.g. the big gold cube over the Proving Ground's goal). It turns slowly and
## bobs up and down around where it was placed.

## Turning speed, in degrees per second.
@export var turn_speed: float = 30.0

## How far it bobs above and below its place, in metres.
@export var bob_height: float = 0.6

## Seconds for one bob up and down.
@export var bob_seconds: float = 3.0

var _home_height: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_home_height = position.y


func _process(delta: float) -> void:
	_time += delta
	rotate_y(deg_to_rad(turn_speed) * delta)
	position.y = _home_height + bob_height * sin(TAU * _time / maxf(bob_seconds, 0.1))
