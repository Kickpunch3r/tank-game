class_name PushController
extends Node
## Reads the Ableton Push 3's pads (over USB MIDI; no Ableton Live or drivers
## needed) and keeps the Push's lever levels and brake. Lives in the player
## rig; each tank's PushDriverInput reads it, so swapping tanks keeps the
## Push's levers where they are. See PushLayout for which pad does what.
##
## Pressing a lever pad jumps that lever to the pad's level; it stays when
## you let go. Holding any pad of the brake square brakes, and pressing it
## also puts both levers back to 0.
##
## Safety: if the Push disappears (unplugged), its levers go back to 0 and the
## brake is held for a few seconds, so the tank stops instead of driving on.

## Group the controller joins, so the Push inputs, lights and HUD can find it.
const GROUP: StringName = &"push_controller"

## How long the brake is held after the Push disappears, in seconds.
const LOSS_BRAKE_SECONDS: float = 3.0

## Test runs switch this off: they feed pretend MIDI in instead.
static var open_midi_in_scenes: bool = true

## Name of the MIDI port to read. The Push shows up as three ports and every
## pad press arrives on two of them, so only this one is read.
@export var midi_port_name: String = "Ableton Push 3 MIDI"

## How often to check that the Push is still plugged in, in seconds.
@export var check_every_seconds: float = 1.0

## The Push's lever levels, from -3 to 3.
var left_level: int = 0
var right_level: int = 0

## Which MIDI port is the Push (its place in Godot's list), -1 = not found.
var midi_device: int = -1

# Brake pads being held: note -> true.
var _brake_pads: Dictionary = {}
var _time: float = 0.0
var _seconds_since_check: float = 0.0
var _loss_brake_until: float = -INF


func _ready() -> void:
	add_to_group(GROUP)
	if open_midi_in_scenes:
		OS.open_midi_inputs()
		_check_for_push()


func _exit_tree() -> void:
	if open_midi_in_scenes:
		OS.close_midi_inputs()


func _process(delta: float) -> void:
	_time += delta
	if not open_midi_in_scenes:
		return
	_seconds_since_check += delta
	if _seconds_since_check >= check_every_seconds:
		_seconds_since_check = 0.0
		_check_for_push()


func _input(event: InputEvent) -> void:
	var midi := event as InputEventMIDI
	if midi != null:
		handle_midi(midi)


## One MIDI message from a port. Only the Push's own port counts.
func handle_midi(midi: InputEventMIDI) -> void:
	if midi.device != midi_device or midi_device == -1:
		return
	var pressed: bool = midi.message == MIDI_MESSAGE_NOTE_ON and midi.velocity > 0
	var released: bool = midi.message == MIDI_MESSAGE_NOTE_OFF \
			or (midi.message == MIDI_MESSAGE_NOTE_ON and midi.velocity == 0)
	if not pressed and not released:
		return
	var pad: Dictionary = PushLayout.describe(midi.pitch)
	match pad.kind:
		PushLayout.Kind.LEFT_LEVER:
			if pressed:
				left_level = pad.level
		PushLayout.Kind.RIGHT_LEVER:
			if pressed:
				right_level = pad.level
		PushLayout.Kind.BRAKE:
			if pressed:
				_brake_pads[midi.pitch] = true
				left_level = 0
				right_level = 0
			else:
				_brake_pads.erase(midi.pitch)


func is_connected_to_push() -> bool:
	return midi_device != -1


func left_tread() -> float:
	return TreadLevels.value_for(left_level)


func right_tread() -> float:
	return TreadLevels.value_for(right_level)


## True while a brake pad is held, or for a few seconds after the Push disappeared.
func is_brake_held() -> bool:
	return not _brake_pads.is_empty() or _time < _loss_brake_until


## Called when the Push stops being there: levers to 0, brake for a while.
func push_lost() -> void:
	left_level = 0
	right_level = 0
	_brake_pads.clear()
	_loss_brake_until = _time + LOSS_BRAKE_SECONDS
	midi_device = -1


func _check_for_push() -> void:
	# The port's place in this list is what InputEventMIDI.device reports.
	var found: int = OS.get_connected_midi_inputs().find(midi_port_name)
	if midi_device != -1 and found == -1:
		push_lost()
	midi_device = found
