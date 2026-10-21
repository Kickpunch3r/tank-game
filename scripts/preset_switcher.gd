class_name PresetSwitcher
extends Node
## Keys 1, 2 and 3 (Input Map: preset_1, preset_2, preset_3) switch the feel
## preset while driving. A preset sets only the six feel knobs (see TankFeel),
## on every tank in `tanks`, so swapping tanks keeps the same preset.
##
## Like the Tab panel, this changes the tuning in memory only, until you quit.
## "Reset to saved" in the Tab panel goes back to the saved tuning.

## The presets, in key order: the first is key 1.
@export var presets: Array[TankFeel] = []

## The tanks whose knobs a preset sets.
@export var tanks: Array[Node] = []

## The Tab panel, rebuilt after a switch so it shows the new values.
@export var tuning_panel: TuningPanel

const ACTIONS: Array[StringName] = [&"preset_1", &"preset_2", &"preset_3"]


func _unhandled_input(event: InputEvent) -> void:
	for index: int in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[index]) and index < presets.size():
			apply_preset(index)
			get_viewport().set_input_as_handled()
			return


## Put preset number `index` (0 = key 1) on every tank.
func apply_preset(index: int) -> void:
	var preset: TankFeel = presets[index]
	for tank: Node in tanks:
		if is_instance_valid(tank):
			preset.apply_to(tank.get(&"tuning"))
	if is_instance_valid(tuning_panel):
		tuning_panel.rebuild()


## The name of the preset these knob values match, or "" if none does (e.g.
## the saved tuning, or a knob changed in the Tab panel after a switch).
## Worked out from the values every time, so it can never be out of date.
func preset_name_for(tuning: Resource) -> String:
	for preset: TankFeel in presets:
		if preset.matches(tuning):
			return preset.display_name
	return ""
