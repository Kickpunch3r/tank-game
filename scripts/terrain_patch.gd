@tool
class_name TerrainPatch
extends Node3D
## A rectangle of special ground (mud, sand...) lying on whatever is below it.
## Treads inside the rectangle use its TerrainType. Place, turn and tilt the
## node to lay the patch on flat ground or along a slope.
##
## This is a tool script: the coloured patch also shows in the editor, so you
## can see where it is while placing it.

## Patches find each other through this group.
const GROUP: StringName = &"terrain_patches"

## How far above and below the patch's surface still counts as "on" it, in metres.
const THICKNESS_ABOVE: float = 3.0
const THICKNESS_BELOW: float = 1.0

## What kind of ground this is.
@export var terrain: TerrainType:
	set(value):
		terrain = value
		_rebuild_visual()

## Width (X) and length (Z) of the patch, in metres.
@export var size: Vector2 = Vector2(20.0, 20.0):
	set(value):
		size = value
		_rebuild_visual()

## Draw the coloured patch. Turn off when the surface underneath is already
## coloured (e.g. a terrain ramp).
@export var show_visual: bool = true:
	set(value):
		show_visual = value
		_rebuild_visual()

var _visual: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	_rebuild_visual()


## Is this world position on the patch?
func contains(world_position: Vector3) -> bool:
	var local: Vector3 = to_local(world_position)
	return absf(local.x) <= size.x / 2.0 and absf(local.z) <= size.y / 2.0 \
			and local.y <= THICKNESS_ABOVE and local.y >= -THICKNESS_BELOW


## The terrain at a world position, from every patch in the scene, or else
## from a painted level's terrain map.
## Returns null for ordinary firm ground.
static func terrain_at(tree: SceneTree, world_position: Vector3) -> TerrainType:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var patch := node as TerrainPatch
		if patch != null and patch.terrain != null and patch.contains(world_position):
			return patch.terrain
	# Otherwise, a painted level's terrain map (see LevelTerrain).
	for node: Node in tree.get_nodes_in_group(LevelTerrain.GROUP):
		var level := node as LevelTerrain
		if level != null:
			var painted: TerrainType = level.terrain_at(world_position)
			if painted != null:
				return painted
	return null


func _rebuild_visual() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
		_visual = null
	if not show_visual or terrain == null:
		return
	var mesh := BoxMesh.new()
	# Thin slab sitting just above the surface, so it shows on top of the ground.
	mesh.size = Vector3(size.x, 0.04, size.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = terrain.colour
	material.roughness = 1.0
	mesh.material = material
	_visual = MeshInstance3D.new()
	_visual.mesh = mesh
	_visual.position = Vector3(0.0, 0.03, 0.0)
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
