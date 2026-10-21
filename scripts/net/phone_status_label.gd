class_name PhoneStatusLabel
extends CanvasLayer
## A small line at the bottom-left of the screen with the web address to open
## on a phone, and whether a phone is connected. Rebuilt from the server's
## state twice a second.

## The server to describe.
@export var server: ControllerServer

var _label: Label
var _seconds_since_update: float = 1.0


func _ready() -> void:
	_label = Label.new()
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 12.0
	_label.offset_top = -36.0
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	add_child(_label)


func _process(delta: float) -> void:
	_seconds_since_update += delta
	if _seconds_since_update < 0.5:
		return
	_seconds_since_update = 0.0
	_label.text = describe(server)


## The line of text for a server's current state.
static func describe(controller_server: ControllerServer) -> String:
	if controller_server == null:
		return ""
	if not controller_server.problem().is_empty():
		return "Phone controller off: %s" % controller_server.problem()
	var urls: PackedStringArray = controller_server.controller_urls()
	var address: String = "  or  ".join(urls) if not urls.is_empty() else "no network found (join a hotspot or router)"
	var phones: String
	if controller_server.driver_id() != 0:
		phones = "driver phone connected"
	elif controller_server.phone_count() > 0:
		phones = "%d phone(s) connected, no driver" % controller_server.phone_count()
	else:
		phones = "no phone connected"
	return "Phone controller: open %s on your phone  (%s)" % [address, phones]
