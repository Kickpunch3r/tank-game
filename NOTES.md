# Notes

How the project is built, what was decided and why, test results, known issues, and what to
check by hand. For how to run and play, see [README.md](README.md).

## Godot
- Version: **4.6.3 stable** (`4.6.3.stable.official.7d41c59c4`).
- Editor: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe`
- Console (headless checks and tests): `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe`
- Renderer: Forward+ on Direct3D 12 (Intel HD Graphics 520 on this laptop). Physics: Jolt.

## Architecture

### Input stations
- The tank **never reads `Input`**. It reads only its `DriverStation` child node:
  `left_tread` and `right_tread` (−1 to 1) and `reset_requested` (true for one frame).
- Input sources are child nodes of the station that extend `DriverInputSource`:
  `KeyboardDriverInput` and `GamepadDriverInput`. **To add new hardware** (MIDI, serial, giant
  levers): write a new `DriverInputSource` script and add it as another child.
- **Combining:** each physics frame the station asks every source. For each tread, the hardest
  push wins, and reset fires if any source pressed it. So an untouched gamepad never cancels
  the keyboard.
- The station runs before the tank each physics frame (`process_physics_priority = -10`).
- **Tests** set `listen_to_input_sources = false` and write values into the station directly.
- **Keyboard tread levels** (developer's idea): with `use_tread_levels` on (default), each press
  steps a tread one level between −3 and +3, and it stays there, like a notched throttle lever.
  The source reports level ÷ 3, so the station and tank don't know about levels. Space
  (`driver_all_stop`) and R set both to 0. Untick `use_tread_levels` for hold-to-drive.
- Input Map actions: `driver_left_forward/back` (W/S), `driver_right_forward/back` (Up/Down),
  `driver_all_stop` (Space), `driver_reset` (R), gamepad versions ending in `_pad`
  (left stick Y, right stick Y, Back/Select; deadzone 0.2), `view_toggle` (V),
  `debug_hud_toggle` (F3).
- **Later**, for several stations: move input sources out of the tank into a separate
  "Controls" node, and give each gamepad source a device number. Other stations
  (`GunnerStation`, …) follow the same pattern as `DriverStation`.

### Movement model
- `Tank` is a `CharacterBody3D` that only ever turns left/right; it never tilts. `HullTilt` on
  `Visual/Hull` tilts the picture to match the ground.
- Each tread is a `TankTread` (`scripts/tank_tread.gd`). Every physics frame:
  1. Push needed = (target speed − speed) ÷ delta + g·sin(slope). Including gravity means
     letting go brakes and holds the tank still.
  2. Capped at `max_drive_accel`, then at the grip limit `traction_coeff·g·cos(slope)`
     ("traction capped").
  3. speed += (push − g·sin(slope))·delta, then a little rolling resistance toward zero.
- Forward speed = average of the treads. Turn rate = (right − left) ÷ `track_width` ×
  (1 − `turn_resistance`). Left tread only turns right.
- Slope = angle of the ground along the tank's facing, from Godot's floor normal.
- In the air: keeps its horizontal speed, falls, treads do nothing.
- **Collision shape is a capsule** (radius 1.7, a sphere in practice), so it touches slopes
  near its centre and the tilted hull sits flush. `HullTilt.contact_radius` must match it.
- **Ground press:** while driving, the tank is pushed 1 m/s into the ground
  (`GROUND_PRESS_SPEED`). Without it, floor contact flickered on and off every other frame on
  any slope (240 of 480 frames on 15° and 25°; 0 after the fix).
- `floor_max_angle` is 60°, so the slope rules, not Godot's floor limit, decide what climbs.

### Cameras and views
- `ChaseCamera` (in the course): behind and above, smoothed, follows heading only, never rolls.
- `DriverSlitCamera` (on `Tank/Visual/Hull`, at the front): first-person, tilts with the hull.
  It owns its overlay (CanvasLayer 5): black above and below a horizontal slit (18% of the
  screen, `slit_height`) with thin dark edges, shown only while this view is active.
- `ViewSwitcher` (in the course) cycles its `views` list on V, calling each camera's
  `set_view_active(bool)`. **For separate screens later:** give each camera its own
  `SubViewport` and drop the switcher; each camera already carries its own overlay.
- `DebugHud` (CanvasLayer 10, above the slit): input, levels, tread speeds, forward speed,
  slope, on floor, traction capped, resets, current view. F3 hides/shows it.

### Tuning panel and air/landing levers (added 2026-10-21, after milestone 7)
- `TuningPanel` (CanvasLayer 20, in the course, Tab = `tuning_panel_toggle`): sliders for every
  `TankTuning` value, the `ChaseCamera` follow settings and `DriverSlitCamera.slit_height`.
  Built in code from a list in `_define_settings()`; add a line there to expose a new value.
- **Changes are session-only** (developer's choice, over saving into the .tres). "Copy values"
  gives the numbers as text, grouped by the file or node they belong in.
- Sliders and buttons have no keyboard focus, so arrows and Space keep driving.
- A target that needs to react to a change (the slit redraws itself) has an
  `on_setting_changed()` method, which the panel calls.
- The tuning resource is shared by every tank that uses `tank_tuning.tres`; the panel changes it
  in memory only. Tests that change tuning give their tank its own `duplicate()`.
- **Reset point:** the panel calls `Tank.set_spawn()`. Positions come from
  `SlopeLadder.start_position(ramp, distance, tank radius)`, the same rule the standing-start
  tests use (at distance 0 the tank is at rest, touching the slope).
- **New levers in `TankTuning` ("Air and landing")**, all defaulting to the old behaviour:
  - `air_gravity_scale` (1.0): gravity multiplier in the air only. 0.5 → a 20 m drop takes
    2.85 s instead of 2.02 s.
  - `nose_dip` (0.0): how much the hull picture tips to follow its flight path in the air
    (`HullTilt._flight_pitch()`). At 1 the nose points ~40° down after a second of falling.
  - `landing_speed_loss` (0.0): fraction of tread speed lost on a hard landing, scaled by fall
    speed (10 m/s counts as fully hard). 0.5 on a 5 m drop: 8.0 → 4.1 m/s.
- Side result from a broken test run: with `max_tread_speed` 15, the 45° and 55° ramps become
  climbable with a run-up (7.8 s and 8.3 s). Top speed strongly sets what a run-up can beat.

### Test course
- Built when the scene starts, by three nodes in `scenes/test_course.tscn`:
  - `CourseBuilder`: 300 × 300 m flat ground (world-space checker shader), 3 m walls,
    kill-plane 20 m below that resets a tank to its start.
  - `SlopeLadder` (at z = −70): ramps side by side, 8 m wide, 4 m apart, 20 m along the slope,
    rising away from the start toward −Z. Green (gentle) to red (steep), floating angle labels.
    The tank starts at the origin, so every ramp has a 70 m run-up.
  - `RollingBumps` (at x = 100): 60 × 60 m of hills up to 2 m high, fading to flat at the edges.
- **Ramp list is a text file**, `levels/slope_ladder.txt`: `25  ledge` or `30  no ledge`.
  Ledge = a flat 10 m platform on top; no ledge = a sharp crest with a sheer drop. They
  alternate by default (developer's idea).
- Ramps are wedges (`PrismMesh`, `left_to_right = 0`, turned −90° about Y) with convex collision
  made from the same mesh, so angles are exact and bases sit flush. Bumps use a
  `HeightMapShape3D` and a mesh built from the same grid points.

### Graphics
- Primitive meshes only. Everything you see is inside a `Visual` child node, so art (low-poly
  models or Doom-style sprites) can be swapped without touching logic. The tank's meshes are
  under `Visual/Hull`; forward is −Z, where the barrel and yellow nose marker point.

## Decisions
- **Scene and resource files are written as text** (allowed in this project, with safeguards:
  see CLAUDE.md). They reference files by path with no UIDs; Godot 4.6 loads them fine and makes
  `.uid` files next to scripts, which are committed.
- **Rounded collision shape instead of a box** (milestone 3): an upright box on a 35° slope
  rests on its edge with its centre ~1.7 m above the surface, so the tilted hull would float.
- **Standing-start test = at rest, already touching the slope** (milestone 5). Starting 2.5 m in
  front gave a run-in that let the tank climb 30°.
- **Tuning unchanged in milestone 5**: the starting values (worked out from the targets) met
  every target, so none were changed. Earlier, `turn_resistance` was raised 0.4 → 0.75 in
  milestone 3 because spinning was ~230°/s; it is now ~95°/s at full tread speed.
- **Course built from code** so angles are exact and easy to change; the cost is that it only
  appears when the game runs.
- **Tests run all ramps at once**, one tank per ramp (tanks pass through each other), with
  `--fixed-fps 60` so the full suite takes ~4 s.

## Tuning and test results

### Final tuning (`tuning/tank_tuning.tres`)
max_tread_speed 10 · max_drive_accel 5 · rolling_resistance 0.1 · traction_coeff 0.55 ·
g 9.8 · track_width 3 · turn_resistance 0.75 · tilt_smoothing 8

### Slope Ladder results (full forward, 15 s limit)

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

All targets met. Run-up times are mostly the 70 m approach (about 8 s at full speed). Full
suite: **65 of 65 checks pass** (input, views and HUD, tuning panel, air and landing levers,
course shape, flat driving, kill-plane,
slopes, sanity). Flat: 39.9 m straight in 5 s with no drift; left tread only turns right;
opposite treads spin with 0.00 m of travel. From full speed, all stop takes ~2.0 s and ~9.7 m.

### Which numbers change slope difficulty
- **Steepest slope climbable from a standstill:** about atan(`traction_coeff`); 0.55 gives
  ~29°. It also needs `max_drive_accel` ≥ g·sin(angle), which 5.0 meets up to ~30°.
- **How much a run-up helps:** `max_tread_speed`. Faster arrival = coasts further up. Steeper
  ramps slow the tank faster, so some angle always beats any run-up.
- Lowering `traction_coeff` makes every steep ramp harder at once.
- Change a value, run the tests, read the table.

### Running the tests
```
C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```
`--fixed-fps 60` runs physics as fast as possible instead of in real time (confirmed in
`--help`). Exit code 0 = all passed. The report is saved to `tests/last_results.txt` (not
committed). To watch: open `tests/test_runner.tscn` and press F6.

## Known issues and limits
- **Gamepad untested on real hardware.** Checked only with simulated stick and button events.
- **The tank is round to walls.** Its collision shape is a sphere of radius 1.7, so walls and
  ramp sides see a round tank; corners of the hull can poke into things.
- **No sideways sliding** on slopes that lean left or right.
- **Treads spin against walls:** hitting a wall stops the tank, but the treads keep their speed.
- **Course only visible when running**, not in the editor viewport.
- **Chase camera** updates in physics frames; it may look juddery on a high-refresh screen
  (possible fix: physics interpolation). It can also end up inside ramps or walls when the tank
  backs into them (not checked).
- **Launching off a crest:** air gravity, nose dip and landing speed loss exist (all off by
  default); camera shake and a hull bounce on landing are not built yet.
- **Exporting:** add `levels/*.txt` to the export's "non-resource files" filter, or the ramp
  list won't be found in an exported build.
- The run-up test has a 15 s limit and the 40° run-up takes 11.2 s; much slower tuning could
  make run-up tests time out rather than truly fail.

## Feel things to check by hand
- **Speeding up and top speed** (10 m/s): does full speed feel right on the start field?
- **All stop glide:** ~2 s and ~10 m from full speed (already confirmed as feeling right).
- **Turning:** spin in place (~95°/s at full) and one-tread turns. Heavy enough?
- **Tread levels vs hold-to-drive:** which is better for the driver station?
- **Holding on slopes:** stops and holds on 20–25°, slides back on 30° and steeper.
- **Run-ups:** do 30–40° feel like an achievement with a run-up and hopeless without?
- **"No ledge" crests:** the launch and landing at speed.
- **Hull tilt:** smooth or floaty on ramps and the bumps (`tilt_smoothing`).
- **Slit view:** slit height, readability, and how the view tips on slopes.
- **Chase camera:** distance, height and smoothing (on the `ChaseCamera` node).

## Ideas for later (from play-testing)
- Tweak how hard the slopes are to climb (see "Which numbers change slope difficulty").
- Improve the feel of launching off a "no ledge" crest: hang time, nose dipping in the air, a
  landing thump or camera shake.

## Milestone log (all 2026-10-21)
1. **Skeleton:** project, folders, `.gitignore`, flat ground, placeholder tank, chase camera.
2. **Input stations:** `DriverStation`, keyboard and gamepad sources, Input Map, reset.
3. **Movement model:** tread dynamics, turning, hull tilt, airborne fall, `TankTuning`.
   Ground-press fix for floor flicker; turn resistance 0.4 → 0.75.
   Extra: keyboard tread levels −3 to +3 and Space = all stop (developer's idea).
4. **Slope Ladder course:** ramps from a text file (with and without ledges), rolling bumps,
   walls, kill-plane.
5. **Tests:** 42 checks in ~4 s; all targets met with the starting tuning.
6. **Driver slit camera + HUD:** slit view on the hull, V to switch, F3 debug display; 50 checks.
   Both views checked by eye in screenshots from a windowed run.
7. **Docs:** README.md and this file.
8. **Tuning panel** (after the plan): Tab panel with live sliders, Copy values, Reset to saved,
   reset point (ramp + distance), and three new air/landing levers. 65 checks pass.
9. **Engine power** (developer's request): `power_falloff_start` and `power_at_top_speed` in
   `TankTuning` (group "Engine power", also in the Tab panel). Full push up to the falloff
   speed, then fading in a straight line to the "at top speed" fraction. Only limits speeding
   up, never braking; slow climbing below the falloff speed is unchanged. Defaults (1, 1) = no
   fade. Time from rest on flat (top speed 10 m/s, max_drive_accel 5):

   | falloff start | at top speed | 0→5 m/s | 0→9 m/s | 0→9.5 m/s | 0→9.9 m/s |
   |---|---|---|---|---|---|
   | 1.0 | 1.0 (off) | 1.0 s | 1.9 s | 2.0 s | 2.0 s |
   | 0.5 | 0.5 | 1.0 s | 2.1 s | 2.3 s | 2.4 s |
   | 0.5 | 0.3 | 1.0 s | 2.2 s | 2.5 s | 2.7 s |
   | 0.3 | 0.3 | 1.1 s | 2.5 s | 2.8 s | 3.0 s |
   | 0.3 | 0.15 | 1.1 s | 2.9 s | 3.3 s | 3.8 s |
   | 0.2 | 0.1 | 1.2 s | 3.3 s | 3.9 s | 4.6 s |

   68 checks pass (3 new: same pull from rest, slower near top speed, braking unchanged).
