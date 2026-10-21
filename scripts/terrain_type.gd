class_name TerrainType
extends Resource
## What a kind of ground does to a tread driving on it. Each value adjusts the
## tank's normal tuning, so "firm ground" is simply no terrain at all.
## Each terrain is a file in terrain/ (e.g. terrain/mud.tres): click it to edit.

## Name shown in the debug display and tuning panel.
@export var display_name: String = "Terrain"

## Colour of the ground patch (until there is real art).
@export var colour: Color = Color(0.5, 0.5, 0.5)

## Grip, as a multiple of the tank's grip (multiplies tan of the tank's grip
## angle, its traction_coeff; e.g. 0.7 on a 28.8° tank = about 21°). Below 1 = slippier:
## steeper slopes can't be held or climbed, and pushing hard spins the tread.
@export_range(0.0, 2.0) var grip: float = 1.0

## Extra drag, in metres per second, per second, added to rolling resistance.
## High = the tread bogs down: hard to keep speed, stops quickly when let go.
@export_range(0.0, 10.0) var drag: float = 0.0

## Top speed on this ground, as a MULTIPLE of the tank's top_speed knob
## (which is in metres per second): 0.5 = half the tank's top speed.
@export_range(0.1, 1.5) var top_speed: float = 1.0

## How far the tank sinks into this ground, in metres. Only the picture
## sinks; the tank's body and collision stay where they are.
@export_range(0.0, 1.0) var sink_depth: float = 0.0
