class_name DriverSlitCamera
extends Camera3D
## The driver's first-person view through a narrow vision slit at the front of
## the hull. It sits on the hull, so it tilts with the tank on slopes.
##
## The slit is drawn by this camera's own overlay (black above and below a
## horizontal strip), shown only while this view is active. Keeping the mask
## inside the camera means the whole view can later move to its own screen.

## Height of the open slit, as a fraction of the screen height (0.18 = 18%).
@export_range(0.02, 1.0) var slit_height: float = 0.18

## Thickness of the metal edge along the slit, in pixels.
@export var edge_thickness: float = 4.0

## Colour of the mask above and below the slit.
@export var mask_colour: Color = Color(0.0, 0.0, 0.0)

## Colour of the thin edge along the slit.
@export var edge_colour: Color = Color(0.22, 0.22, 0.2)

var _overlay: CanvasLayer


func _ready() -> void:
	_overlay = _build_overlay()
	add_child(_overlay)
	_overlay.visible = current


## Called by the ViewSwitcher to turn this view on or off.
func set_view_active(active: bool) -> void:
	current = active
	_overlay.visible = active


func is_slit_visible() -> bool:
	return _overlay.visible


func _build_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "SlitOverlay"
	# Below the debug display (layer 10), above the 3D view.
	layer.layer = 5
	var open_top: float = 0.5 - slit_height / 2.0
	var open_bottom: float = 0.5 + slit_height / 2.0
	layer.add_child(_band("MaskTop", 0.0, open_top, 0.0, 0.0, mask_colour))
	layer.add_child(_band("MaskBottom", open_bottom, 1.0, 0.0, 0.0, mask_colour))
	layer.add_child(_band("EdgeTop", open_top, open_top, 0.0, edge_thickness, edge_colour))
	layer.add_child(_band("EdgeBottom", open_bottom, open_bottom, -edge_thickness, 0.0, edge_colour))
	return layer


## A full-width strip between two heights (fractions of the screen), nudged by
## pixel offsets. Anchored, so it keeps its shape when the window is resized.
func _band(band_name: String, top: float, bottom: float, top_pixels: float,
		bottom_pixels: float, colour: Color) -> ColorRect:
	var band := ColorRect.new()
	band.name = band_name
	band.color = colour
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = top
	band.anchor_bottom = bottom
	band.offset_top = top_pixels
	band.offset_bottom = bottom_pixels
	return band
