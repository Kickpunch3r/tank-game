class_name LevelRoot
extends Node3D
## Put this on the root node of a level scene. When the level runs (F6, or
## loaded by the game), it adds the shared player rig (tank, cameras, debug
## display, Tab panel) unless the scene already has one, and puts the tank on
## the ground at the LevelStart marker. It also adds a kill-plane.
##
## Levels therefore only contain level things: the LevelTerrain, a LevelStart,
## the sky and sun, and (later) placed pieces.

## The player rig to add when the level runs.
@export var player_rig_scene: PackedScene = preload("res://scenes/player_rig.tscn")

## How far below the lowest ground the kill-plane sits, in metres.
@export var kill_plane_depth: float = 30.0

var terrain: LevelTerrain
var start: LevelStart
var tank: Tank


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	terrain = _find_child_of_type(self, "LevelTerrain") as LevelTerrain
	start = _find_child_of_type(self, "LevelStart") as LevelStart

	var rig: Node3D = get_node_or_null(^"PlayerRig")
	if rig == null:
		rig = player_rig_scene.instantiate()
		# Placed before it is added, so the tank's home is right from the start.
		rig.transform = start_transform()
		add_child(rig)
	tank = rig.get_node(^"Tank")
	_place_tank_at_start()
	if terrain != null:
		terrain.rebuilt.connect(_place_tank_at_start)

	var kill_plane := KillPlane.new()
	kill_plane.name = "KillPlane"
	kill_plane.position = Vector3(0.0, global_position.y - kill_plane_depth, 0.0)
	add_child(kill_plane)


## The start marker's place and facing, on the ground surface.
func start_transform() -> Transform3D:
	if start == null:
		return Transform3D.IDENTITY
	var where: Vector3 = start.global_position
	if terrain != null:
		where.y = terrain.height_at(where)
	# Keep only the marker's left/right turn, so the tank always starts upright.
	var facing: Vector3 = -start.global_basis.z
	var yaw: float = atan2(-facing.x, -facing.z)
	return Transform3D(Basis(Vector3.UP, yaw), where)


## Puts the tank at the start and makes that its home (the Tab panel's
## "Start field"). Runs again whenever the ground is rebuilt.
func _place_tank_at_start() -> void:
	var home: Transform3D = start_transform()
	home.origin.y += 0.3
	tank.set_home(home)
	tank.set_spawn(home)
	tank.reset_to_spawn()


func _find_child_of_type(node: Node, type_name: String) -> Node:
	for child: Node in node.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == type_name:
			return child
		var found: Node = _find_child_of_type(child, type_name)
		if found != null:
			return found
	return null
