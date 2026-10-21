class_name ControllerServer
extends Node
## Lets phones drive the tank. The game hosts everything itself:
## - a tiny web server (port 8080) that gives a phone's browser the controller
##   page (web/controller.html), and
## - a WebSocket server (port 8081) the page connects to, to send tread values.
## Phone and computer must be on the same local network.
##
## Messages are small JSON texts:
##   phone -> game: {"t":"hello","role":"driver"}  then  {"t":"in","l":0.5,"r":-1.0,"b":0}
##                  ("b" = brake button held: 1 or 0; optional)
##   game -> phone: {"t":"welcome","role":"driver" or "spectator"},  {"t":"buzz","ms":40}
## The first phone to say hello as driver becomes the driver; later phones are
## spectators and their input is ignored, until the driver leaves.
## Bad or unexpected messages are ignored. Tread values are clamped to -1..1.

## Group the server joins, so PhoneDriverInput and the HUD can find it.
const GROUP: StringName = &"controller_server"

## Tests set this (e.g. "127.0.0.1") so test runs only listen on this computer
## and don't trigger a Windows Firewall question. Empty = use bind_address.
static var bind_address_override: String = ""
## Tests also use their own ports (0 = use the exported ports), so a running
## game or an open controller page can't interfere with a test run.
static var http_port_override: int = 0
static var websocket_port_override: int = 0

## Port for the controller web page.
@export var http_port: int = 8080
## Port the page's WebSocket connects to.
@export var websocket_port: int = 8081
## Off: listen on this computer only. Phones then connect through a USB cable
## (see UsbPhoneLink), and Windows doesn't ask for network access, which
## needs admin rights on some computers.
## On: listen on the network too, so phones on the same Wi-Fi can connect
## (Windows Firewall must allow Godot).
@export var allow_wifi_phones: bool = false
## The controller page served to phones.
@export_file("*.html") var page_path: String = "res://web/controller.html"
## If the driver phone sends nothing for this long (seconds), its input counts
## as gone and the treads go back to 0. A dropped Wi-Fi connection must never
## leave the tank driving away.
@export var watchdog_seconds: float = 0.25
## The tank whose bumps make the driver's phone buzz (optional).
@export var tank: Tank

## When the driver phone goes quiet or disconnects while driving, the brake
## is held for this long (seconds), so the tank stops instead of coasting on.
## After that the keyboard can drive again.
const LOSS_BRAKE_SECONDS: float = 3.0

## Latest values from the driver phone (only meaningful while is_driver_live()).
var latest_left: float = 0.0
var latest_right: float = 0.0
var latest_brake: bool = false

var _http := ControllerHttpServer.new()
var _websocket_server := TCPServer.new()
var _registry := StationRegistry.new()
# Connection id -> {"peer": WebSocketPeer, "age": float}
var _phones: Dictionary = {}
var _next_id: int = 1
# Game time in seconds (from frame deltas), used for the watchdog.
var _time: float = 0.0
var _last_driver_message_time: float = -INF
var _http_error: Error = OK
var _websocket_error: Error = OK
var _was_driver_live: bool = false
var _loss_brake_until: float = -INF


func _ready() -> void:
	add_to_group(GROUP)
	var address: String = "*" if allow_wifi_phones else "127.0.0.1"
	if not bind_address_override.is_empty():
		address = bind_address_override
	if http_port_override != 0:
		http_port = http_port_override
	if websocket_port_override != 0:
		websocket_port = websocket_port_override
	_http.page_path = page_path
	_http.websocket_port = websocket_port
	_http.tread_levels = TreadLevels.VALUES
	_http_error = _http.start(http_port, address)
	_websocket_error = _websocket_server.listen(websocket_port, address)
	if _http_error != OK or _websocket_error != OK:
		push_warning("ControllerServer: could not open ports %d / %d (%s / %s). Is another copy of the game running?" % [
				http_port, websocket_port, error_string(_http_error), error_string(_websocket_error)])
	if tank != null:
		tank.bumped.connect(func() -> void: buzz(40))


func _exit_tree() -> void:
	for id: int in _phones.keys():
		(_phones[id].peer as WebSocketPeer).close()
	_phones.clear()
	_http.stop()
	_websocket_server.stop()


func _process(delta: float) -> void:
	_time += delta
	_http.poll(delta)
	while _websocket_server.is_connection_available():
		var peer := WebSocketPeer.new()
		if peer.accept_stream(_websocket_server.take_connection()) == OK:
			_phones[_next_id] = {"peer": peer, "age": 0.0}
			_next_id += 1
	for id: int in _phones.keys():
		_poll_phone(id, delta)
	# The driver phone just stopped being live (quiet or gone): brake for a while.
	var live: bool = is_driver_live()
	if _was_driver_live and not live:
		_loss_brake_until = _time + LOSS_BRAKE_SECONDS
	_was_driver_live = live


# --- What the rest of the game asks ---------------------------------------

## True while a driver phone is connected and has sent input recently.
func is_driver_live() -> bool:
	return _registry.holder_of("driver") != 0 and _time - _last_driver_message_time <= watchdog_seconds


## The driver phone's left tread value, or 0 when it isn't live (watchdog).
func driver_left() -> float:
	return latest_left if is_driver_live() else 0.0


func driver_right() -> float:
	return latest_right if is_driver_live() else 0.0


## True while the driver phone holds its brake button, and for a few seconds
## after the driver phone goes quiet or disconnects (so the tank stops).
func driver_brake() -> bool:
	if is_driver_live():
		return latest_brake
	return _time < _loss_brake_until


func is_listening() -> bool:
	return _http.is_listening() and _websocket_server.is_listening()


func phone_count() -> int:
	return _phones.size()


## Connection id of the driver phone (0 = none).
func driver_id() -> int:
	return _registry.holder_of("driver")


func seconds_since_driver_message() -> float:
	return _time - _last_driver_message_time


## The address a phone connected by USB cable opens.
func usb_url() -> String:
	return "http://localhost:%d" % http_port


## Web addresses to type into a phone, one per network this computer is on.
## Empty when Wi-Fi phones are switched off.
func controller_urls() -> PackedStringArray:
	var urls := PackedStringArray()
	if not allow_wifi_phones:
		return urls
	for address: String in IP.get_local_addresses():
		# IPv4 only; skip "this computer only" and "no network found" addresses.
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		urls.append("http://%s:%d" % [address, http_port])
	return urls


## Why the servers aren't running, or "" if they are.
func problem() -> String:
	if _http_error != OK:
		return "port %d unavailable (%s)" % [http_port, error_string(_http_error)]
	if _websocket_error != OK:
		return "port %d unavailable (%s)" % [websocket_port, error_string(_websocket_error)]
	return ""


## Short vibration on the driver's phone (Android only; iPhones ignore it).
func buzz(milliseconds: int) -> void:
	var id: int = driver_id()
	if id != 0:
		_send(id, {"t": "buzz", "ms": milliseconds})


# --- Talking to phones ---------------------------------------------------

func _poll_phone(id: int, delta: float) -> void:
	var phone: Dictionary = _phones[id]
	var peer: WebSocketPeer = phone.peer
	peer.poll()
	phone.age += delta
	match peer.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				_handle_message(id, peer.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CONNECTING:
			if phone.age > 5.0:
				peer.close()
				_forget_phone(id)
		WebSocketPeer.STATE_CLOSED:
			_forget_phone(id)


func _handle_message(id: int, text: String) -> void:
	# JSON.new().parse() reports bad text quietly (JSON.parse_string would log
	# an error for every bad message, which a faulty phone could flood).
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return
	var message: Dictionary = json.data
	match message.get("t"):
		"hello":
			if _registry.station_of(id) != StationRegistry.SPECTATOR:
				# Already holds a station: just confirm it.
				_send(id, {"t": "welcome", "role": _registry.station_of(id)})
				return
			var wanted: String = str(message.get("role", "driver"))
			_send(id, {"t": "welcome", "role": _registry.join(id, wanted)})
		"in":
			if _registry.station_of(id) != "driver":
				return
			var left: Variant = message.get("l")
			var right: Variant = message.get("r")
			if not _is_number(left) or not _is_number(right):
				return
			latest_left = clampf(float(left), -1.0, 1.0)
			latest_right = clampf(float(right), -1.0, 1.0)
			# Brake is optional: "b": 1 (or true) while the brake button is held.
			var brake: Variant = message.get("b", 0)
			latest_brake = (brake is bool and brake) or (_is_number(brake) and float(brake) != 0.0)
			_last_driver_message_time = _time


func _forget_phone(id: int) -> void:
	_phones.erase(id)
	var was_driver: bool = _registry.station_of(id) == "driver"
	var promoted: Dictionary = _registry.leave(id)
	if was_driver:
		latest_left = 0.0
		latest_right = 0.0
		latest_brake = false
		_last_driver_message_time = -INF
	if not promoted.is_empty():
		_send(promoted.new_holder, {"t": "welcome", "role": promoted.station})


func _send(id: int, message: Dictionary) -> void:
	if not _phones.has(id):
		return
	var peer: WebSocketPeer = _phones[id].peer
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peer.send_text(JSON.stringify(message))


func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
