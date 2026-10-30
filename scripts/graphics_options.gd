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


## Show or hide everything to match the options (called after a change).
static func apply(tree: SceneTree) -> void:
	for item: Array in [[TANK_DETAILS_GROUP, tank_details], [DUST_GROUP, dust], [SCENERY_GROUP, scenery]]:
		for node: Node in tree.get_nodes_in_group(item[0]):
			if node is Node3D:
				(node as Node3D).visible = item[1]
	for node: Node in tree.root.find_children("*", "DirectionalLight3D", true, false):
		(node as DirectionalLight3D).shadow_enabled = shadows
