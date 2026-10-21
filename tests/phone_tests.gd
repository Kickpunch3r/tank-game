class_name PhoneTests
extends RefCounted
## Checks the phone controller without a phone: Godot itself plays the phone,
## connecting to the course's ControllerServer as a web browser would.
## (The test runner makes the server listen on this computer only.)

## Longest to wait for the network, in real milliseconds.
const NETWORK_TIMEOUT_MS: int = 3000

var runner: TestRunner
var report: TestReport
var server: ControllerServer
var station: DriverStation
var keyboard: KeyboardDriverInput


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Phone controller")
	server = runner.course.get_node(^"PlayerRig/ControllerServer")
	var tank: Tank = runner.course.get_node(^"PlayerRig/Tank")
	station = tank.driver_station
	keyboard = station.get_node(^"KeyboardDriverInput")
	keyboard.clear_levels()
	station.listen_to_input_sources = true

	report.check("Servers are listening", server.is_listening(), server.problem())
	if not server.is_listening():
		return

	var page: String = await _http_get("/")
	report.check("Web page: GET / returns the controller page (200)",
			page.begins_with("HTTP/1.1 200") and page.contains("<html"), page.get_slice("\r\n", 0))
	report.check("Page gets the same lever levels as the keyboard (filled in by the game)",
			page.contains("const LEVELS_TEXT = \"[0.25,0.5,1.0]\"") and not page.contains("{{TREAD_LEVELS}}"))
	var missing: String = await _http_get("/nothing-here")
	report.check("Web page: anything else returns 404", missing.begins_with("HTTP/1.1 404"), missing.get_slice("\r\n", 0))

	# The first phone becomes the driver.
	var driver: WebSocketPeer = await _connect()
	report.check("A phone can connect", driver.get_ready_state() == WebSocketPeer.STATE_OPEN)
	_send(driver, {"t": "hello", "role": "driver"})
	var welcome: Dictionary = await _receive(driver)
	report.check("First phone is welcomed as the driver", welcome.get("role") == "driver", str(welcome))

	await _send_for(driver, 0.53, -1.0, 10)
	report.check("Driver phone's values reach the DriverStation",
			is_equal_approx(station.left_tread, 0.53) and is_equal_approx(station.right_tread, -1.0),
			"station L %.2f R %.2f" % [station.left_tread, station.right_tread])

	# Phone wins over the keyboard while it is live.
	for i: int in 3:
		await _tap_key(KEY_W)
	await _send_for(driver, 0.2, 0.2, 10)
	report.check("While the phone is driving, it wins over the keyboard",
			is_equal_approx(station.left_tread, 0.2), "keyboard level %d, station L %.2f" % [keyboard.left_level, station.left_tread])
	keyboard.clear_levels()

	# Watchdog: the phone goes quiet.
	await _send_for(driver, 0.8, 0.8, 5)
	var quiet_frames: int = 0
	while server.is_driver_live() and quiet_frames < 120:
		await runner.get_tree().physics_frame
		quiet_frames += 1
	await runner.wait_physics_frames(2)
	report.check("Watchdog: phone goes quiet -> treads back to 0 within ~0.3 s",
			quiet_frames <= 18 and station.left_tread == 0.0 and station.right_tread == 0.0,
			"stopped counting as live after %.2f s; station L %.2f" % [quiet_frames / 60.0, station.left_tread])
	report.check("Watchdog also brakes, so the tank stops instead of coasting on", station.brake)
	var braking_frames: int = 0
	while station.brake and braking_frames < 600:
		await runner.get_tree().physics_frame
		braking_frames += 1
	report.check("...for about 3 s, then lets go", absf(braking_frames / 60.0 - ControllerServer.LOSS_BRAKE_SECONDS) < 0.1,
			"braked for %.2f s" % (braking_frames / 60.0))
	for i: int in 3:
		await _tap_key(KEY_W)
	report.check("After the watchdog, the keyboard drives again", is_equal_approx(station.left_tread, 1.0) and not station.brake)
	keyboard.clear_levels()

	# The phone's brake button.
	for i: int in 10:
		driver.poll()
		_send(driver, {"t": "in", "l": 0, "r": 0, "b": 1})
		await runner.get_tree().physics_frame
	await runner.wait_physics_frames(2)
	report.check("Phone brake button brakes the tank", station.brake)
	await _send_for(driver, 0.5, 0.5, 10)
	report.check("Releasing the phone brake lets the tank drive", not station.brake and is_equal_approx(station.left_tread, 0.5))

	# A second phone is a spectator and its input is ignored.
	var second: WebSocketPeer = await _connect()
	_send(second, {"t": "hello", "role": "driver"})
	var second_welcome: Dictionary = await _receive(second)
	report.check("Second phone is welcomed as a spectator", second_welcome.get("role") == "spectator", str(second_welcome))
	await _send_for(second, 1.0, 1.0, 10)
	report.check("Spectator's input is ignored", station.left_tread == 0.0 and not server.is_driver_live())

	# Bad messages: nothing crashes, nothing moves.
	for junk: String in ["garbage", "{", "[1,2,3]", "{\"t\":\"in\"}", "{\"t\":\"in\",\"l\":\"abc\",\"r\":0.5}",
			"{\"t\":\"in\",\"l\":null,\"r\":1}", "{\"t\":42}", ""]:
		driver.send_text(junk)
	await _wait_frames_polling([driver, second], 10)
	report.check("Malformed messages are ignored (no crash, no movement)",
			station.left_tread == 0.0 and station.right_tread == 0.0 and server.phone_count() == 2)
	await _send_for(driver, 5.0, -9.0, 10)
	report.check("Out-of-range values are clamped to -1..1",
			is_equal_approx(station.left_tread, 1.0) and is_equal_approx(station.right_tread, -1.0),
			"station L %.2f R %.2f" % [station.left_tread, station.right_tread])

	# Buzz reaches the driver.
	server.buzz(40)
	var buzz: Dictionary = await _receive(driver)
	report.check("Buzz messages reach the driver phone", buzz.get("t") == "buzz" and buzz.get("ms") == 40.0, str(buzz))

	# Driver leaves: the spectator becomes the driver.
	driver.close()
	var promoted: Dictionary = await _receive(second)
	report.check("When the driver leaves, the waiting phone becomes the driver",
			promoted.get("role") == "driver" and server.driver_id() != 0, str(promoted))
	second.close()
	await _wait_frames_polling([second], 20)
	report.check("When every phone leaves, nobody is the driver", server.driver_id() == 0 and server.phone_count() == 0,
			"%d phones" % server.phone_count())
	station.listen_to_input_sources = true


# --- Playing the phone -----------------------------------------------------

func _http_get(path: String) -> String:
	var peer := StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", server.http_port)
	var started: int = Time.get_ticks_msec()
	var sent: bool = false
	var received := PackedByteArray()
	while Time.get_ticks_msec() - started < NETWORK_TIMEOUT_MS:
		peer.poll()
		var status: StreamPeerTCP.Status = peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			if not sent:
				peer.put_data(("GET %s HTTP/1.1\r\nHost: localhost\r\n\r\n" % path).to_utf8_buffer())
				sent = true
			var available: int = peer.get_available_bytes()
			if available > 0:
				received += peer.get_data(available)[1]
		elif sent and status != StreamPeerTCP.STATUS_CONNECTING:
			break
		await runner.get_tree().process_frame
	peer.disconnect_from_host()
	return received.get_string_from_utf8()


func _connect() -> WebSocketPeer:
	var peer := WebSocketPeer.new()
	peer.connect_to_url("ws://127.0.0.1:%d" % server.websocket_port)
	var started: int = Time.get_ticks_msec()
	while peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - started < NETWORK_TIMEOUT_MS:
		peer.poll()
		await runner.get_tree().process_frame
	return peer


func _send(peer: WebSocketPeer, message: Dictionary) -> void:
	peer.send_text(JSON.stringify(message))


## Send tread values every frame for `frames` physics frames, as the page does.
func _send_for(peer: WebSocketPeer, left: float, right: float, frames: int) -> void:
	for i: int in frames:
		peer.poll()
		_send(peer, {"t": "in", "l": left, "r": right})
		await runner.get_tree().physics_frame
	await runner.wait_physics_frames(2)


## Wait for the next message on `peer`, as a dictionary ({} if none arrives).
func _receive(peer: WebSocketPeer) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < NETWORK_TIMEOUT_MS:
		peer.poll()
		if peer.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			return message if message is Dictionary else {}
		await runner.get_tree().process_frame
	return {}


func _wait_frames_polling(peers: Array[WebSocketPeer], frames: int) -> void:
	for i: int in frames:
		for peer: WebSocketPeer in peers:
			peer.poll()
		await runner.get_tree().physics_frame


func _tap_key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await runner.wait_physics_frames(2)
