class_name Tank
extends CharacterBody3D
## The tank's body: it moves and collides. What it looks like lives in the
## child "Visual" node, so the art can be swapped without touching this script.
## It never reads the keyboard or gamepad: all driving input comes from its
## DriverStation child.
##
## Milestone 2: the tank falls, rests on the ground, and resets to where it
## started. Tread driving arrives in milestone 3.

## How fast the tank falls when it is in the air (metres per second, per second).
## Temporary: this moves into the TankTuning resource in milestone 3.
@export var fall_gravity: float = 9.8

@onready var driver_station: DriverStation = $DriverStation

## Where the tank started, so reset can put it back.
var _spawn_transform: Transform3D


func _ready() -> void:
	_spawn_transform = global_transform


func _physics_process(delta: float) -> void:
	if driver_station.reset_requested:
		reset_to_spawn()
		return
	if not is_on_floor():
		velocity.y -= fall_gravity * delta
	move_and_slide()


## Put the tank back where it started, standing still.
func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
