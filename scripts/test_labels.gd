class_name TestLabels
extends RefCounted
## The floating labels on the test pieces (ramp angles, the ledge strip, steps
## and crest). They start hidden; the Tab panel's Debug section has a tick box
## to show them.

const GROUP: StringName = &"test_labels"


## Put a new label in the group, hidden to start with.
static func add(label: Label3D) -> void:
	label.add_to_group(GROUP)
	label.visible = false


static func set_shown(tree: SceneTree, shown: bool) -> void:
	for node: Node in tree.get_nodes_in_group(GROUP):
		(node as Node3D).visible = shown


## True if the labels are showing (worked out from the labels themselves).
static func are_shown(tree: SceneTree) -> bool:
	var first: Node = tree.get_first_node_in_group(GROUP)
	return first != null and (first as Node3D).visible


static func exist(tree: SceneTree) -> bool:
	return tree.get_first_node_in_group(GROUP) != null
