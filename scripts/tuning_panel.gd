class_name TuningPanel
extends CanvasLayer
## In-game panel for changing driving, camera and slit settings while you play.
## Tab (Input Map: tuning_panel_toggle) shows and hides it.
##
## Changes only last until you stop the game. "Copy values" puts the current
## numbers on the clipboard (and in the Output panel) so they can be made
## permanent in the Inspector. "Reset to saved" puts everything back.
##
## The panel also chooses where R puts the tank: in front of a chosen ramp, a
## chosen distance back from it.

## The tank whose tuning and slit camera are being changed.
@export var tank: Tank

## The chase camera whose follow settings are being changed.
@export var chase_camera: ChaseCamera

## The rows of ramps, for choosing where reset puts the tank.
@export var slope_ladders: Array[SlopeLadder] = []

## Distance back from the chosen ramp when the panel starts, in metres.
@export var start_distance: float = 0.0

# One entry per setting: which object, which property, slider range, and the
# value it had when the game started (for "Reset to saved").
var _settings: Array[Dictionary] = []
var _sliders: Array[HSlider] = []
var _value_labels: Array[Label] = []

var _ramp_choice: OptionButton
# One entry per dropdown item after "Start field": {"ladder": SlopeLadder, "index": int}.
var _reset_choices: Array[Dictionary] = []
var _distance_slider: HSlider
var _distance_label: Label
var _copy_button: Button
var _start_field_spawn: Transform3D


func _ready() -> void:
	layer = 20
	visible = false
	_start_field_spawn = tank.get_spawn()
	_define_settings()
	_build_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tuning_panel_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()


# --- What can be changed ---------------------------------------------------

func _define_settings() -> void:
	var tuning: TankTuning = tank.tuning
	var slit: DriverSlitCamera = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	_add_setting("Speed", tuning, &"max_tread_speed", 2.0, 25.0, 0.5)
	_add_setting("Speed", tuning, &"max_drive_accel", 0.5, 15.0, 0.1)
	_add_setting("Speed", tuning, &"rolling_resistance", 0.0, 2.0, 0.05)
	_add_setting("Engine power", tuning, &"power_falloff_start", 0.0, 1.0, 0.05)
	_add_setting("Engine power", tuning, &"power_at_top_speed", 0.0, 1.0, 0.05)
	_add_setting("Grip and gravity", tuning, &"traction_coeff", 0.05, 1.5, 0.01)
	_add_setting("Grip and gravity", tuning, &"g", 1.0, 30.0, 0.1)
	_add_setting("Turning", tuning, &"track_width", 1.0, 8.0, 0.1)
	_add_setting("Turning", tuning, &"turn_resistance", 0.0, 0.95, 0.01)
	_add_setting("Air and landing", tuning, &"air_gravity_scale", 0.1, 3.0, 0.05)
	_add_setting("Air and landing", tuning, &"nose_dip", 0.0, 1.0, 0.05)
	_add_setting("Air and landing", tuning, &"landing_speed_loss", 0.0, 1.0, 0.05)
	_add_setting("Air and landing", tuning, &"tilt_smoothing", 0.5, 30.0, 0.5)
	_add_setting("Chase camera", chase_camera, &"follow_distance", 3.0, 40.0, 0.5)
	_add_setting("Chase camera", chase_camera, &"follow_height", 0.5, 20.0, 0.5)
	_add_setting("Chase camera", chase_camera, &"look_height", 0.0, 5.0, 0.1)
	_add_setting("Chase camera", chase_camera, &"follow_smoothing", 0.5, 20.0, 0.5)
	_add_setting("Driver slit", slit, &"slit_height", 0.05, 0.6, 0.01)
	for terrain: TerrainType in _terrain_types_in_scene():
		var group: String = "Terrain: %s" % terrain.display_name
		_add_setting(group, terrain, &"grip", 0.0, 2.0, 0.05)
		_add_setting(group, terrain, &"drag", 0.0, 10.0, 0.1)
		_add_setting(group, terrain, &"top_speed", 0.1, 1.5, 0.05)
		_add_setting(group, terrain, &"sink_depth", 0.0, 1.0, 0.05)


## Every different terrain used by a patch in the scene, in the order found.
func _terrain_types_in_scene() -> Array[TerrainType]:
	var found: Array[TerrainType] = []
	for node: Node in get_tree().get_nodes_in_group(TerrainPatch.GROUP):
		var patch := node as TerrainPatch
		if patch != null and patch.terrain != null and not found.has(patch.terrain):
			found.append(patch.terrain)
	return found


func _add_setting(group: String, target: Object, property: StringName,
		min_value: float, max_value: float, step: float) -> void:
	_settings.append({
		"group": group,
		"target": target,
		"property": property,
		"min": min_value,
		"max": max_value,
		"step": step,
		"saved": target.get(property),
	})


# --- Building the panel ----------------------------------------------------

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -430.0
	panel.offset_right = -10.0
	panel.offset_top = 10.0
	panel.offset_bottom = -10.0
	# A nearly solid background, so ramp labels behind it don't make it hard to read.
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	background.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override(&"panel", background)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_heading("TUNING  (Tab to close)  -  changes last until you quit"))
	var buttons := HBoxContainer.new()
	_copy_button = _button("Copy values", _on_copy_pressed)
	buttons.add_child(_copy_button)
	buttons.add_child(_button("Reset to saved", _on_reset_to_saved_pressed))
	list.add_child(buttons)

	_build_reset_point(list)

	var current_group: String = ""
	for index: int in _settings.size():
		var setting: Dictionary = _settings[index]
		if setting.group != current_group:
			current_group = setting.group
			list.add_child(_heading(current_group))
		list.add_child(_setting_row(index))


func _build_reset_point(list: VBoxContainer) -> void:
	list.add_child(_heading("Reset point (where R puts you)"))
	_ramp_choice = OptionButton.new()
	_ramp_choice.focus_mode = Control.FOCUS_NONE
	_ramp_choice.add_item("Start field")
	var longest_run_up: float = 0.0
	for ladder: SlopeLadder in slope_ladders:
		longest_run_up = maxf(longest_run_up, ladder.run_up_length)
		for index: int in ladder.ramps.size():
			var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
			var text: String = "%d° %s" % [roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge"]
			if ramp.terrain != null:
				text += ", " + ramp.terrain.display_name.to_lower()
			_ramp_choice.add_item(text)
			_reset_choices.append({"ladder": ladder, "index": index})
	_ramp_choice.item_selected.connect(func(_index: int) -> void: _apply_reset_point())
	list.add_child(_ramp_choice)

	var row := HBoxContainer.new()
	row.add_child(_name_label("Distance back (m)"))
	_distance_slider = _slider(0.0, longest_run_up, 1.0, start_distance)
	_distance_slider.value_changed.connect(func(_value: float) -> void: _apply_reset_point())
	row.add_child(_distance_slider)
	_distance_label = _number_label()
	row.add_child(_distance_label)
	list.add_child(row)
	list.add_child(_button("Reset now", _on_reset_now_pressed))
	_apply_reset_point()


func _setting_row(index: int) -> HBoxContainer:
	var setting: Dictionary = _settings[index]
	var row := HBoxContainer.new()
	row.add_child(_name_label(String(setting.property).capitalize()))
	var slider: HSlider = _slider(setting.min, setting.max, setting.step, setting.target.get(setting.property))
	slider.value_changed.connect(func(value: float) -> void: _on_setting_changed(index, value))
	row.add_child(slider)
	var value_label: Label = _number_label()
	value_label.text = _format(setting.target.get(setting.property), setting.step)
	row.add_child(value_label)
	_sliders.append(slider)
	_value_labels.append(value_label)
	return row


# --- Reacting to the controls ----------------------------------------------

func _on_setting_changed(index: int, value: float) -> void:
	var setting: Dictionary = _settings[index]
	var target: Object = setting.target
	target.set(setting.property, value)
	_value_labels[index].text = _format(value, setting.step)
	if target.has_method(&"on_setting_changed"):
		target.call(&"on_setting_changed")


func _on_reset_to_saved_pressed() -> void:
	for index: int in _settings.size():
		var setting: Dictionary = _settings[index]
		_sliders[index].set_value_no_signal(setting.saved)
		_on_setting_changed(index, setting.saved)


func _on_copy_pressed() -> void:
	var text: String = values_text()
	DisplayServer.clipboard_set(text)
	print(text)
	_copy_button.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func() -> void: _copy_button.text = "Copy values")


func _on_reset_now_pressed() -> void:
	var keyboard := tank.driver_station.get_node_or_null(^"KeyboardDriverInput") as KeyboardDriverInput
	if keyboard != null:
		keyboard.clear_levels()
	tank.reset_to_spawn()


## Tell the tank where R should put it, from the ramp choice and distance.
func _apply_reset_point() -> void:
	_distance_label.text = "%d" % roundi(_distance_slider.value)
	var choice: int = _ramp_choice.selected
	if choice <= 0:
		tank.set_spawn(_start_field_spawn)
		return
	var reset_choice: Dictionary = _reset_choices[choice - 1]
	var ladder: SlopeLadder = reset_choice.ladder
	var where: Vector3 = ladder.start_position(reset_choice.index, _distance_slider.value, tank.contact_radius())
	# Facing the ramp (the ramps rise toward -Z, the way an unturned tank faces).
	tank.set_spawn(Transform3D(Basis.IDENTITY, where))


## Choose the reset point from code (used by the tests): ramp number
## `ramp_index` of `ladder`. ramp_index -1 = start field.
func choose_reset_point(ladder: SlopeLadder, ramp_index: int, distance: float) -> void:
	var item: int = 0
	for choice_number: int in _reset_choices.size():
		var reset_choice: Dictionary = _reset_choices[choice_number]
		if reset_choice.ladder == ladder and reset_choice.index == ramp_index:
			item = choice_number + 1
	_ramp_choice.select(item)
	_distance_slider.set_value_no_signal(distance)
	_apply_reset_point()


## Change a setting from code as if its slider was moved (used by the tests).
func set_setting(property: StringName, value: float) -> void:
	for index: int in _settings.size():
		if _settings[index].property == property:
			_sliders[index].value = value
			return
	push_warning("TuningPanel: no setting called %s" % property)


## The current values as text, grouped by where each one is set in the editor.
func values_text() -> String:
	var lines: PackedStringArray = [
		"# Tank tuning values copied from the game. To keep them, type them into the",
		"# Inspector for the file or node named in each heading (or paste them to Claude).",
	]
	var current_place: String = ""
	for setting: Dictionary in _settings:
		var place: String = _place_name(setting.target)
		if place != current_place:
			current_place = place
			lines.append("")
			lines.append("# " + place)
		var value: float = setting.target.get(setting.property)
		lines.append("%s = %s" % [setting.property, _format(value, setting.step)])
	return "\n".join(lines) + "\n"


func _place_name(target: Object) -> String:
	if target is TankTuning:
		return "tuning/tank_tuning.tres"
	if target is ChaseCamera:
		return "ChaseCamera node in scenes/test_course.tscn"
	if target is DriverSlitCamera:
		return "Visual/Hull/DriverSlitCamera node in scenes/tank.tscn"
	if target is TerrainType:
		return (target as TerrainType).resource_path
	return str(target)


# --- Small UI helpers -----------------------------------------------------

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	return label


func _name_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(170.0, 0.0)
	return label


func _number_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(55.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


## Sliders and buttons never take keyboard focus, so the arrow keys and Space
## keep driving the tank while the panel is open.
func _slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return slider


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


func _format(value: float, step: float) -> String:
	return str(snappedf(value, step))
