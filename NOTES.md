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
- **Keyboard tread levels** (developer's idea, 2026-10-21): with `use_tread_levels` on (default),
  each press of W/S or Up/Down steps that tread one level between -3 and +3, and it stays there.
  The source reports level / 3, so the station and tank are unchanged. Space (`driver_all_stop`)
  and R set both levels to 0. Stopping still has inertia: from full speed the tank takes
  ~2.0 s and ~9.7 m to stop (set by `max_drive_accel`). Untick `use_tread_levels` on the
  `KeyboardDriverInput` node to go back to hold-to-drive. Gamepad sticks stay smooth.
- `DriverReadout` (top-left text) is temporary; it becomes part of the F3 debug display.
- Later, for several stations or controllers: move input sources out of the tank into a separate
  "Controls" node, and give each gamepad source a device number.

## Movement model
- `Tank` (`CharacterBody3D`) only ever turns left/right; it never tilts. `HullTilt` on
  `Visual/Hull` tilts the picture to the ground.
- Each tread is a `TankTread` (`scripts/tank_tread.gd`). Per physics frame:
  push needed = (target speed − speed) / delta + g·sin(slope) (so letting go brakes and holds),
  capped at `max_drive_accel`, then at the grip limit `traction_coeff·g·cos(slope)`;
  then speed += (push − g·sin(slope))·delta, minus a little rolling resistance.
- Forward speed = average of the treads. Turn rate = (right − left) / `track_width` ×
  (1 − `turn_resistance`). Left tread only = turns right.
- Slope = angle of the ground along the tank's facing, from Godot's floor normal.
- **Collision shape is a capsule** (radius 1.7, a sphere in practice), not a box, so it touches
  slopes near its centre and the tilted hull sits flush. Walls see a round tank. `HullTilt`'s
  `contact_radius` must match the capsule radius.
- **Ground press:** while driving, the tank is pushed 1 m/s into the ground
  (`GROUND_PRESS_SPEED`). Without it, floor contact flickered on/off every other frame on
  any slope (measured: 240 of 480 frames off the floor on 15° and 25°; 0 after the fix).
- No sideways sliding on slopes that lean left/right (could be added later).
- Hitting a wall stops the body but the treads keep their speed (they spin against it).
- Tuning lives in `tuning/tank_tuning.tres`; defaults in `scripts/tank_tuning.gd`.

## Test course
- Built at runtime by three nodes in `scenes/test_course.tscn`:
  - `CourseBuilder`: 300 × 300 m flat ground, 3 m boundary walls, kill-plane 20 m below
    (anything touching it is reset to the start).
  - `SlopeLadder` (at z = −70): ramps side by side, 8 m wide, 4 m apart, each 20 m along the
    slope, rising away from the start toward −Z. Green (gentle) to red (steep), with a floating
    angle label. The tank spawns at the origin, so every ramp has a 70 m run-up.
  - `RollingBumps` (at x = 100): 60 × 60 m of hills up to 2 m high, fading to flat at the edges.
- **Ramp list is a text file:** `levels/slope_ladder.txt`, one line per ramp: `25  ledge` or
  `30  no ledge`. Edit and press Play. (Developer's idea: some ramps have a flat 10 m platform
  on top, others end in a crest with a sheer drop. They alternate by default.)
- Ramps are wedges (`PrismMesh` with `left_to_right = 0`, turned −90° about Y), with convex
  collision made from the same mesh, so the angle is exact and the base sits flush.
- Bumps use a `HeightMapShape3D` and a mesh built from the same grid points.
- **For exporting later:** `levels/*.txt` must be added to the export's "non-resource files"
  filter, or the ramp list won't be found in an exported build.

## Milestone log
1. **Skeleton** (2026-10-21): project, folders, `.gitignore`, flat ground, placeholder tank,
   chase camera. Headless run: no errors; tank settles on the ground (y = 0.001, on floor).
2. **Input stations** (2026-10-21): `DriverStation`, keyboard and gamepad sources, Input Map,
   reset to spawn, temporary readout. Headless check with simulated key, stick and button events:
   10/10 passed (keys, sticks, deadzone, hardest-push-wins, both resets, direct writes, readout).
3. **Movement model** (2026-10-21): tread dynamics, turning, ground alignment, hull tilt,
   airborne fall, `TankTuning`. Headless check on temporary test slopes: flat straight 39.7 m in
   5 s; left only turns right; spin in place moves 0.0 m; holds still on 20°; slides back on 35°
   and 55°; climbs 25° slowly from rest (5.1 m/s); fails 30° from rest. Turn resistance raised
   0.4 → 0.75 after the first run (spinning was ~230°/s; now ~95°/s at full tread speed).
   Untested: driving off a ledge (no ledges until milestone 4), how it feels by hand.
4. **Slope Ladder course** (2026-10-21): ramps from a text file (with and without ledges),
   rolling bumps, walls, kill-plane. Headless check: all 10 ramp angles measured exact to
   0.01°, ledges present/absent as listed, bases flush with the ground, bump mesh faces up,
   35° with run-up reaches the ledge, kill-plane resets the tank in 2.2 s, driving across the
   bumps stays finite and above ground.

## Ideas for later (from play-testing)
- Tweak how hard the slopes are to climb (2026-10-21). Milestone 5's tests will show which
  tuning values move which ramps from "climbs" to "fails".
- Improve the feel of launching off a "no ledge" crest (2026-10-21): e.g. hang time, nose
  dipping in the air, a landing thump or camera shake.
5. **Tests and tuning** (2026-10-21): `tests/test_runner.tscn` runs 42 checks in about 4 s
   (input, course shape, flat driving, kill-plane, every ramp standing and with run-up, sanity).
   All targets met with the starting tuning values, so **no tuning changes were needed**.
   One test fix on the way: "standing start" first began 2.5 m in front of the ramp, which gave
   the tank a small run-in and let it climb 30°. It now starts at rest already touching the slope.

## Running the tests
```
C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```
- `--fixed-fps 60` runs physics as fast as possible instead of in real time (confirmed in
  `--help` for 4.6.3). Exit code 0 = all passed, 1 = something failed.
- Report is printed and saved to `tests/last_results.txt` (not committed: rewritten each run).
- To watch: open `tests/test_runner.tscn` in the editor and press F6. The camera follows one
  test tank; the window stays open at the end with a summary.

## Final tuning and test results
Tuning (`tuning/tank_tuning.tres`): max_tread_speed 10, max_drive_accel 5, rolling_resistance 0.1,
traction_coeff 0.55, g 9.8, track_width 3, turn_resistance 0.75, tilt_smoothing 8.

| Ramp | Standing start | With run-up (70 m) | Target |
|---|---|---|---|
| 5° ledge | climbs, 3.2 s | climbs, 10.0 s | climbs / climbs |
| 10° no ledge | climbs, 3.5 s | climbs, 10.0 s | climbs / climbs |
| 15° ledge | climbs, 4.0 s | climbs, 10.0 s | climbs / climbs |
| 20° no ledge | climbs, 4.8 s | climbs, 10.0 s | climbs / climbs |
| 25° ledge | climbs slowly, 7.0 s | climbs, 10.0 s | climbs / climbs |
| 30° no ledge | fails (4% up) | climbs, 10.1 s | fails / climbs |
| 35° ledge | fails (3% up) | climbs, 10.4 s | fails / climbs |
| 40° no ledge | fails (4% up) | **climbs**, 11.2 s | fails / either |
| 45° ledge | fails (3% up) | fails (78% up) | fails / fails |
| 55° no ledge | fails (5% up) | fails (49% up) | fails / fails |

Run-up times are mostly the 70 m approach (about 8 s at full speed).

### Which numbers change slope difficulty
- **Steepest slope climbable from a standstill** is set by `traction_coeff`: about
  atan(traction_coeff). 0.55 gives ~29°. (Also needs `max_drive_accel` ≥ g × sin(angle), which
  5.0 satisfies up to ~30°.)
- **How much a run-up helps** is set by `max_tread_speed`: faster arrival = coasts further up.
  Steeper ramps slow the tank faster, so there is always an angle no run-up can beat.
- **Grip on steep slopes**: lowering `traction_coeff` makes every steep ramp harder at once.
- Change a value, run the tests, and read the table.
