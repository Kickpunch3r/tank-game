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
		lines.append("Keyboard levels:  L %+d   R %+d   (Space = all stop)" % [
			keyboard.left_level, keyboard.right_level])
	lines.append_array([
		"Left tread:  input %+.2f   speed %+5.1f m/s" % [station.left_tread, tank.left_tread.speed],
		"Right tread: input %+.2f   speed %+5.1f m/s" % [station.right_tread, tank.right_tread.speed],
		"Forward speed: %+5.1f m/s" % tank.forward_speed,
		"Slope: %+5.1f deg   On floor: %s" % [tank.slope_degrees, "yes" if tank.is_on_floor() else "no"],
		"Traction capped: %s" % ("YES" if tank.is_traction_capped() else "no"),
		"Ground: left %s, right %s" % [_terrain_name(tank.left_terrain), _terrain_name(tank.right_terrain)],
		"Resets: %d" % _reset_count,
	])
	if is_instance_valid(view_switcher):
		lines.append("View: %s   (V = switch, F3 = hide this)" % view_switcher.current_view_name())
	_label.text = "\n".join(lines)


func _terrain_name(terrain: TerrainType) -> String:
	return terrain.display_name if terrain != null else "firm"
