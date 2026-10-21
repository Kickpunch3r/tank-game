# Notes

## Godot
- Version: **4.6.3 stable** (`4.6.3.stable.official.7d41c59c4`).
- Editor: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe`
- Headless checks: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe --headless --path .`
- Renderer: Forward+ on Direct3D 12 (same as the finger-walk project, known to work on this laptop).
  Physics engine: Jolt.

## Decisions
- **Scene files written as text** (allowed in this project, see CLAUDE.md). Scenes reference files
  by path with no UIDs; Godot 4.6 loads them fine and creates `.gd.uid` files next to scripts.
  Commit those `.uid` files.
- **Graphics:** each object keeps its looks in a `Visual` child node. The tank's meshes sit under
  `Visual/Hull` so milestone 3 can tilt the hull without touching the collision body.
  Forward is **-Z** (Godot's convention); the barrel and yellow nose marker point that way.
- **Ground** is built by `scripts/course_builder.gd` when the scene starts, with a world-space
  checker shader (`art/checker_ground.gdshader`) so speed is easy to read. Because it is built at
  runtime, the ground does not show in the editor viewport, only when the game runs.
- **Chase camera** follows the tank's heading only, never its tilt, so it stays level. It updates
  in `_physics_process`. Possible later fix if it looks juddery on a high-refresh screen: turn on
  physics interpolation.

## Input stations
- The tank **never reads `Input`**. It reads only its `DriverStation` child node
  (`left_tread`, `right_tread` in -1..1, `reset_requested` for one frame).
- Input sources are child nodes of the station that extend `DriverInputSource`:
  `KeyboardDriverInput` and `GamepadDriverInput`. To add new hardware (MIDI, serial, levers),
  write a new `DriverInputSource` script and add it as another child.
- **Combining:** each frame the station asks every source; for each tread the hardest push wins,
  and reset fires if any source pressed it. So an untouched gamepad never cancels the keyboard.
- The station runs before the tank each physics frame (`process_physics_priority = -10`).
- **Tests** set `listen_to_input_sources = false` and write values into the station directly.
- Input Map actions (Project Settings > Input Map): `driver_left_forward/back` (W/S),
  `driver_right_forward/back` (Up/Down), `driver_reset` (R), and the gamepad versions ending
  in `_pad` (left stick Y, right stick Y, Back/Select). All with deadzone 0.2.
- **Gamepad is untested on real hardware** (the developer has none). It was checked only with
  simulated stick and button events.
- `DriverReadout` (top-left text) is temporary; it becomes part of the F3 debug display.
- Later, for several stations or controllers: move input sources out of the tank into a separate
  "Controls" node, and give each gamepad source a device number.

## Milestone log
1. **Skeleton** (2026-10-21): project, folders, `.gitignore`, flat ground, placeholder tank,
   chase camera. Headless run: no errors; tank settles on the ground (y = 0.001, on floor).
2. **Input stations** (2026-10-21): `DriverStation`, keyboard and gamepad sources, Input Map,
   reset to spawn, temporary readout. Headless check with simulated key, stick and button events:
   10/10 passed (keys, sticks, deadzone, hardest-push-wins, both resets, direct writes, readout).
