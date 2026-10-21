class_name KillPlane
extends Area3D
## A huge flat trigger far below the ground. A tank that falls onto it is sent
## back to its reset point.

## Width and length of the trigger, in metres. Make it much bigger than the
## level so nothing can fall past its edges.
@export var size: Vector2 = Vector2(2000.0, 2000.0)


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 2.0, size.y)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Either kind of tank.
	if body.has_method(&"reset_to_spawn"):
		# Deferred: moving a body in the middle of a physics callback is unsafe.
		body.call_deferred(&"reset_to_spawn")
