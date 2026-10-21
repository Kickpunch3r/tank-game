class_name DebugHud
extends CanvasLayer
## Debug display in the top-left corner: the driver's input and what the tank
## is doing. F3 (Input Map: debug_hud_toggle) hides and shows it.

## The station to show.
@export var station: DriverStation

## The tank to show.
@export var tank: Tank

## Optional: shows which camera view is active.
@export var view_switcher: ViewSwitcher

## Optional: shows which feel preset is active.
@export var preset_switcher: PresetSwitcher

## Whether the display is showing when the game starts.
@export var start_visible: bool = true

var _label: Label
var _reset_count: int = 0


func _ready() -> void:
	# Above the slit mask (layer 5), so it stays readable in the slit view.
	layer = 10
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	add_child(_label)
	visible = start_visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_hud_toggle"):
		visible = not visible


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(station) or not is_instance_valid(tank):
		return
	if station.reset_requested:
		_reset_count += 1
	# Rebuilt from the station's and tank's state every frame.
	var lines: PackedStringArray = []
	var keyboard := station.get_node_or_null(^"KeyboardDriverInput") as KeyboardDriverInput
	if keyboard != null and keyboard.use_tread_levels:
		lines.append("Keyboard levels:  L %+d   R %+d   (Space = brake)" % [
			keyboard.left_level, keyboard.right_level])
	lines.append_array([
		"Left tread:  input %+.2f   speed %+5.1f m/s" % [station.left_tread, tank.left_tread.speed],
		"Right tread: input %+.2f   speed %+5.1f m/s" % [station.right_tread, tank.right_tread.speed],
		"Forward speed: %+5.1f m/s   Brake: %s" % [tank.forward_speed, "ON" if station.brake else "off"],
		"Engine push available: L %.1f  R %.1f  (of %.1f)" % [
			tank.left_tread.engine_output, tank.right_tread.engine_output, tank.tuning.max_drive_accel],
		"Slope: %+5.1f deg   On floor: %s" % [tank.slope_degrees, "yes" if tank.is_on_floor() else "no"],
		"Traction capped: %s" % ("YES" if tank.is_traction_capped() else "no"),
		"Ground: left %s, right %s" % [_terrain_name(tank.left_terrain), _terrain_name(tank.right_terrain)],
		"Sideways slide: %.2f m/s" % tank.slide_speed(),
		"Resets: %d" % _reset_count,
	])
	lines.append_array(_feel_lines(tank.tuning))
	if is_instance_valid(view_switcher):
		lines.append("View: %s   (V = switch, F3 = hide this)" % view_switcher.current_view_name())
	lines.append_array(_phone_lines())
	_label.text = "\n".join(lines)


## The feel knobs, the preset they match, and the slope limit they give.
func _feel_lines(tuning: TankTuning) -> PackedStringArray:
	var preset: String = ""
	if is_instance_valid(preset_switcher):
		preset = preset_switcher.preset_name_for(tuning)
	return [
		"Preset: %s   (1 heavy, 2 nimble, 3 slippery)" % (preset if not preset.is_empty() else "none (saved or changed tuning)"),
		"Knobs: weight %.2f  top speed %.1f  pulling power %.1f  grip %.1f°  sideways grip %.2f  tippiness %.2f" % [
				tuning.weight, tuning.top_speed, tuning.pulling_power, tuning.grip, tuning.sideways_grip, tuning.tippiness],
		"Climbable from a standstill: %.1f° (grip %.1f°, engine %.1f°)" % [
				tuning.climbable_limit_degrees(), tuning.grip, tuning.engine_limit_degrees()],
	]


## Phone controller status, if the scene has a ControllerServer.
func _phone_lines() -> PackedStringArray:
	var server := get_tree().get_first_node_in_group(ControllerServer.GROUP) as ControllerServer
	if server == null:
		return []
	if not server.problem().is_empty():
		return ["Phone: off (%s)" % server.problem()]
	var urls: PackedStringArray = server.controller_urls()
	var link := get_tree().get_first_node_in_group(UsbPhoneLink.GROUP) as UsbPhoneLink
	var lines: PackedStringArray = [
		"Wi-Fi phones: %s" % (("  ".join(urls) if not urls.is_empty() else "no network found") if server.allow_wifi_phones else "off (this computer only)"),
		link.describe() if link != null else "USB phone: no USB link in this scene",
		"Phones connected: %d   Driver phone: %s" % [server.phone_count(),
				("#%d" % server.driver_id()) if server.driver_id() != 0 else "none"],
	]
	if server.driver_id() != 0:
		var since_ms: int = roundi(server.seconds_since_driver_message() * 1000.0) if is_finite(server.seconds_since_driver_message()) else -1
		lines.append("Driver phone: last message %s ago, L %+.2f R %+.2f %s" % [
				("%d ms" % since_ms) if since_ms >= 0 else "never", server.latest_left, server.latest_right,
				"(driving)" if server.is_driver_live() else "(watchdog: treads 0)"])
	return lines


func _terrain_name(terrain: TerrainType) -> String:
	return terrain.display_name if terrain != null else "firm"
