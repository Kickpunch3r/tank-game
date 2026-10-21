class_name PlayerRig
extends Node3D
## The player's tank(s) with everything that follows them: chase camera, view
## switcher, debug display, Tab panel and feel presets.
##
## There are two tanks to compare: the kinematic Tank and the PhysicsTank.
## Only one is active at a time. T (Input Map: tank_swap) swaps them: the other
## tank appears where the active one is, facing the same way, at rest. The
## hidden tank is switched off completely (no input, no physics, not drawn).

## The tanks to swap between, in order. The first one starts active.
@export var tanks: Array[Node3D] = []

@export var chase_camera: ChaseCamera
@export var view_switcher: ViewSwitcher
@export var debug_hud: DebugHud
@export var tuning_panel: TuningPanel
@export var controller_server: ControllerServer

## Emitted after a swap, with the tank that is now active.
signal active_tank_changed(tank: Node3D)

## The tank being driven now.
var active_tank: Node3D

## Where the driver's slit camera sits in either tank.
const SLIT_CAMERA_PATH: NodePath = ^"Visual/Hull/DriverSlitCamera"


func _ready() -> void:
	if tanks.is_empty():
		return
	for tank: Node3D in tanks:
		if tank != tanks[0]:
			_switch_off(tank)
		# Bumping into things buzzes the driver's phone, whichever tank it is.
		if is_instance_valid(controller_server) and tank != controller_server.tank:
			tank.connect(&"bumped", func() -> void: controller_server.buzz(40))
	active_tank = tanks[0]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tank_swap"):
		swap_tank()
		get_viewport().set_input_as_handled()


## Swap to the next tank in the list.
func swap_tank() -> void:
	var live: Array[Node3D] = []
	for tank: Node3D in tanks:
		if is_instance_valid(tank):
			live.append(tank)
	if live.size() < 2 or not is_instance_valid(active_tank):
		return
	var old_tank: Node3D = active_tank
	var new_tank: Node3D = live[(live.find(old_tank) + 1) % live.size()]

	# Where the old tank is, upright, facing the same way (its left/right turn only).
	var facing: Vector3 = -old_tank.global_basis.z
	var yaw: float = atan2(-facing.x, -facing.z)
	var where := Transform3D(Basis(Vector3.UP, yaw), old_tank.global_position + Vector3.UP * 0.2)

	new_tank.call(&"set_spawn", old_tank.call(&"get_spawn"))
	new_tank.call(&"set_home", old_tank.call(&"get_home"))
	_copy_lever_positions(old_tank, new_tank)
	var old_slit: Node = old_tank.get_node(SLIT_CAMERA_PATH)
	_switch_off(old_tank)
	_switch_on(new_tank)
	new_tank.call(&"place_at", where)
	active_tank = new_tank
	_point_everything_at(new_tank, old_slit)
	active_tank_changed.emit(new_tank)


## The keyboard's tread levels are where the player left the levers, not part
## of the tank: carry them over (the phone's levers carry over by themselves).
func _copy_lever_positions(from_tank: Node3D, to_tank: Node3D) -> void:
	var from_keys := from_tank.get_node_or_null(^"DriverStation/KeyboardDriverInput") as KeyboardDriverInput
	var to_keys := to_tank.get_node_or_null(^"DriverStation/KeyboardDriverInput") as KeyboardDriverInput
	if from_keys != null and to_keys != null:
		to_keys.left_level = from_keys.left_level
		to_keys.right_level = from_keys.right_level


func _point_everything_at(tank: Node3D, old_slit: Node) -> void:
	if is_instance_valid(chase_camera):
		chase_camera.target = tank
	if is_instance_valid(view_switcher):
		var new_slit := tank.get_node(SLIT_CAMERA_PATH) as Camera3D
		var slot: int = view_switcher.views.find(old_slit)
		if slot >= 0:
			(old_slit as DriverSlitCamera).set_view_active(false)
			view_switcher.views[slot] = new_slit
		view_switcher.show_view(view_switcher.current_index)
	if is_instance_valid(debug_hud):
		debug_hud.tank = tank
		debug_hud.station = tank.get(&"driver_station")
	if is_instance_valid(tuning_panel):
		tuning_panel.tank = tank
		tuning_panel.rebuild()


func _switch_off(tank: Node3D) -> void:
	tank.visible = false
	# Disabled nodes get no input or processing, and their bodies leave the
	# physics world (Godot's default disable mode), so nothing can bump them.
	tank.process_mode = Node.PROCESS_MODE_DISABLED


func _switch_on(tank: Node3D) -> void:
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	tank.visible = true
