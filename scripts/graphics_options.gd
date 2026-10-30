class_name GraphicsOptions
extends RefCounted
## Graphics extras that can be switched off from the Tab panel (Graphics
## section) if they slow the game down. All on at the start; changes last
## until you quit, like the rest of the panel.
##
## Things that change how the game plays (trees, rocks) are never switched off.

## Group of things to show or hide with each option.
const TANK_DETAILS_GROUP: StringName = &"graphics_tank_details"
const DUST_GROUP: StringName = &"graphics_dust"
const SCENERY_GROUP: StringName = &"graphics_scenery"

## Road wheels and moving tracks on the physics tank.
static var tank_details: bool = true
## Dust and mud spray behind the treads.
static var dust: bool = true
## Bushes (looks only; trees and rocks stay, as they are solid).
static var scenery: bool = true
## The sun's shadows.
static var shadows: bool = true
## Distance haze (the misty forest stays misty either way).
static var haze: bool = true


## The options in the order the Tab panel lists them, with their labels.
const LABELS: Dictionary = {
	&"tank_details": "Tank details (road wheels, moving tracks)",
	&"dust": "Dust and spray behind the treads",
	&"scenery": "Bushes",
	&"shadows": "Shadows",
	&"haze": "Distance haze (the misty forest stays misty)",
}


static func is_on(option: StringName) -> bool:
	match option:
		&"tank_details": return tank_details
		&"dust": return dust
		&"scenery": return scenery
		&"shadows": return shadows
		&"haze": return haze
	push_error("Unknown graphics option: %s" % option)
	return false


## Switch one option on or off, and show or hide things to match.
static func set_on(tree: SceneTree, option: StringName, on: bool) -> void:
	match option:
		&"tank_details": tank_details = on
		&"dust": dust = on
		&"scenery": scenery = on
		&"shadows": shadows = on
		&"haze": haze = on
		_: push_error("Unknown graphics option: %s" % option)
	apply(tree)


## Show or hide everything to match the options (called after a change).
static func apply(tree: SceneTree) -> void:
	for item: Array in [[TANK_DETAILS_GROUP, tank_details], [DUST_GROUP, dust], [SCENERY_GROUP, scenery]]:
		for node: Node in tree.get_nodes_in_group(item[0]):
			if node is Node3D:
				(node as Node3D).visible = item[1]
	for node: Node in tree.root.find_children("*", "DirectionalLight3D", true, false):
		(node as DirectionalLight3D).shadow_enabled = shadows
