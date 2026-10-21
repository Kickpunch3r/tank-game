# Tank Game (Godot) - Foundation Build Plan

You are building the first playable foundation of a tank game in Godot, on the developer's local machine. Work through the milestones in order. Make reasonable decisions without asking unless something is genuinely blocked, record decisions in `NOTES.md`, and commit after each milestone.

## 1. Vision (context only, do not build yet)

The long-term goal is a co-operative crew game played in a large physical installation: several players operate different stations of one tank (driver, gunner, engineer), using big custom controllers and separate screens or vision slits. Some players may see while others control. Think Lovers in a Dangerous Spacetime or Captain Sonar.

**This build covers only driving.** But the architecture must leave room for multiple stations, multiple input devices and multiple views. See section 4.

## 2. Goal of this build

- A tank the player steers by controlling the **left and right treads independently**.
- An environment with **slopes of increasing steepness**. The steepest slopes are **unclimbable**. Whether a mid-steep slope can be climbed depends on **momentum**: a run-up lets the tank climb slopes it cannot climb from a standstill.
- The player can see while driving (chase camera), plus a toggleable driver's vision-slit view.

## 3. Assumptions

- 3D, Godot 4.x (use the version installed on this machine; record it in `NOTES.md`), GDScript with static typing.
- Final art will be low-poly models or Doom-style sprites. For now use **primitive meshes only**, kept in separate visual child nodes so art can be swapped without touching logic.
- No addons, no downloaded assets.
- Find the Godot executable first (`godot`, `godot4`, or ask the developer for the path if neither is on PATH). Record the command used in `NOTES.md`.

## 4. Architecture

### 4.1 Input stations (critical for the future)

The tank must **never read `Input` directly**.

- `DriverStation` (script, plain class or Node): exposes `left_tread: float` and `right_tread: float`, each in [-1, 1], plus `reset_requested: bool`.
- Input sources write into a station:
  - `KeyboardDriverInput`: left tread `W`/`S`, right tread `Up`/`Down` arrows, reset `R`.
  - `GamepadDriverInput`: left stick Y = left tread, right stick Y = right tread, with a deadzone.
  - Define all keys and buttons in the Input Map in `project.godot` so they are remappable.
- The tank reads only from its `DriverStation`. Later stations (`GunnerStation`, etc.) and custom hardware inputs (MIDI, serial, giant levers) will plug in the same way.
- Document this pattern briefly in `NOTES.md`.

### 4.2 Movement model: kinematic, rules-based (NOT rigid-body physics)

Use `CharacterBody3D` for the tank. Do not use `RigidBody3D` or simulated suspension.

Per physics frame:

1. **Tread speeds.** Each tread has a current speed. Target speed = `tread_input * max_tread_speed`.
2. **Ground info.** Get the floor normal (from `is_on_floor()` / `get_floor_normal()`, or a downward raycast near the hull centre). Compute the slope angle along the tank's forward direction (signed: positive when nose-up).
3. **Longitudinal dynamics, per tread** (this is where momentum and slopes come from):
   - `drive_accel` toward the target speed, capped at `max_drive_accel`.
   - Traction cap: `|drive_accel| <= traction_coeff * g * cos(slope)`.
   - Gravity along slope: subtract `g * sin(slope)` (positive slope slows forward motion; it also makes a stationary tank roll back down when traction is exceeded).
   - Rolling resistance: small decay toward zero speed.
   - Integrate: `tread_speed += net_accel * delta`.
4. **Combine treads.**
   - Forward speed = `(left + right) / 2`.
   - Yaw rate = `(right - left) / track_width` (sign chosen so that left-only drive turns right).
   - Apply a `turn_resistance` factor so spinning in place feels heavy.
5. **Move.** Rotate the body by the yaw rate, set velocity = forward vector projected onto the ground plane times forward speed, plus gravity when airborne. Call `move_and_slide()`. Set `floor_max_angle` high enough (around 60 degrees) that the custom slope rules, not Godot's floor limit, decide what is climbable.
6. **Visual tilt.** Smoothly align a child `Hull` visual node (not the collision body) to the ground normal so the tank pitches and rolls on slopes.
7. **Airborne.** If not on the floor, apply gravity, keep horizontal momentum, and do not apply drive.

All tunables go in one `TankTuning` Resource (`tank_tuning.tres`): `max_tread_speed`, `max_drive_accel`, `traction_coeff`, `g`, `rolling_resistance`, `track_width`, `turn_resistance`, `tilt_smoothing`. Code comments should explain each in plain language, because the developer will tune these by hand.

**Why this produces the desired slopes:** a tank can hold a slope only if its traction-capped drive beats `g * sin(slope)`. Since traction falls with `cos(slope)`, there is a critical angle above which it always loses (`tan(slope) > traction_coeff`). Below that, a tank arriving fast carries speed up the ramp before gravity slows it, so a run-up extends how far it gets.

### 4.3 Cameras and views

- `ChaseCamera`: third-person, smoothed follow, stays level (no roll).
- `DriverSlitCamera`: mounted at the front of the hull, first-person, rendered with a narrow letterbox mask (a horizontal slit overlay) to suggest looking out of a vision slot.
- `V` toggles between them. Keep each camera self-contained so later each can render to its own `SubViewport` or screen.

## 5. Test environment: the Slope Ladder

`scenes/test_course.tscn` (set as the main scene):

- A flat start area with a long flat **run-up strip** (at least 60 m) leading to the ramps.
- A row of ramps at **5, 10, 15, 20, 25, 30, 35, 40, 45, 55 degrees**, each 20 m long along the slope, with a flat landing on top. Distinct colour per ramp and a `Label3D` with its angle.
- Ramps built from `StaticBody3D` with simple box or convex collision so the angles are exact.
- A second area of gentle rolling bumps for free driving.
- Boundary walls, and a kill-plane that respawns the tank at the start.

## 6. Debug HUD

`CanvasLayer`, toggled with `F3`: forward speed, left and right tread input and tread speed, on-floor state, current slope angle, and whether traction is capped this frame.

## 7. Milestones (commit after each)

1. **Skeleton:** project, folders (`scenes/`, `scripts/`, `tests/`, `docs/`), `.gitignore` for Godot 4 (ignore `.godot/`), flat ground, placeholder tank, chase camera. Runs without errors.
2. **Input stations:** `DriverStation`, keyboard and gamepad inputs, Input Map, reset.
3. **Movement model:** tread dynamics, turning, ground alignment, tilt visual, airborne handling.
4. **Slope Ladder** course.
5. **Tests:** see section 8. Tune `TankTuning` until the targets hold.
6. **Driver slit camera + HUD.**
7. **Docs:** `README.md` and final `NOTES.md`.

## 8. Verification

Create a headless test runner, for example:

```
<godot> --headless --path . res://tests/test_runner.tscn
```

It must print a results table and exit non-zero on failure. Tests drive the tank by writing into its `DriverStation` directly, not via simulated keypresses.

- **Flat:** both treads forward for 5 s moves roughly straight; left-only turns right; opposite treads rotate in place with little translation.
- **Standing start:** for each ramp, start at the base from rest, full forward for up to 15 s. Did it reach the top?
- **Run-up:** same, starting from the far end of the run-up strip.
- **Sanity:** no NaNs, no falling through the ground.

Targets (tune to meet them, record the final results in `NOTES.md`):

| Angle | Standing start | With run-up |
|---|---|---|
| 5 to 15 deg | climbs | climbs |
| 20 to 25 deg | climbs, slowly | climbs |
| 30 to 35 deg | fails | climbs |
| 40 deg | fails | either is fine, note which |
| 45 and 55 deg | fails | **fails** |

If a target cannot be met sensibly, keep the ordering correct (steeper is never easier) and explain in `NOTES.md`.

## 9. Working rules

- Small, typed scripts. One responsibility per script.
- Do not delete files you did not create. Do not force-push or rewrite history.
- If something takes far longer than expected, choose the simpler option, note it, and move on.

## 10. Deliverables

- Project opens in Godot and runs the test course.
- `README.md`: how to run, controls, how to run tests.
- `NOTES.md`: Godot version and command, architecture notes (stations, movement model, cameras), final tuning values, test results, known issues, and a "feel things to check by hand" list for the developer.
