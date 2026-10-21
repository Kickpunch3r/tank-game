class_name ViewSwitcher
extends Node
## Switches which camera is showing when V is pressed (Input Map: view_toggle).
## Each view is a camera with a set_view_active(bool) method, so it can take
## care of its own extras (like the slit mask). Later, each view could instead
## render to its own screen and this switcher would not be needed.

## The cameras to cycle through, in order. The first one starts active.
@export var views: Array[Camera3D] = []

var current_index: int = 0


func _ready() -> void:
	show_view(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"view_toggle"):
		show_view((current_index + 1) % maxi(views.size(), 1))


## Turn on view number `index` and turn the others off.
func show_view(index: int) -> void:
	current_index = index
	for i: int in views.size():
		var view: Camera3D = views[i]
		if is_instance_valid(view) and view.has_method(&"set_view_active"):
			view.set_view_active(i == index)


func current_view_name() -> String:
	if current_index < views.size() and is_instance_valid(views[current_index]):
		return views[current_index].name
	return "none"
