# Physics Tank Comparison - Build Plan

Build a second, physics-based tank alongside the existing kinematic tank, so the developer can drive both on the same course and choose by feel. Do this after the milestones in `TANK_PLAN.md` are complete. Work on a branch `physics-tank`, commit after each milestone, and record decisions in `NOTES.md`.

**Do not modify or delete the kinematic tank.** Both tanks must keep working.

## 1. Why

The kinematic tank samples the ground at roughly one point, so it cannot lurch when one tread drops off a ledge, and it snaps between slope angles instead of easing onto an incline. The physics tank should get these behaviours naturally:

- one tread dropping off a ledge makes the tank tilt, teeter or fall
- the nose rides up onto an incline and the hull settles gradually
- momentum carries the tank up slopes; the steepest stay unclimbable
- bumps and collisions behave plausibly

The developer finds many tuning variables hard to manage, so **simplicity of tuning is a hard requirement** (section 4).

## 2. Shared pieces (reuse, do not duplicate)

- `DriverStation` and all input sources (keyboard, gamepad, phone if built). The physics tank reads only from `DriverStation`, exactly like the kinematic tank.
- Cameras, test course, debug HUD and test runner.

## 2a. Controls (must match the kinematic tank exactly)

The physics tank must be driven with **exactly the same controls** as the kinematic tank, so swapping tanks never changes what the player's hands do. The physics tank gets these automatically by reading `DriverStation`; do not add any tank-specific input code.

Controls as originally specified in `TANK_PLAN.md`:

| Action | Keyboard | Gamepad | Phone (if built) |
|---|---|---|---|
| Left tread forward / back | `W` / `S` | Left stick Y | Left lever |
| Right tread forward / back | `Up` / `Down` | Right stick Y | Right lever |
| Reset tank to start | `R` | (as currently mapped) | - |
| Toggle chase / driver slit camera | `V` | (as currently mapped) | - |
| Toggle debug HUD | `F3` | - | - |

Behaviour that must also carry over:

- Tread inputs are each in [-1, 1]; left only turns right, opposite treads spin in place.
- Same gamepad deadzone and throttle smoothing feel as the kinematic tank (use the same input-side values; do not create separate ones).
- Reset (`R`) respawns whichever tank is active, at rest.
- Input merging and the phone watchdog (if built) work the same for both tanks.

New keys added by this plan:

| Action | Key |
|---|---|
| Swap kinematic / physics tank | `T` |
| Presets heavy / nimble / slippery | `1` / `2` / `3` |

**Before starting, check the actual project:** read the current Input Map in `project.godot`, the README and `NOTES.md`. The controls may have changed during development. If anything differs from the table above, **the current project is the source of truth**: match it, and list every difference in `NOTES.md` under "Controls: differences from original plan" so the developer can confirm them. Also confirm `T`, `1`, `2` and `3` are not already used; if they are, pick free keys and note them.

Add a controls test: for both tanks, the same `DriverStation` input (left only, right only, both forward, opposite) produces the same direction of movement and turning.

## 3. Physics tank design

- `RigidBody3D` hull with a simple box collider. Wheels/treads have no colliders of their own.
- **Contact points:** 4 `RayCast3D` probes per tread (8 total), evenly spaced along each tread, pointing down. Each acts as a spring-damper pushing the hull up at its own position. This per-point contact is what produces tipping when one side loses ground.
- **Drive:** each tread's throttle comes from `DriverStation`. For each grounded probe, apply a share of that tread's drive force along the hull's forward direction projected onto that probe's ground plane, at the probe position.
- **Grip:** each probe's forward drive force and sideways friction force are capped by `grip * spring_force_at_that_probe`. Less weight on a probe means less grip, so steep slopes and lifted treads lose traction naturally.
- **Sideways slide:** each grounded probe applies a force opposing sideways velocity at its position, scaled by `sideways_grip`, within the grip cap.
- **Top speed:** drive force fades to zero as forward speed approaches `top_speed`.
- **Physics rate:** if the tank jitters, raise the physics tick rate (e.g. 120 Hz) before adding more parameters. Note which physics engine the project uses (Godot Physics or Jolt) in `NOTES.md`; try the other only if stability problems persist.

## 4. Tuning: six feel knobs, everything else derived

Create `PhysicsTankTuning` (a `Resource`). The **only values the developer is expected to edit** are these six, each with a plain-language comment and a sensible range:

| Knob | Meaning |
|---|---|
| `weight` | How heavy the tank feels (mass). |
| `top_speed` | Maximum forward speed. |
| `pulling_power` | How hard the treads push; affects acceleration and climbing. |
| `grip` | The steepest slope the treads can hold, **in degrees** (e.g. 35). Converted internally with `tan(angle)`. Same meaning as in the kinematic tank (`KINEMATIC_TUNING_PLAN.md`). |
| `sideways_grip` | How much the tank resists sliding sideways when turning. |
| `tippiness` | How easily it tips; controls centre-of-mass height (0 = very low and stable, 1 = high and tippy). |

Everything else is either **derived in code** or **fixed once** and placed in a clearly separate "Advanced, do not usually touch" section:

- **Spring stiffness:** derived from `weight` and a fixed target sag (how far the hull sinks at rest, e.g. 15 percent of spring length).
- **Spring damping:** derived from stiffness and weight as a fixed fraction of critical damping (start around 0.3 to 0.5) so the tank settles without bouncing.
- **Probe layout, spring rest length, max travel:** fixed to match the hull shape.
- **Throttle response, rolling resistance, linear and angular damping:** fixed values chosen during development.

Explain the derivations briefly in `NOTES.md`.

### Presets

Ship three saved presets as `.tres` files: `heavy.tres`, `nimble.tres`, `slippery.tres`. Add a key (e.g. `1`/`2`/`3`) to switch preset live while driving.

## 5. Switching between tanks

- Press `T` to swap between the kinematic and physics tank. The new tank appears at the current tank's position and heading, starting at rest. The other tank is hidden and disabled.
- Cameras and HUD follow whichever tank is active. The HUD shows which tank and which preset are active.
- Both cameras should stay level on roll and damp pitch movement, to reduce motion sickness and keep the comparison fair.

## 6. Course additions

Add to the test course, without breaking the existing slope ladder:

- **Ledge strip:** a raised platform beside a drop, so the tank can drive along it with one tread over the edge.
- **Step-ups and step-downs:** low steps of increasing height (e.g. 0.2 m, 0.4 m, 0.6 m).
- **A crest:** a ramp that tips over into a downslope, to show weight transfer.

## 7. HUD additions

For the physics tank: grounded state of each of the 8 probes (a simple diagram is ideal), compression of each spring, hull pitch and roll, whether grip is saturated on each tread.

## 8. Milestones (commit after each)

1. **Physics tank on flat ground:** hull, probes, springs, derived stiffness and damping. Sits stably at rest, no jitter.
2. **Drive and grip:** tread forces, sideways grip, top speed. Drives, turns, spins in place.
3. **Tuning resource + presets + tank switching.**
4. **Course additions.**
5. **Tests and tuning** (section 9).
6. **HUD + docs.**

If a milestone stalls for a long time on stability, take the simplest stable option, note it, and move on.

## 9. Verification

Add to the existing test runner. Physics is less exactly repeatable than the kinematic model, so use tolerances, and run each slope test 3 times and report the majority result.

- **Rest:** placed on flat ground, the tank settles within 2 seconds and stays still (no drift or jitter beyond a small tolerance).
- **Flat drive:** same as the kinematic tests (straight, turn, spin in place).
- **Slopes:** standing start and run-up on every ramp. Same targets as `TANK_PLAN.md`: 45 and 55 degrees must always fail; steeper must never be easier.
- **Ledge:** driving along the ledge strip with one tread over the edge produces a measurable roll angle and does not cause NaNs or the tank falling through the world.
- **Stability:** no NaNs; the tank does not flip on flat ground or gentle bumps at full speed.

Run the slope tests for both tanks and put the results side by side in `NOTES.md`.

## 10. Deliverables

- Both tanks drivable on the same course, switchable with `T`.
- `PhysicsTankTuning` with six documented feel knobs and three presets.
- `NOTES.md` additions: physics design, derived values, test results for both tanks side by side, known issues, and a **"how to compare"** checklist for the developer, e.g.:
  - climb the 30 degree ramp from a standstill and with a run-up in each tank
  - drive along the ledge strip
  - spin in place on a slope
  - drive over the steps and the crest
  - try each preset
- README updated with the new controls (`T`, `1`/`2`/`3`).

## 11. Working rules

- No new dependencies, addons or downloads.
- Do not change the kinematic tank's behaviour or tuning.
- Do not delete files you did not create; do not force-push.
