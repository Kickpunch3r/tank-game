# Notes

How the project is built, what was decided and why, test results, known issues, and what to
check by hand. For how to run and play, see [README.md](README.md).

## Godot
- Version: **4.6.3 stable** (`4.6.3.stable.official.7d41c59c4`).
- Editor: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe`
- Console (headless checks and tests): `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe`
- Renderer: Forward+ on Direct3D 12 (Intel HD Graphics 520 on this laptop). Physics: Jolt
  (60 Hz tick).

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
  (1 − `turn_resistance`) ÷ `weight`. Left tread only turns right.
- `max_drive_accel` = `pulling_power` ÷ `weight`, `traction_coeff` = tan(`grip`), and
  `max_tread_speed` = `top_speed` (see "Feel knobs" below).
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
  Built in code: the tank rows come from `TankTuning.panel_settings()` (feel knobs first, then
  Advanced), the camera/slit/level/terrain rows from `_define_settings()`; add a line there to
  expose a new value. `rebuild()` builds it again from the current values (after a preset switch).
- **Changes are session-only** (developer's choice, over saving into the .tres). "Copy values"
  gives the numbers as text, grouped by the file or node they belong in.
- Sliders and buttons have no keyboard focus, so arrows and Space keep driving. Sliders have
  `scrollable = false`, so the mouse wheel scrolls the panel instead of changing values
  (checked in a real window: before, a wheel tick changed 10 → 9.5; now the value stays and the
  panel scrolls).
- Each setting also has a typing box (`LineEdit`): Enter, clicking elsewhere or Tab applies it.
  Typed values are exact (not rounded to slider steps) but clamped to the slider's range;
  non-numbers are ignored. While a box has focus it takes the keys, so driving keys don't
  reach the tank. Tab is caught in `_input` (before the boxes), so it always closes the panel.
  In hold-to-drive mode the keyboard source polls `Input` directly, so held keys could still
  drive while typing (levels mode, the default, is safe).
- Headless runs have a 64 × 64 px window, so the wheel test only truly runs in a window (F6);
  headless it checks the `scrollable` setting instead.
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

### Terrain (added 2026-10-21, level plan step 1)
- `TerrainType` (`scripts/terrain_type.gd`, files in `terrain/`): `grip` (× traction_coeff),
  `drag` (m/s² added to rolling resistance), `top_speed` (× max_tread_speed), `sink_depth`
  (hull picture only), `colour`. No terrain = ordinary firm ground.
- `TerrainPatch` (`scripts/terrain_patch.gd`, **tool script**, so it shows in the editor): a
  rectangle of terrain; can be moved, turned and tilted. Counts as "on" the patch from 1 m below
  to 3 m above its surface. Patches shouldn't overlap (the first one found wins).
- **Each tread looks up the terrain under itself** (`TerrainPatch.terrain_at`), so one tread in
  mud drags that side and the tank pulls toward the mud.
- Ramp lists take an optional terrain name: `20  no ledge  mud` loads `terrain/mud.tres`, colours
  the ramp, and lays patches along the slope and ledge. `levels/terrain_ramps.txt` is a second
  `SlopeLadder` (`TerrainRamps`, at x −100) with sand 10–25° and mud 10–20°.
- Course: `MudPatch` (x −25, z 35) and `SandPatch` (x 25, z 35), 24 × 24 m, behind the start.
- Tab panel: a "Terrain: Mud" and "Terrain: Sand" section; reset point list includes the
  terrain ramps.
- Starting values. Mud: grip 0.7, drag 1.5, top speed 0.5, sink 0.3 (first tried grip 0.6,
  drag 3, but drag nearly matched the grip limit, so the tank crawled even on flat mud).
  Sand: grip 0.75, drag 1.0, top speed 0.8, sink 0.1.
- Results (headless): top speed firm 10 / sand 8 / mud 5 m/s. From 4 m/s, stops in 0.78 s on
  firm vs 0.75 s in mud (mud braking is limited by its low grip). One tread in mud: 14.8° pull
  in 1.5 s. Terrain ramps, standing / run-up: sand 10° and 15° climb / climb, sand 20° and 25°
  fail / climb; mud 10° climbs / climbs, mud 15° fails / climbs, mud 20° fails / fails.
- Ice, road, shallow water: planned as mostly visual for now (not built).
- Placeholder colours: mud is very dark under the lighting, and sand is close to the ground
  colour.

### Feel knobs and presets (branch `kinematic-tuning`, from KINEMATIC_TUNING_PLAN.md)
Decisions, alternatives and reasons: [docs/kinematic_tuning_design.md](docs/kinematic_tuning_design.md).
- `TankTuning` starts with six **feel knobs**, the same names and meanings as the physics tank's;
  everything else is in "Advanced (do not usually touch)", unchanged.

  | Knob | Default | How the kinematic tank uses it |
  |---|---|---|
  | `weight` | 1 | Divides the push and brake, idle drag, turn rate and tilt smoothing |
  | `top_speed` | 10 m/s | Each tread's top speed (was `max_tread_speed`) |
  | `pulling_power` | 5 | Push = pulling_power ÷ weight (was `max_drive_accel`); also the brake |
  | `grip` | 28.8108° | Push capped at tan(grip) × g × cos(slope) (tan = the old `traction_coeff` 0.55) |
  | `sideways_grip` | 1 | Slide in turns: 1 = none; lower = longer drift |
  | `tippiness` | 0 | Hull picture rocks on its suspension (looks only) |

- **Derived and fixed values** (all give today's numbers at the defaults):
  - Push and brake = `pulling_power / weight`. Idle drag = `idle_drag / weight` (heavier coasts
    further). Turn = × `(1 − turn_resistance) / weight`. Tilt smoothing = `tilt_smoothing / weight`.
  - Rolling resistance, gravity, track width, turn scrub: fixed (advanced).
  - Slide fade rate = 0.3 + `slide_decay_scale` (3) × s / (1 − s), s = `sideways_grip`
    (`TankFeel.slide_decay_rate`, shared with the physics tank). 1 → no slide at all.
  - Sway: target angle = tippiness × `sway_degrees_per_accel` (1.5°) per m/s² of speeding up,
    braking or turning (speed × turn rate), max 12°, followed by a slightly bouncy spring
    (`HullSway` on `Visual/Hull/Sway`, which holds the meshes; the slit camera is outside it).
- **Old names still work in code**: `max_tread_speed`, `max_drive_accel` and `traction_coeff`
  read and write the knobs they came from.
- **Presets** (`TankFeel`, six knobs only): `tuning/presets/heavy.tres`, `nimble.tres`,
  `slippery.tres`. Keys 1/2/3 (`PresetSwitcher` in the player rig) set them on the tank in memory
  and rebuild the Tab panel. The HUD names the preset whose six values match the tank's.
- **Grip is "steepest slope it can hold / climb from a standstill"**, not "ever": a run-up still
  carries the tank about 10° past its grip (the approved targets need that). The plan said
  "whatever the momentum"; see the design doc (needs your OK).
- **Default parity** (checked by a test against main's table): every slope result, flat
  driving 39.9 m in 5 s, brake 1.97 s, idle stop 3.23 s, spin 40°/s, pivot 25°/s are unchanged.
  The whole test report is identical to main's apart from the new sections.
- Grip limit (pulling power 20 so the engine isn't the limit), steepest ramp climbed:
  grip 25° → 20° standing / 35° run-up; 35° → 30° / 45°; 45° → 40° / 55°.
- Weight 2: 0 → 9.5 m/s in 3.97 s (1.95 s at weight 1); coasts 28.2 m after letting go (14.6 m).
- Sideways grip 0.3, hard turn at 10 m/s: slides up to 0.73 m/s outward (0 at sideways grip 1).
- Slope ladder per preset (standing start / run-up, seconds to the top or how far up it got):

  | Ramp | Saved tuning | Heavy | Nimble | Slippery |
  |---|---|---|---|---|
  | 5° ledge | 3.2 / 10.0 | 3.8 / 12.3 | 2.8 / 8.5 | 4.2 / 10.6 |
  | 10° no ledge | 3.5 / 10.0 | 4.2 / 12.3 | 3.0 / 8.5 | 5.3 / 10.6 |
  | 15° ledge | 4.0 / 10.0 | 5.2 / 12.3 | 3.4 / 8.5 | 8.6 / 10.6 |
  | 20° no ledge | 4.8 / 10.0 | 7.7 / 12.3 | 4.0 / 8.5 | fail 2% / 10.7 |
  | 25° ledge | 7.0 / 10.0 | fail 4% / 12.4 | 5.1 / 8.5 | fail 2% / 11.0 |
  | 30° no ledge | fail 4% / 10.1 | fail 3% / 12.9 | 9.4 / 8.5 | fail 2% / 11.7 |
  | 35° ledge | fail 3% / 10.4 | fail 3% / fail 93% | fail 4% / 8.6 | fail 2% / fail 80% |
  | 40° no ledge | fail 4% / 11.2 | fail 3% / fail 67% | fail 4% / 8.8 | fail 3% / fail 63% |
  | 45° ledge | fail 3% / fail 78% | fail 4% / fail 53% | fail 5% / 9.1 | fail 2% / fail 52% |
  | 55° no ledge | fail 5% / fail 49% | fail 5% / fail 33% | fail 6% / fail 78% | fail 4% / fail 39% |

  Heavy fails 25° standing because its push (4 m/s²) only climbs 24°; Nimble's 12 m/s top
  speed carries it up 45° with a run-up.

### Physics tank (branch `physics-tank`, from PHYSICS_COMPARISON_PLAN.md)
Decisions, alternatives and reasons: [docs/physics_tank_design.md](docs/physics_tank_design.md).
- `PhysicsTank` (`scripts/physics_tank.gd`, `scenes/physics_tank.tscn`, blue-grey hull): a
  `RigidBody3D` with a box collider (sloped nose and tail) riding on **8 spring probes**
  (`RayCast3D`, 4 per tread, made by the script). Each grounded probe pushes the hull up at its
  own place (spring + damper), pushes it along (its share of its tread's drive) and holds it
  against sliding sideways; drive + sideways together are capped at tan(grip) × how hard that
  probe is pressed. Treads brake / idle / drive like the kinematic tank's.
- **Physics engine: Jolt** (as before). **Tick: 60 Hz**, unchanged (no jitter seen).
- `PhysicsTankTuning` (`tuning/physics_tank_tuning.tres`): the same six knobs, then Advanced.
  **Derived, not set:**
  - mass = `weight` × `base_mass` (30 000 kg); push = `pulling_power / weight` (as kinematic)
  - spring stiffness = (mass × g ÷ 8) ÷ (`target_sag` 0.15 × `spring_length` 1 m): each spring
    sinks 15% under its share of the weight
  - spring damping = `damping_ratio` (0.45) × 2 × √(stiffness × mass ÷ 8)
  - sideways hold rate = the kinematic slide fade rate for the same `sideways_grip`, capped at
    `max_sideways_rate` (6/s). This is also what makes turning heavy (the treads' ends are
    dragged sideways in a turn).
  - centre of mass height = 0.2 m + `tippiness` × 2 m (default tippiness 0.3 → 0.8 m)
  - Fixed: probe layout (±1.5 m, ±1.875 / ±0.625 m), spring length 1 m, throttle response 5/s,
    rolling resistance 0.1, idle drag 3, damping linear 0 / angular 0.1 (replacing Godot's
    project damping, which otherwise adds 0.1 and cost 0.25 m/s of top speed).
- **Two tanks, T to swap:** both are in `scenes/player_rig.tscn`; `PlayerRig` (root script)
  keeps `active_tank`. The hidden tank is switched off (`process_mode` disabled: no input, out of
  the physics world, not drawn). Each tank has its own `DriverStation`; on a swap the keyboard
  levels carry over. Camera, slit view, HUD and Tab panel follow; works in levels too.
- **Shared interface** (both tanks): `driver_station`, `tuning`, `bumped`, `place_at()`,
  `reset_to_spawn()`, `set/get_spawn()`, `set/get_home()`, `standing_start_distance()`,
  `display_name()`, `debug_lines()`. The HUD shows each tank's own lines plus shared ones.
- Chase camera: smooths its look point up and down (`look_smoothing` 6; 0 = off) so spring
  bounce doesn't tip the view. Never rolls (as before). The slit camera tilts with the hull.
- HUD (physics): tread speeds and grip ok/SATURATED per tread, hull pitch and roll, and a probe
  diagram: `#  15%` = touching, spring squashed 15%; `.  ---` = in the air.
- Course additions (`ComparisonFeatures` node in the test course at x 100, z 90, built in code):
  ledge strip (1.2 m platform beside a drop), steps 0.2 / 0.4 / 0.6 m, 15° crest. In the Tab
  panel's reset-point list.

#### Controls: differences from the original plan
The physics tank uses exactly the kinematic tank's current controls (it reads its own
`DriverStation` with the same sources). These differ from `PHYSICS_COMPARISON_PLAN.md` 2a:

| Action | Keyboard | Phone | Notes |
|---|---|---|---|
| Left tread | `W` / `S` step a level | Left lever (7 notches) | Levels stay where left (not hold-to-drive) |
| Right tread | `Up` / `Down` step a level | Right lever | |
| Levels | 3 forward, 3 back: 0.25, 0.5, 1 | Same | Defined once in `scripts/tread_levels.gd` |
| Brake (hold) | `Space` (action still called `driver_all_stop`) | BRAKE button | Not in the plan; brake wins over everything |
| Reset | `R` | | Resets whichever tank is active |
| Camera view | `V` | | |
| Debug display | `F3` | | |
| Tuning panel | `Tab` | | Not in the plan |
| Full screen | `F11` | | Not in the plan |
| Swap tank | `T` | | New (was free) |
| Presets | `1` / `2` / `3` | | New (were free) |

- Level 0 is idling (idle drag), not braking, in both tanks. The phone watchdog brakes for 3 s.
- Gamepad sticks still work for both tanks; no gamepad brake (developer won't use one).

#### Results side by side (slope ladder, full forward, 15 s limit)
| Ramp | Kinematic standing | Kinematic run-up | Physics standing | Physics run-up |
|---|---|---|---|---|
| 5° ledge | 3.2 s | 10.0 s | 3.5 s | 10.2 s |
| 10° no ledge | 3.5 s | 10.0 s | 3.7 s | 10.2 s |
| 15° ledge | 4.0 s | 10.0 s | 4.0 s | 10.2 s |
| 20° no ledge | 4.8 s | 10.0 s | 4.8 s | 10.3 s |
| 25° ledge | 7.0 s | 10.0 s | 6.6 s | 10.6 s |
| 30° no ledge | fails (4%) | 10.1 s | fails (44%) | 11.3 s |
| 35° ledge | fails (3%) | 10.4 s | fails (23%) | fails (70%) |
| 40° no ledge | fails (4%) | 11.2 s | fails (17%) | fails (41%) |
| 45° ledge | fails (3%) | fails (78%) | fails (12%) | fails (28%) |
| 55° no ledge | fails (5%) | fails (49%) | fails (7%) | fails (13%) |

Physics: 3 runs each, majority (all agreed). Flat: straight 38.2 m in 5 s (kinematic 39.9);
spin 44°/s (40); one-tread pivot 34°/s (25). Rest: settles in under 2 s at 15% squash.
Ledge, middle 0.5 m inside the edge: leans 12° standing, up to 22.5° driving along; any
further out it tips off. The physics run-up loses ~4 m/s lifting its nose onto 35°–40° ramps,
so they fail; see the design doc.

#### How to compare (by hand)
1. Climb the 30° ramp from a standstill and with a run-up, in each tank (Tab, Reset point).
2. Drive along the ledge strip with one tread over the edge.
3. Spin on the spot on a slope.
4. Drive over the steps and the crest.
5. Try each preset (1/2/3) in each tank.
6. Note what feels better: hull rocking, nose lifting onto slopes, ledges, turning weight.

### Phone controller (branch `phone-controller`, from PHONE_CONTROLLER_PLAN.md)
- `ControllerServer` (`scripts/net/controller_server.gd`, a node in `scenes/player_rig.tscn`, so
  every level has it): HTTP server on 8080 (`ControllerHttpServer`, serves only
  `web/controller.html` at `/`, 404 otherwise, fills `{{WEBSOCKET_PORT}}` into the page) and a
  WebSocket server on 8081 (`TCPServer` + `WebSocketPeer.accept_stream`), polled every frame.
  Ports and bind address are exported. Chosen over an autoload so it lives with the player rig.
- Protocol as in the plan: `hello`/`welcome`, `in` (l, r clamped to -1..1, must be numbers),
  `buzz`. Bad messages are ignored, read with `JSON.new().parse()` (quiet; `JSON.parse_string`
  logged an error for each bad message).
- `StationRegistry`: station name -> phone. First phone to ask gets "driver"; later phones wait
  as spectators and the first waiting one is promoted (and told) when the driver leaves. Adding
  a gunner/engineer = more names in `STATIONS`.
- **Merging:** new `DriverInputSource.takes_over()`. `PhoneDriverInput` takes over while the
  driver phone has sent input in the last 0.25 s; while any source takes over, the station only
  listens to those (otherwise "hardest push wins" as before). Reset still comes from any source.
- **Watchdog:** `watchdog_seconds` = 0.25, measured in game time (frame deltas) so headless tests
  behave like real play. After it, the phone reports 0 and stops taking over.
- The tank's new `bumped` signal (first frame of driving into a wall at > 1 m/s) buzzes the
  driver phone for 40 ms. Tank movement code is otherwise unchanged.
- URL shown bottom-left (`PhoneStatusLabel`) and in the F3 HUD (URL, phones connected, driver,
  time since last message, latest values, live/watchdog). Addresses from `IP.get_local_addresses()`
  minus IPv6, 127.x and 169.254.x.
- Page (`web/controller.html`): Pointer Events with pointer capture, one finger per lever;
  dead zone ±0.05; spring return default, "stay where left" setting (localStorage); sends on
  change up to ~30/s and a heartbeat every 150 ms; reconnects every 1 s and resets levers to 0;
  vibration on zero crossing and buzz; wake lock only works on HTTPS, so a tip is shown instead.
- **Tests** bind to 127.0.0.1 on ports 18080/18081 (`ControllerServer.*_override`), so test runs
  never trigger a firewall prompt and can't collide with a running game or an open controller
  page (found when a browser tab left open on the page grabbed the driver role from a test).
- **Checked in a browser** (built-in browser pane, phone-sized, against the running game): both
  levers at once (L 1.00, R -0.63 reached the station), spring return, stay mode, a silenced
  phone (watchdog stopped the tank), page reload (new driver, levers at 0). **Not tested on a real
  phone** (touch feel, vibration, Wi-Fi, firewall).
- **QR code skipped:** no addon-free way short of writing a QR encoder; the URL is shown as text.
- **Exporting later:** add `web/*` to the export's non-resource filter.
- The plan's milestones 1 and 2 were committed together (server and protocol share a script).

### Painted levels (level plan step 2a, height only)
- `LevelTerrain` (`scripts/level_terrain.gd`, **tool script**): builds ground from a greyscale
  PNG. Settings: `height_image_path`, `metres_per_pixel`, `max_height`, `smoothing` (3 × 3 blur
  passes), plus an Inspector **Rebuild** button (`@export_tool_button`, confirmed in 4.6.3).
  Rebuilds itself in the editor when the PNG's save time changes (checked every second), and
  0.4 s after the last setting change (so dragging a slider doesn't rebuild every frame).
  Generated nodes have no owner, so nothing is saved into the scene.
- **The PNG is read raw** (`Image.load_from_file`), not through Godot's import, which may compress
  it. Export later: add `levels/` images to the export's non-resource filter.
- **16-bit PNGs:** confirmed (headless test, 2026-10-21) that Godot 4.6.3 loads them as 8-bit:
  a stored 25728 came back as 25700. So heights have 256 steps; smoothing hides them. A small
  hand-written 16-bit PNG reader is possible later if steps show.
- Collision: `HeightMapShape3D` (points 1 unit apart) scaled evenly by `metres_per_pixel`, with
  heights divided by the same amount. The visual mesh uses the same grid points. A 256 × 256
  rebuild takes ~0.8 s (GDScript).
- `LevelStart` (`scripts/level_start.gd`, tool script): a Marker3D with a yellow arrow in the
  editor. Only its ground position and left/right turn are used.
- `LevelRoot` (`scripts/level_root.gd`) on a level's root: when run, adds
  `scenes/player_rig.tscn` (unless the scene has a `PlayerRig`), places it at the start on the
  ground, adds a `KillPlane` 30 m below, and re-places the tank whenever the ground rebuilds.
- **Player rig** (`scenes/player_rig.tscn`): Tank, ChaseCamera, ViewSwitcher, DebugHud,
  TuningPanel. The test course now uses it too (its tank is at `PlayerRig/Tank`).
- `Tank.get_home()/set_home()`: the level's normal start (the Tab panel's "Level start").
- The Tab panel finds ramp rows (`SlopeLadder.GROUP`) and level ground (`LevelTerrain.GROUP`) by
  itself; "Level ground" settings appear when a level is running.
- Starter level `levels/starter/`: height map made by `tools/generate_starter_heightmap.gd`
  (rerunning it overwrites the PNG). Edges are painted mountains (no walls), as decided.
- Guide for making levels: `docs/making_levels.md`.

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
Feel knobs: weight 1 · top_speed 10 · pulling_power 5 · grip 28.8108° (= traction 0.55) ·
sideways_grip 1 · tippiness 0. Advanced: rolling_resistance 0.1 · idle_drag 3 · g 9.8 ·
track_width 3 · turn_resistance 0.75 · turn_scrub 2 · tilt_smoothing 8 (rest at their defaults)

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
suite: **190 of 190 checks pass** in about 70 s (input, views and HUD, tuning panel, feel knobs and presets,
tank swapping, physics tank, air and landing levers,
engine power, terrain, level builder, phone controller,
course shape, flat driving, kill-plane,
slopes, sanity). Flat: 39.9 m straight in 5 s with no drift; left tread only turns right;
opposite treads spin with 0.00 m of travel. From full speed, all stop takes ~2.0 s and ~9.7 m.

### Which numbers change slope difficulty
- **Steepest slope climbable from a standstill:** the `grip` angle (28.8°). It also needs
  `pulling_power / weight` ≥ g·sin(angle), which 5.0 meets up to ~30.7°. The F3 display shows
  both and the lower one.
- **How much a run-up helps:** `max_tread_speed`. Faster arrival = coasts further up. Steeper
  ramps slow the tank faster, so some angle always beats any run-up.
- Lowering `grip` makes every steep ramp harder at once.
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
- **No sideways sliding** on slopes that lean left or right (the `sideways_grip` slide only
  comes from turning).
- **Physics tank, untested by hand:** feel, visuals and how the probes behave on the painted
  levels' steepest parts. Its phone buzz on hitting things uses a simple "sudden loss of
  speed" rule (more than 3 m/s in one frame), not checked by hand.
- **Physics tank on the 35°–40° ramps with a run-up:** fails, where the kinematic tank climbs
  (lifting its nose onto the slope costs momentum). Possible fixes in the design doc.
- **The hidden tank stays where it was left** (switched off). Swapping puts it at the active
  tank's place, so this only matters if something looks at it.
- **One-frame turning lag:** the tank moves along the heading it had at the start of each frame,
  so in a hard turn its real motion is ~2 cm/s sideways even with no slide. Was already so.
- **Walls stall the treads:** driving into a wall slows the treads to the real speed (fixed 2026-10-21; they used to keep spinning at full speed).
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
- **Physics vs kinematic (T):** see "How to compare" under the physics tank section.
- **Physics chase camera:** is the spring bounce calm enough (`look_smoothing`)?
- **Feel knobs and presets** (1/2/3): does Heavy feel heavy, Nimble nimble, Slippery slippery?
  Is the tippiness rocking pleasant or sickening? Is the sideways slide visible enough?

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
10. **Terrain step 1:** `TerrainType` + `TerrainPatch`, per-tread terrain, mud and sand patches
    and terrain ramps on the test course, terrain in the HUD and Tab panel. 74 checks pass
    (6 new terrain checks; terrain checks compare terrains rather than fix numbers, so they
    survive tuning). Fixed a test that started driving into the new terrain ramps.
11. **Tab panel: typing and wheel:** typed exact values, wheel no longer changes values.
    83 checks pass (9 new).
12. **Level builder, height only:** `LevelTerrain`, `LevelStart`, `LevelRoot`, shared player rig,
    starter level, `docs/making_levels.md`. 92 checks pass (9 new). Found and fixed a test
    clean-up bug the rig move caused (a test tank named "Tank" was never removed).
13. **Cliff bounce fix, panel limits, full screen** (developer's bug report and requests):
    - Bug: at max height 60 and 2 m per pixel, driving at the mesa's south cliff made the tank
      bounce on the spot. Cause: on the 45° base it hit the >60° cliff (a "wall" to Godot);
      move_and_slide kept the upward part of its velocity, so it popped into the air, landed and
      pushed again, while the treads stayed at full speed. Fix (`Tank._blocked_by_wall`): when
      driving into a wall, tread speeds drop to the real speed (they stall), and hitting a wall
      in the air never keeps upward speed. Crest launches are unaffected. Regression test added.
    - Tab panel: wider slider ranges; typed values may go past the slider (it stretches); hard
      limits only where needed (fractions 0–1, no negatives for physical amounts, smoothing ≤ 50).
    - Full screen at start (`display/window/size/mode=3`), F11 toggles (`WindowControls`
      autoload, action `toggle_fullscreen`). Checked in a real window: starts 1920 × 1080
      fullscreen, F11 → windowed. Unconfirmed: whether the editor's embedded "Game" tab honours it.
    95 checks pass.
14. **Phone controller** (branch `phone-controller`): servers, protocol, station registry,
    phone input with takeover and watchdog, controller page, HUD and README. 111 checks pass
    (16 new). Browser-checked; not yet tried on a real phone.
15. **Phone over USB** (developer's choice, because Windows Firewall needs admin rights to let
    Godot onto the network on this laptop):
    - `ControllerServer.allow_wifi_phones` (default **off**): off = listen on 127.0.0.1 only, so
      Windows shouldn't ask for network access (unconfirmed until the developer runs it).
    - `UsbPhoneLink` (in the player rig): every 3 s on a background thread, finds `adb.exe`
      (Adb Path setting, then `Documents/platform-tools`, next to the project folder, or the
      Android SDK), runs `adb devices`, and for an allowed phone runs
      `adb -s <phone> reverse tcp:<port> tcp:<port>` for both server ports. The phone then opens
      `http://localhost:8080`. Status shown bottom-left and in F3. Tests use a pretend adb
      (`UsbPhoneLink.run_adb`); the real one is switched off in test runs.
    - Checked: game runs with no adb present and reports "adb not found" without errors.
      **Not tested with a real phone or real adb** (none here). Unknowns: whether the laptop lets
      adb.exe run, and whether Windows needs a USB driver for the phone (needs admin).
    - adb leaves its own background server running after the game closes (normal for adb).
    119 checks pass (8 new).
16. **Phone controller tested on a real phone over USB** by the developer (2026-10-21):
    "works great". Merged `phone-controller` into `main`.
17. **Brake, idling, levels, warm-up, turn scrub** (developer's design, 2026-10-21):
    - **Levels** 0.25 / 0.5 / 1 (and back), defined once in `TreadLevels`; the game fills them
      into the phone page (`{{TREAD_LEVELS}}`), so keyboard and phone always agree.
    - **Brake** is a separate control: `DriverStation.brake` (any source; always wins over a
      source that is taking over). Keyboard: hold Space (action still named `driver_all_stop`;
      renaming it needs project.godot with Godot closed). Phone: BRAKE button, `"b":1` in `in`
      messages. No gamepad brake (developer won't use a gamepad). Brake strength = Max Drive
      Accel (1.97 s from 10 m/s); holds the tank on slopes up to the grip limit.
    - **Level 0 = idling:** no engine push; `idle_drag` (3) slows the tread (stops from 10 m/s
      in 3.2 s). Doesn't hold slopes steeper than atan(idle_drag / g) ≈ 18°: rolled 4.6 m back
      in 3 s on 25°. First built as pure coasting, but then a lever at 0 at speed barely turned
      the tank (1° in 2 s), because that tread freewheeled; the developer's instinct (an
      unpowered tread should be dragged, making a slow pivot) led to idle drag.
    - **Watchdog now brakes** for `LOSS_BRAKE_SECONDS` (3 s) when the driver phone goes quiet or
      disconnects, since level 0 alone would let the tank roll on.
    - **Warm-up** (`warm_up_time`, default 0 = off): each tread's push builds from nothing to
      full over that time whenever more is asked for; drops at once; never delays the brake.
      0.5 s: half the speed after the first 0.5 s (1.24 vs 2.45 m/s). Correction to what was
      first said: stepping up from steady cruising warms up almost from scratch (the engine is
      barely pushing at cruise); only stepping up while still speeding up is instant.
    - **Turn scrub** (`turn_scrub`, default 2): first built as an extra drag, but the engine
      (5 m/s²) cancelled it out (0.04 m/s difference in a hard turn). Reworked: while turning,
      the treads' target speeds are divided by (1 + turn_scrub × turn rate), so the engine can't
      make it back. Straight driving and all slope results unchanged. Measured: spin on the spot
      40°/s (95 without); one-tread pivot 25°/s with the powered tread at 5.3 m/s; hard turn at
      speed (levers 1 and 0.25) 3.6 m/s after 2 s (6.2 without); one lever to 0 at full speed:
      13° in 2 s and down to 5.3 m/s.
    - Phone page: 7 evenly spaced notches per lever, snap, buzz per notch, stay where left
      (spring-back is a setting, off); BRAKE button; `setPointerCapture` failures are caught (a
      browser check with simulated touches showed an uncaught failure there stopped the brake).
    - Debug display: brake state and each tread's available engine push.
    138 checks pass.
18. **Feel knobs and presets** (branch `kinematic-tuning`, from KINEMATIC_TUNING_PLAN.md, built
    overnight by Claude working alone; decisions in `docs/kinematic_tuning_design.md`):
    six knobs in `TankTuning` (rest under Advanced), weight effects, tippiness sway
    (`Visual/Hull/Sway`), sideways slide, grip in degrees, presets on keys 1/2/3, HUD lines,
    new `FeelTests` suite. Default parity checked: identical results. 159 checks pass.
19. **Physics tank** (branch `physics-tank`, built on `kinematic-tuning`, from
    PHYSICS_COMPARISON_PLAN.md, overnight by Claude working alone; decisions in
    `docs/physics_tank_design.md`): spring-probe `RigidBody3D` tank, `PhysicsTankTuning` with the
    same six knobs, shared presets, T to swap (also in levels), ledge strip / steps / crest,
    physics HUD, new `PhysicsTankTests`. Fixed: Tab panel's Reset to saved missed the hidden
    tank. Kinematic results unchanged. 190 checks pass (~70 s).

## Ableton Push 3 controller (branch `push-controller`, from `physics-tank`, 2026-10-22)
- Developer's design: the phone's layout on the Push pads. `PushLayout` (`scripts/push/`): left
  lever columns 0–1, right lever columns 6–7, rows 0–6 = levels −3..+3 (row 3 = 0), brake square
  columns 3–4 × rows 3–4 (2 × 2; first built 4 × 4, shrunk at the developer's request), top row free. Levers two columns wide so they're easy to hit without
  looking (developer said "7 lights either side"; two columns chosen, recommended and agreed).
- `PushController` (in the player rig, like the phone's server): opens MIDI, reads only the port
  named "Ableton Push 3 MIDI" (the Push shows each press on two ports; same as the finger-walking
  game), keeps the Push's lever levels and brake. Pressing a lever pad jumps the lever there; it
  stays. Holding a brake pad brakes and sets both levers to 0.
- `PushDriverInput` on **both** tanks' DriverStations reads the controller, so T keeps the Push's
  levers. Merging as for every source: hardest push wins per tread, brake from any source.
- Safety: every second it checks the Push's port is still in `OS.get_connected_midi_inputs()`;
  if it disappeared, levers go to 0 and it brakes for 3 s. **Unconfirmed:** whether Godot's port
  list updates on Windows when the Push is unplugged while the game runs (it may only update when
  MIDI is reopened). Try unplugging it while driving slowly.
- Lights: `PushLightSender` (in the rig) builds all 64 pad colours from the **active tank's
  DriverStation** (so the keyboard and phone show on the Push too) and sends
  `{"pads": [64 x [colour, 0, 0]]}` to the relay page over a WebSocket on 127.0.0.1:9080. The page
  (`web/push_relay.html`) is a copy of the finger-walking game's `tools/push_relay.html`, one hint
  reworded. Steady colours only, so no MIDI clock is needed.
- Default colours (Inspector, Push palette numbers): notch 124 (dark grey), zero notch 123 (light
  grey), forward 32 (bright green, found in the finger-walking game), reverse 125 (blue), stopped
  122 (white), brake 127 (red), brake held 122 (white). **Not seen on the Push yet:** pick better
  ones with the relay page's palette view.
- Tests (`tests/push_tests.gd`, pretend MIDI and a pretend relay page; real MIDI is never opened
  and the light port is 19080 in tests): layout, levers, duplicate port ignored, lights (position,
  notches, reverse, brake, follows the keyboard), brake hold/release, unplug -> 3 s brake, the
  page receiving all 64 pads, and the Push driving the physics tank after T. 204 checks pass.
- **Not tested:** a real Push (pads, lights, colours, unplugging), the relay page with this game.
