class_name PushTests
extends RefCounted
## Checks the Ableton Push 3 controller without a Push: pretend MIDI pad
## presses go into the course's PushController, and the lights are checked
## as built and as received by a pretend relay page.
## (The test runner stops the controller opening real MIDI.)

const NETWORK_TIMEOUT_MS: int = 3000

var runner: TestRunner
var report: TestReport
var push: PushController
var lights: PushLightSender
var rig: PlayerRig
var station: DriverStation


func _init(test_runner: TestRunner) -> void:
	runner = test_runner
	report = runner.report


func run() -> void:
	report.heading("Ableton Push 3 (pretend MIDI)")
	rig = runner.course.get_node(^"PlayerRig")
	push = rig.get_node(^"PushController")
	lights = rig.get_node(^"PushLightSender")
	station = rig.active_tank.get(&"driver_station")
	var keyboard: KeyboardDriverInput = station.get_node(^"KeyboardDriverInput")
	keyboard.clear_levels()
	station.listen_to_input_sources = true
	push.midi_device = 0  # as if the Push were found as the first MIDI port
	# The phone tests end by disconnecting, which brakes for 3 s: wait for that.
	var waited: int = 0
	while station.brake and waited < 300:
		await runner.get_tree().physics_frame
		waited += 1

	report.check("Layout: left lever bottom pad = full back, top = full forward",
			_kind_level(PushLayout.note_for(0, 0)) == [PushLayout.Kind.LEFT_LEVER, -3]
			and _kind_level(PushLayout.note_for(1, 6)) == [PushLayout.Kind.LEFT_LEVER, 3])
	report.check("Layout: right lever middle pad = 0, brake square in the middle, top row free",
			_kind_level(PushLayout.note_for(7, 3)) == [PushLayout.Kind.RIGHT_LEVER, 0]
			and _kind_level(PushLayout.note_for(3, 4))[0] == PushLayout.Kind.BRAKE
			and _kind_level(PushLayout.note_for(4, 7))[0] == PushLayout.Kind.NONE)

	# Levers.
	await _tap(PushLayout.note_for(0, 6))
	await _tap(PushLayout.note_for(7, 1))
	report.check("Pressing pads sets the levers (left +3 = 1, right -2 = -0.5) and they stay",
			is_equal_approx(station.left_tread, 1.0) and is_equal_approx(station.right_tread, -0.5),
			"station L %.2f R %.2f" % [station.left_tread, station.right_tread])
	await _tap(PushLayout.note_for(1, 4), 1)
	report.check("Presses from the Push's duplicate MIDI port are ignored", push.left_level == 3)

	var pads: Array = lights.build_pads()
	report.check("Lights: the lever's position is bright, the other notches dim",
			_colour(pads, 0, 6) == lights.forward_colour and _colour(pads, 1, 6) == lights.forward_colour
			and _colour(pads, 0, 5) == lights.notch_colour and _colour(pads, 0, 3) == lights.zero_notch_colour)
	report.check("Lights: reverse position in the reverse colour, brake square red, top row dark",
			_colour(pads, 7, 1) == lights.reverse_colour and _colour(pads, 3, 3) == lights.brake_colour
			and _colour(pads, 4, 7) == 0 and _colour(pads, 2, 0) == 0)

	# Brake.
	await _press(PushLayout.note_for(2, 2), true)
	report.check("Holding a brake pad brakes and puts both levers to 0",
			station.brake and push.left_level == 0 and push.right_level == 0)
	report.check("Lights: brake square shows it's held", _colour(lights.build_pads(), 5, 5) == lights.brake_held_colour)
	await _press(PushLayout.note_for(2, 2), false)
	report.check("Letting go of the brake pad releases the brake", not station.brake)

	# The lights show what the tank is told, from any controller.
	for i: int in 2:
		await _key(KEY_W)
	report.check("Lights follow the keyboard too (W x2 -> left lever lit at +2)",
			_colour(lights.build_pads(), 0, 5) == lights.forward_colour and _colour(lights.build_pads(), 0, 3) == lights.zero_notch_colour)
	keyboard.clear_levels()

	# The relay page receives the lights.
	var received: Array = await _pads_from_relay_page()
	report.check("A relay page connecting gets all 64 pad lights", received.size() == 64 and received == lights.build_pads(),
			"%d pads received" % received.size())

	# Unplugged.
	await _tap(PushLayout.note_for(0, 6))
	push.push_lost()
	await runner.wait_physics_frames(2)
	report.check("Push unplugged: levers back to 0 and the brake held", push.left_level == 0 and station.brake)
	var frames: int = 0
	while station.brake and frames < 400:
		await runner.get_tree().physics_frame
		frames += 1
	report.check("...for about 3 s", absf(frames / 60.0 - PushController.LOSS_BRAKE_SECONDS) < 0.1,
			"braked for %.2f s" % (frames / 60.0))
	push.midi_device = 0

	# Both tanks.
	rig.swap_tank()
	await runner.wait_physics_frames(2)
	await _tap(PushLayout.note_for(0, 5))
	var other_station: DriverStation = rig.active_tank.get(&"driver_station")
	report.check("After T, the Push drives the other tank too (and its lights follow it)",
			is_equal_approx(other_station.left_tread, 0.5) and _colour(lights.build_pads(), 0, 5) == lights.forward_colour,
			"%s station L %.2f" % [rig.active_tank.name, other_station.left_tread])
	await _press(PushLayout.note_for(3, 3), true)
	await _press(PushLayout.note_for(3, 3), false)
	rig.swap_tank()
	await runner.wait_physics_frames(5)
	push.midi_device = -1


func _kind_level(note: int) -> Array:
	var pad: Dictionary = PushLayout.describe(note)
	return [pad.kind, pad.level]


func _colour(pads: Array, column: int, row: int) -> int:
	return pads[row * PushLayout.COLUMNS + column][0]


func _press(note: int, down: bool, device: int = 0) -> void:
	var event := InputEventMIDI.new()
	event.device = device
	event.message = MIDI_MESSAGE_NOTE_ON if down else MIDI_MESSAGE_NOTE_OFF
	event.pitch = note
	event.velocity = 100 if down else 0
	push.handle_midi(event)
	await runner.wait_physics_frames(2)


func _tap(note: int, device: int = 0) -> void:
	await _press(note, true, device)
	await _press(note, false, device)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await runner.wait_physics_frames(2)


## Connect like the relay page and return the first pad lights it receives.
func _pads_from_relay_page() -> Array:
	var peer := WebSocketPeer.new()
	peer.connect_to_url("ws://127.0.0.1:%d" % PushLightSender.port_override)
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < NETWORK_TIMEOUT_MS:
		peer.poll()
		if peer.get_available_packet_count() > 0:
			var json := JSON.new()
			if json.parse(peer.get_packet().get_string_from_utf8()) == OK and json.data is Dictionary:
				peer.close()
				var pads: Variant = json.data.get("pads")
				return _as_ints(pads) if pads is Array else []
		await runner.get_tree().process_frame
	peer.close()
	return []


## JSON numbers come back as floats: turn the pad lists back into whole numbers.
func _as_ints(pads: Array) -> Array:
	var result: Array = []
	for pad: Variant in pads:
		var values: Array = []
		for value: Variant in pad:
			values.append(int(value))
		result.append(values)
	return result
