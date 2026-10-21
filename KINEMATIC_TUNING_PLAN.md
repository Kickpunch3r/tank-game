# Kinematic Tank: Simplified Tuning - Build Plan

Simplify how the existing kinematic tank is tuned so the developer edits a handful of plain-language "feel knobs" instead of raw values. This uses the **same six knobs as the physics tank** in `PHYSICS_COMPARISON_PLAN.md`, so a preset like "heavy" means the same thing in both tanks and the comparison is fair.

Do this after the milestones in `TANK_PLAN.md`. It can be done before or after the physics tank. Work on a branch `kinematic-tuning`, commit after each milestone, and record decisions in `NOTES.md`.

## 1. The six feel knobs

Replace the current `TankTuning` contents with these six editable values, each with a plain-language comment and a sensible range. Keep names identical to the physics tank.

| Knob | Meaning | How the kinematic tank uses it |
|---|---|---|
| `weight` | How heavy the tank feels. | Divides acceleration and braking (`accel = pulling_power / weight`), slows turn response, and makes the hull tilt lag behind the ground more. Heavier = more momentum, slower to start and stop. |
| `top_speed` | Maximum forward speed. | Sets maximum tread speed. |
| `pulling_power` | How hard the treads push. | Sets drive acceleration before weight is applied. Affects take-off and how far a run-up carries up a slope. |
| `grip` | How steep a slope the tank can ever hold. | **Expressed as an angle in degrees** (the steepest slope the treads can hold, e.g. 35). Converted internally to a traction coefficient with `tan(angle)`. Steeper slopes than this are always unclimbable, whatever the momentum. |
| `sideways_grip` | How much the tank resists sliding sideways when turning. | **New behaviour:** when the tank turns at speed, a small part of its velocity carries on in the old direction and decays at a rate set by this knob. 1 = no slide (current behaviour), lower = more drift. |
| `tippiness` | How much the hull visibly sways. | Visual only: how far the hull pitches back on acceleration, dips forward on braking, and leans outward in turns. 0 = rigid, 1 = very swaying. Must not affect movement or the cameras. |

Also apply the "grip as an angle" idea to the physics tank (express its `grip` knob in degrees and convert internally), so the knob reads identically in both tanks. If the physics tank already exists, update it; if not, note it for when it is built.

## 2. Derived and fixed values

Everything else is derived in code or fixed once, in a clearly separate "Advanced, do not usually touch" section:

- **Gravity strength:** fixed (9.8).
- **Track width:** fixed to match the hull shape.
- **Turn resistance:** derived from `weight`.
- **Rolling resistance:** fixed small value.
- **Tilt smoothing:** derived from `weight`.
- **Slide decay rate:** derived from `sideways_grip`.

Explain each derivation briefly in `NOTES.md`.

## 3. Presets

Create three presets as `.tres` files with the **same names and intent** as the physics tank's: `heavy.tres`, `nimble.tres`, `slippery.tres`. Keys `1`/`2`/`3` switch preset live while driving (share the same key bindings and preset-switching code with the physics tank if it exists). Show the active preset in the HUD.

## 4. HUD additions

Show the six current knob values, the active preset, the current sideways slide speed, and the "climbable limit" angle derived from `grip`.

## 5. Milestones (commit after each)

1. **Knob resource:** new `TankTuning` with six knobs, the advanced section, and derivations. Default values chosen to reproduce the current feel as closely as possible.
2. **Weight and tippiness:** inertia effects and visual body sway.
3. **Sideways slide.**
4. **Grip as an angle:** in this tank, and in the physics tank if it exists.
5. **Presets + live switching + HUD.**
6. **Tests and docs.**

## 6. Verification

Add to the existing test runner:

- **Default parity:** with default knob values, the slope test results match the results before this change (record before and after in `NOTES.md`). If they differ, explain why.
- **Grip limit:** for a few `grip` values (e.g. 25, 35, 45 degrees), the tank never climbs a ramp steeper than that angle, even with a run-up.
- **Weight:** a heavier preset takes longer to reach top speed and travels further after releasing the throttle.
- **Slide:** with `sideways_grip` at 1, a sharp turn at speed produces no measurable sideways slide; with a low value it does.
- **Tippiness:** changing it does not change the tank's path in any test (visual only).
- Run the slope tests for each preset and include the results table in `NOTES.md`.

## 7. Deliverables

- `TankTuning` with six documented knobs, presets, and live switching.
- `NOTES.md`: knob-to-behaviour explanations, derivations, before/after results, per-preset results.
- README updated with the preset keys and a short "how to tune" section: change one knob at a time, use the HUD and slope ladder to see the effect.

## 8. Working rules

- Keep the movement model itself kinematic; this is a tuning and feel layer, not a rewrite.
- No new dependencies, addons or downloads.
- Do not delete files you did not create; do not force-push.
