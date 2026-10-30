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

## The tank whose tuning and slit camera are being changed (either kind;
## the PlayerRig swaps it and calls rebuild()).
@export var tank: Node3D

## The chase camera whose follow settings are being changed.
@export var chase_camera: ChaseCamera

## Rows of ramps (SlopeLadder nodes) are found in the scene automatically, for
## choosing where reset puts the tank.

## Distance back from the chosen ramp when the panel starts, in metres.
@export var start_distance: float = 0.0

# One entry per setting: which object, which property, slider range, and the
# value it had when the game started (for "Reset to saved").
var _settings: Array[Dictionary] = []
var _sliders: Array[HSlider] = []
var _value_fields: Array[LineEdit] = []

var _ramp_choice: OptionButton
# One entry per dropdown item after "Start field": {"ladder": SlopeLadder, "index": int}
# for a ramp, or {"transform": Transform3D} for a comparison feature's start.
var _reset_choices: Array[Dictionary] = []
var _distance_slider: HSlider
var _distance_field: LineEdit
var _copy_button: Button
var _panel: PanelContainer
## The debug button that swaps tanks (null when there is only one tank).
var swap_button: Button
## The debug tick box that shows the test labels (null when there are none).
var labels_box: CheckBox
## The Graphics section's tick boxes, by option name (see GraphicsOptions).
var graphics_boxes: Dictionary = {}
# Value at the start of the game, by target and property (see _saved_key):
# {"target": Object, "property": StringName, "value": Variant}.
var _saved_values: Dictionary = {}


func _ready() -> void:
	layer = 20
	visible = false
	_remember_all_tank_tunings()
	_define_settings()
	_build_panel()


## Build the panel again from the current values, e.g. after swapping tanks
## or after changing tank. Keeps it open or closed, scrolled and with the same
## reset point.
func rebuild() -> void:
	_stop_typing()
	var scroll_position: int = 0
	var scrolls: Array[Node] = _panel.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		scroll_position = (scrolls[0] as ScrollContainer).scroll_vertical
	var ramp_item: int = _ramp_choice.selected
	var distance: float = _distance_slider.value
	remove_child(_panel)
	_panel.queue_free()
	_sliders.clear()
	_value_fields.clear()
	_reset_choices.clear()
	_define_settings()
	_build_panel()
	_ramp_choice.select(ramp_item)
	_distance_slider.set_value_no_signal(distance)
	_apply_reset_point()
	var new_scroll := _panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	new_scroll.set_deferred(&"scroll_vertical", scroll_position)


## Runs before the panel's own controls see the event, so Tab always opens and
## closes the panel, even while typing in a value box.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tuning_panel_toggle"):
		_stop_typing()
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	# Clicking anywhere outside the box being typed in finishes the typing,
	# so the driving keys go back to the tank.
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed:
		var typing_in := get_viewport().gui_get_focus_owner() as LineEdit
		if typing_in != null and not typing_in.get_global_rect().has_point(mouse_button.position):
			typing_in.release_focus()


## Finish typing in any value box (its value is applied as it lets go).
func _stop_typing() -> void:
	var typing_in := get_viewport().gui_get_focus_owner() as LineEdit
	if typing_in != null:
		typing_in.release_focus()


# --- What can be changed ---------------------------------------------------

func _define_settings() -> void:
	_settings.clear()
	# The tank's own tuning lists its rows (feel knobs first, then advanced).
	var tuning: Resource = tank.get(&"tuning")
	for row: Dictionary in tuning.call(&"panel_settings"):
		_add_setting(row.group, tuning, row.property, row.min, row.max, row.step, row.hard_min, row.hard_max)
	var slit: DriverSlitCamera = tank.get_node(^"Visual/Hull/DriverSlitCamera")
	# Slider range first (just a comfortable dragging range: typed values can
	# go past it), then hard limits only where other values break the maths.
	_add_setting("Chase camera", chase_camera, &"follow_distance", 0.0, 100.0, 0.5)
	_add_setting("Chase camera", chase_camera, &"follow_height", -10.0, 60.0, 0.5, -INF)
	_add_setting("Chase camera", chase_camera, &"look_height", -10.0, 20.0, 0.1, -INF)
	_add_setting("Chase camera", chase_camera, &"follow_smoothing", 0.0, 40.0, 0.5)
	# A fraction of the screen.
	_add_setting("Driver slit", slit, &"slit_height", 0.0, 1.0, 0.01, 0.0, 1.0)
	for node: Node in get_tree().get_nodes_in_group(LevelTerrain.GROUP):
		var level := node as LevelTerrain
		_add_setting("Level ground", level, &"metres_per_pixel", 0.25, 10.0, 0.25, 0.05)
		_add_setting("Level ground", level, &"max_height", 0.0, 300.0, 0.5)
		# Every pass takes a moment; 50 is already a very soft blur.
		_add_setting("Level ground", level, &"smoothing", 0.0, 20.0, 1.0, 0.0, 50.0)
	for terrain: TerrainType in _terrain_types_in_scene():
		var group: String = "Terrain: %s" % terrain.display_name
		_add_setting(group, terrain, &"grip", 0.0, 3.0, 0.05)
		_add_setting(group, terrain, &"drag", 0.0, 20.0, 0.1)
		_add_setting(group, terrain, &"top_speed", 0.0, 3.0, 0.05)
		_add_setting(group, terrain, &"sink_depth", 0.0, 2.0, 0.05)


## Every row of ramps in the scene.
func _slope_ladders_in_scene() -> Array[SlopeLadder]:
	var found: Array[SlopeLadder] = []
	for node: Node in get_tree().get_nodes_in_group(SlopeLadder.GROUP):
		found.append(node as SlopeLadder)
	return found


## Every different terrain used by a patch in the scene, in the order found.
func _terrain_types_in_scene() -> Array[TerrainType]:
	var found: Array[TerrainType] = []
	for node: Node in get_tree().get_nodes_in_group(TerrainPatch.GROUP):
		var patch := node as TerrainPatch
		if patch != null and patch.terrain != null and not found.has(patch.terrain):
			found.append(patch.terrain)
	return found


## slider_min/slider_max: the slider's dragging range. hard_min/hard_max: the
## only limits on typed values (default: anything 0 or above).
func _add_setting(group: String, target: Object, property: StringName,
		slider_min: float, slider_max: float, step: float,
		hard_min: float = 0.0, hard_max: float = INF) -> void:
	var value: float = target.get(property)
	# "Reset to saved" goes back to the value at the very start, even after
	# the panel was rebuilt (e.g. after swapping tanks).
	_remember_saved(target, property)
	var key: String = _saved_key(target, property)
	_settings.append({
		"group": group,
		"target": target,
		"property": property,
		# If the current value is already outside the slider's range, widen it.
		"min": minf(slider_min, value),
		"max": maxf(slider_max, value),
		"step": step,
		"hard_min": hard_min,
		"hard_max": hard_max,
		"saved": _saved_values[key].value,
	})


## Remember a value as it was at the start of the game (only the first time).
func _remember_saved(target: Object, property: StringName) -> void:
	var key: String = _saved_key(target, property)
	if not _saved_values.has(key):
		_saved_values[key] = {"target": target, "property": property, "value": target.get(property)}


## Also remember every tank's tuning in the player rig, including a hidden
## tank's, so "Reset to saved" puts back values changed on it.
func _remember_all_tank_tunings() -> void:
	var rig := get_parent() as PlayerRig
	if rig == null:
		return
	for each_tank: Node3D in rig.tanks:
		var tuning: Resource = each_tank.get(&"tuning")
		for row: Dictionary in tuning.call(&"panel_settings"):
			_remember_saved(tuning, row.property)


func _saved_key(target: Object, property: StringName) -> String:
	return "%d/%s" % [target.get_instance_id(), property]


# --- Building the panel ----------------------------------------------------

func _build_panel() -> void:
	var panel := PanelContainer.new()
	_panel = panel
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
	_build_graphics(list)
	_build_debug(list)

	var current_group: String = ""
	for index: int in _settings.size():
		var setting: Dictionary = _settings[index]
		if setting.group != current_group:
			current_group = setting.group
			list.add_child(_heading(current_group))
		list.add_child(_setting_row(index))


## Graphics section: switch off extras if the game runs slowly.
func _build_graphics(list: VBoxContainer) -> void:
	graphics_boxes = {}
	list.add_child(_heading("Graphics  (switch off if the game runs slowly)"))
	for option: StringName in GraphicsOptions.LABELS:
		var box := CheckBox.new()
		box.text = GraphicsOptions.LABELS[option]
		box.focus_mode = Control.FOCUS_NONE
		box.button_pressed = GraphicsOptions.is_on(option)
		box.toggled.connect(func(on: bool) -> void: GraphicsOptions.set_on(get_tree(), option, on))
		list.add_child(box)
		graphics_boxes[option] = box


## Debug section: show or hide the test pieces' labels, and swap between the
## physics tank and the old kinematic tank (kept for comparison).
func _build_debug(list: VBoxContainer) -> void:
	swap_button = null
	labels_box = null
	var rig := get_parent() as PlayerRig
	var can_swap: bool = rig != null and rig.tanks.size() >= 2
	if not can_swap and not TestLabels.exist(get_tree()):
		return
	list.add_child(_heading("Debug"))
	if TestLabels.exist(get_tree()):
		labels_box = CheckBox.new()
		labels_box.text = "Show test labels (ramp angles, course pieces)"
		labels_box.focus_mode = Control.FOCUS_NONE
		# Shown as the labels are now (rebuilt from state).
		labels_box.button_pressed = TestLabels.are_shown(get_tree())
		labels_box.toggled.connect(func(on: bool) -> void: TestLabels.set_shown(get_tree(), on))
		list.add_child(labels_box)
	if not can_swap:
		return
	var text: String = "Swap to kinematic tank (old)" if tank is PhysicsTank else "Swap back to physics tank"
	# Deferred: the swap rebuilds this panel, button included.
	swap_button = _button(text, func() -> void: rig.swap_tank.call_deferred())
	list.add_child(swap_button)


func _build_reset_point(list: VBoxContainer) -> void:
	list.add_child(_heading("Reset point (where R puts you)"))
	_ramp_choice = OptionButton.new()
	_ramp_choice.focus_mode = Control.FOCUS_NONE
	_ramp_choice.add_item("Level start")
	var longest_run_up: float = 0.0
	for ladder: SlopeLadder in _slope_ladders_in_scene():
		longest_run_up = maxf(longest_run_up, ladder.run_up_length)
		for index: int in ladder.ramps.size():
			var ramp: SlopeLadder.RampInfo = ladder.ramps[index]
			var text: String = "%d° %s" % [roundi(ramp.angle_degrees), "ledge" if ramp.has_ledge else "no ledge"]
			if ramp.terrain != null:
				text += ", " + ramp.terrain.display_name.to_lower()
			_ramp_choice.add_item(text)
			_reset_choices.append({"ladder": ladder, "index": index})
	for features: Node in get_tree().get_nodes_in_group(ComparisonFeatures.GROUP):
		for point: Dictionary in (features as ComparisonFeatures).reset_points():
			_ramp_choice.add_item(point.name)
			_reset_choices.append({"transform": point.transform})
	_ramp_choice.item_selected.connect(func(_index: int) -> void: _apply_reset_point())
	list.add_child(_ramp_choice)

	var row := HBoxContainer.new()
	row.add_child(_name_label("Distance back (m)"))
	_distance_slider = _slider(0.0, longest_run_up, 1.0, start_distance)
	_distance_slider.value_changed.connect(func(_value: float) -> void: _apply_reset_point())
	row.add_child(_distance_slider)
	_distance_field = _value_field(_on_distance_typed)
	row.add_child(_distance_field)
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
	var field: LineEdit = _value_field(func(text: String) -> void: _on_value_typed(index, text))
	field.text = _format(setting.target.get(setting.property))
	row.add_child(field)
	_sliders.append(slider)
	_value_fields.append(field)
	return row


# --- Reacting to the controls ----------------------------------------------

func _on_setting_changed(index: int, value: float) -> void:
	var setting: Dictionary = _settings[index]
	var target: Object = setting.target
	# Whole-number settings (like smoothing passes) get whole numbers.
	if typeof(target.get(setting.property)) == TYPE_INT:
		value = roundf(value)
		target.set(setting.property, int(value))
	else:
		target.set(setting.property, value)
	_value_fields[index].text = _format(value)
	if target.has_method(&"on_setting_changed"):
		target.call(&"on_setting_changed")


## A value typed into a box: used exactly (not rounded to the slider's steps).
## It may go past the slider's ends (the slider stretches to fit); only the
## setting's hard limits apply. Anything that isn't a number is ignored.
func _on_value_typed(index: int, text: String) -> void:
	var setting: Dictionary = _settings[index]
	var cleaned: String = text.strip_edges()
	if not cleaned.is_valid_float():
		_value_fields[index].text = _format(setting.target.get(setting.property))
		return
	var value: float = clampf(cleaned.to_float(), setting.hard_min, setting.hard_max)
	var slider: HSlider = _sliders[index]
	slider.min_value = minf(slider.min_value, value)
	slider.max_value = maxf(slider.max_value, value)
	slider.set_value_no_signal(value)
	_on_setting_changed(index, value)


func _on_distance_typed(text: String) -> void:
	var cleaned: String = text.strip_edges()
	if cleaned.is_valid_float():
		_distance_slider.set_value_no_signal(clampf(cleaned.to_float(), 0.0, _distance_slider.max_value))
	_apply_reset_point()


func _on_reset_to_saved_pressed() -> void:
	var shown: Dictionary = {}
	for index: int in _settings.size():
		var setting: Dictionary = _settings[index]
		_sliders[index].set_value_no_signal(setting.saved)
		_on_setting_changed(index, setting.saved)
		shown[_saved_key(setting.target, setting.property)] = true
	# Values not on show right now (the hidden tank's tuning) go back too.
	for key: String in _saved_values:
		var saved: Dictionary = _saved_values[key]
		if not shown.has(key) and is_instance_valid(saved.target):
			(saved.target as Object).set(saved.property, saved.value)


func _on_copy_pressed() -> void:
	var text: String = values_text()
	DisplayServer.clipboard_set(text)
	print(text)
	_copy_button.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func() -> void: _copy_button.text = "Copy values")


func _on_reset_now_pressed() -> void:
	var keyboard := tank.get_node_or_null(^"DriverStation/KeyboardDriverInput") as KeyboardDriverInput
	if keyboard != null:
		keyboard.clear_levels()
	tank.call(&"reset_to_spawn")


## Tell the tank where R should put it, from the ramp choice and distance.
func _apply_reset_point() -> void:
	_distance_field.text = _format(_distance_slider.value)
	var choice: int = _ramp_choice.selected
	if choice <= 0:
		tank.call(&"set_spawn", tank.call(&"get_home"))
		return
	var reset_choice: Dictionary = _reset_choices[choice - 1]
	if reset_choice.has("transform"):
		# A comparison feature's start (the distance slider is for ramps only).
		tank.call(&"set_spawn", reset_choice.transform)
		return
	var ladder: SlopeLadder = reset_choice.ladder
	var where: Vector3 = ladder.start_position_for(reset_choice.index, _distance_slider.value, tank)
	# Facing the ramp (the ramps rise toward -Z, the way an unturned tank faces).
	tank.call(&"set_spawn", Transform3D(Basis.IDENTITY, where))


## Choose the reset point from code (used by the tests): ramp number
## `ramp_index` of `ladder`. ramp_index -1 = start field.
func choose_reset_point(ladder: SlopeLadder, ramp_index: int, distance: float) -> void:
	var item: int = 0
	for choice_number: int in _reset_choices.size():
		var reset_choice: Dictionary = _reset_choices[choice_number]
		if reset_choice.get("ladder") == ladder and reset_choice.get("index") == ramp_index:
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


## The slider and typing box for a setting (used by the tests).
func controls_for(property: StringName) -> Dictionary:
	for index: int in _settings.size():
		if _settings[index].property == property:
			return {"slider": _sliders[index], "field": _value_fields[index]}
	return {}


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
		lines.append("%s = %s" % [setting.property, _format(value)])
	return "\n".join(lines) + "\n"


func _place_name(target: Object) -> String:
	if target is TankTuning or target is PhysicsTankTuning:
		var path: String = (target as Resource).resource_path
		if not path.is_empty():
			return path.trim_prefix("res://")
		return "tuning/tank_tuning.tres" if target is TankTuning else "tuning/physics_tank_tuning.tres"
	if target is ChaseCamera:
		return "ChaseCamera node in scenes/test_course.tscn"
	if target is DriverSlitCamera:
		var tank_scene: String = "scenes/physics_tank.tscn" if tank is PhysicsTank else "scenes/tank.tscn"
		return "Visual/Hull/DriverSlitCamera node in %s" % tank_scene
	if target is TerrainType:
		return (target as TerrainType).resource_path
	if target is LevelTerrain:
		return "LevelTerrain node in %s" % (target as Node).owner.scene_file_path
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


## A box showing a value that you can click and type a new value into.
## Enter, clicking elsewhere or Tab finishes typing and applies the value.
## While typing, keys go to the box, not the tank.
func _value_field(on_typed: Callable) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(64.0, 0.0)
	field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field.select_all_on_focus = true
	field.text_submitted.connect(func(_text: String) -> void: field.release_focus())
	# Applying on focus loss covers Enter, clicking away and Tab alike.
	field.focus_exited.connect(func() -> void: on_typed.call(field.text))
	return field


## Sliders and buttons never take keyboard focus, so the arrow keys and Space
## keep driving the tank while the panel is open. Sliders also ignore the
## mouse wheel, so scrolling the panel never changes a value by accident.
func _slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.scrollable = false
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return slider


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


## Up to 4 decimal places, without trailing zeros (10, 0.55, 0.1234).
func _format(value: float) -> String:
	return String.num(value, 4)
