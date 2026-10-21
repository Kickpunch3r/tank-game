class_name PushLightSender
extends Node
## Lights the Push 3's pads to match the levers and brake.
##
## Godot can't send MIDI, so the lights go through the browser relay page
## (web/push_relay.html, open it in Chrome or Edge): the game runs a small
## WebSocket server on this computer only, the page connects and passes the
## lights on to the Push. Same page and message as the finger-walking game:
## {"pads": [64 x [colour, 0, 0]]}, pad 36 (bottom-left) first.
##
## The lights show what the active tank is actually being told (its
## DriverStation), not just what was pressed on the Push, so the keyboard or
## the phone moving a lever shows on the Push too. Rebuilt from that state
## every frame and sent when something changes.
##
## Colours are Push palette numbers (0 = off). The relay page's palette view
## shows them all on the pads.

## Group the sender joins, so the HUD can find it.
const GROUP: StringName = &"push_light_sender"

## Tests use their own port (0 = use `port`).
static var port_override: int = 0

## The rig, to find the tank being driven.
@export var rig: PlayerRig

## Port the relay page connects to (the page's default is 9080).
@export var port: int = 9080

@export_group("Colours (Push palette numbers)")
## Every lever notch.
@export_range(0, 127) var notch_colour: int = 124
## The lever's middle notch (level 0), so you can find it.
@export_range(0, 127) var zero_notch_colour: int = 123
## Where the lever is, when going forward.
@export_range(0, 127) var forward_colour: int = 32
## Where the lever is, when going backwards.
@export_range(0, 127) var reverse_colour: int = 125
## Where the lever is, at level 0.
@export_range(0, 127) var stopped_colour: int = 122
## The brake square.
@export_range(0, 127) var brake_colour: int = 127
## The brake square while braking.
@export_range(0, 127) var brake_held_colour: int = 122

var _server := TCPServer.new()
var _peers: Array[WebSocketPeer] = []
# Pages that already have the current lights.
var _up_to_date: Dictionary = {}
var _last_pads: Array = []


func _ready() -> void:
	add_to_group(GROUP)
	if port_override != 0:
		port = port_override
	var error: Error = _server.listen(port, "127.0.0.1")
	if error != OK:
		push_warning("PushLightSender: can't open port %d for the Push relay page (%s)" % [port, error_string(error)])


func _exit_tree() -> void:
	for peer: WebSocketPeer in _peers:
		peer.close()
	_server.stop()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var peer := WebSocketPeer.new()
		if peer.accept_stream(_server.take_connection()) == OK:
			_peers.append(peer)
	var pads: Array = build_pads()
	var changed: bool = pads != _last_pads
	_last_pads = pads
	var message: String = JSON.stringify({"pads": pads})
	for i: int in range(_peers.size() - 1, -1, -1):
		var peer: WebSocketPeer = _peers[i]
		peer.poll()
		while peer.get_available_packet_count() > 0:
			peer.get_packet()  # The page's only message asks for MIDI clock; not used here.
		match peer.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if changed or not _up_to_date.get(peer, false):
					peer.send_text(message)
					_up_to_date[peer] = true
			WebSocketPeer.STATE_CLOSED:
				_up_to_date.erase(peer)
				_peers.remove_at(i)


## How many relay pages are connected.
func page_count() -> int:
	return _peers.size()


func is_listening() -> bool:
	return _server.is_listening()


## All 64 pads, pad 36 (bottom-left) first: [colour, 0, 0] each.
func build_pads() -> Array:
	var station: DriverStation = _station()
	var left: int = PushLayout.nearest_level(station.left_tread) if station != null else 0
	var right: int = PushLayout.nearest_level(station.right_tread) if station != null else 0
	var braking: bool = station != null and station.brake
	var pads: Array = []
	for row: int in PushLayout.ROWS:
		for column: int in PushLayout.COLUMNS:
			pads.append([_colour_for(column, row, left, right, braking), 0, 0])
	return pads


func _colour_for(column: int, row: int, left: int, right: int, braking: bool) -> int:
	var pad: Dictionary = PushLayout.describe_pad(column, row)
	match pad.kind:
		PushLayout.Kind.LEFT_LEVER:
			return _lever_colour(pad.level, left)
		PushLayout.Kind.RIGHT_LEVER:
			return _lever_colour(pad.level, right)
		PushLayout.Kind.BRAKE:
			return brake_held_colour if braking else brake_colour
	return 0


func _lever_colour(pad_level: int, lever_level: int) -> int:
	if pad_level == lever_level:
		if lever_level > 0:
			return forward_colour
		if lever_level < 0:
			return reverse_colour
		return stopped_colour
	return zero_notch_colour if pad_level == 0 else notch_colour


func _station() -> DriverStation:
	if rig == null or not is_instance_valid(rig.active_tank):
		return null
	return rig.active_tank.get(&"driver_station") as DriverStation
