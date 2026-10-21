@tool
class_name LevelStart
extends Marker3D
## Where the tank starts in a level, and which way it faces (along the yellow
## arrow, the node's -Z). Only its position across the ground and its turn
## matter: the tank is always placed on the ground surface below or above it.

func _ready() -> void:
	if Engine.is_editor_hint():
		_add_arrow()


## A yellow arrow, shown only in the editor, pointing the way the tank will face.
func _add_arrow() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.6, 0.6, 6.0)
	shaft.material = material
	var head := PrismMesh.new()
	head.size = Vector3(2.4, 2.4, 0.6)
	head.material = material
	var shaft_visual := MeshInstance3D.new()
	shaft_visual.mesh = shaft
	shaft_visual.position = Vector3(0.0, 1.0, -3.0)
	add_child(shaft_visual)
	var head_visual := MeshInstance3D.new()
	head_visual.mesh = head
	# Prism points up (+Y) by default; turn it to point forward (-Z).
	head_visual.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, 1.0, -7.0))
	add_child(head_visual)
