class_name PhoneStatusLabel
extends CanvasLayer
## A few lines at the bottom-left of the screen: how to connect a phone (by
## USB cable, and by Wi-Fi if switched on) and whether one is connected.
## Rebuilt from the server's and USB link's state twice a second.

## The server to describe.
@export var server: ControllerServer

## The USB phone link to describe (optional).
@export var usb_link: UsbPhoneLink

## Optional: show these lines only while this debug display is open (F3).
@export var debug_hud: DebugHud

var _label: Label
var _seconds_since_update: float = 1.0


func _ready() -> void:
	_label = Label.new()
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = 12.0
	_label.offset_bottom = -10.0
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	add_child(_label)


func _process(delta: float) -> void:
	visible = debug_hud == null or debug_hud.visible
	_seconds_since_update += delta
	if _seconds_since_update < 0.5:
		return
	_seconds_since_update = 0.0
	_label.text = "\n".join(describe(server, usb_link))


## The lines of text for the current state.
static func describe(controller_server: ControllerServer, link: UsbPhoneLink) -> PackedStringArray:
	var lines := PackedStringArray()
	if controller_server == null:
		return lines
	if not controller_server.problem().is_empty():
		lines.append("Phone controller off: %s" % controller_server.problem())
		return lines
	if controller_server.allow_wifi_phones:
		var urls: PackedStringArray = controller_server.controller_urls()
		lines.append("Wi-Fi phone: open %s" % ("  or  ".join(urls) if not urls.is_empty() else "(no network found)"))
	if link != null:
		lines.append(link.describe())
	if controller_server.driver_id() != 0:
		lines.append("Phone: driver connected")
	elif controller_server.phone_count() > 0:
		lines.append("Phone: %d connected, none driving" % controller_server.phone_count())
	return lines
