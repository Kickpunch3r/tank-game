class_name Tank
extends CharacterBody3D
## The tank's body: it moves and collides. What it looks like lives in the
## child "Visual" node, so the art can be swapped without touching this script.
##
## Milestone 1: the tank only falls and rests on the ground.
## Tread driving arrives in milestone 3.

## How fast the tank falls when it is in the air (metres per second, per second).
## Temporary: this moves into the TankTuning resource in milestone 3.
@export var fall_gravity: float = 9.8


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= fall_gravity * delta
	move_and_slide()
