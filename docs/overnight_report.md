# Overnight report: kinematic tuning + physics tank (2026-10-21)

Two branches, pushed, nothing merged into `main`. Every milestone is its own commit, and every
commit passes all tests. Full decisions with alternatives: `docs/kinematic_tuning_design.md`
and `docs/physics_tank_design.md` (each ends with a longer hand-test checklist).

## What was done
**`kinematic-tuning`** (from `main`), all 6 milestones of `KINEMATIC_TUNING_PLAN.md`:
- `TankTuning` now starts with the six feel knobs (weight, top speed, pulling power, grip in
  degrees, sideways grip, tippiness); every old value is kept under "Advanced".
- **With the default knobs nothing changes:** the whole test report is identical to `main`.
- Weight, a hull sway picture (tippiness, never moves the slit camera), a sideways slide in
  turns, three presets on keys 1/2/3, new HUD lines. 159 checks pass (was 138), ~15 s.

**`physics-tank`** (from `kinematic-tuning`), all 6 milestones of `PHYSICS_COMPARISON_PLAN.md`:
- A physics tank on 8 spring probes, with the same six knobs and the same preset files.
- **T** swaps tanks in place (test course and painted levels); camera, slit view, HUD, Tab panel,
  phone and brake follow the active tank. Ledge strip, steps and crest added to the course.
- 190 checks pass, ~70 s (the physics slope tests run 3 times each, as the plan asks).

**Not done:** nothing from the plans is missing. Not built (ideas only): a hard "never above
grip" cut-off, a slanted front probe for the physics tank, a 4th preset key for "saved tuning".

## Results (slope ladder, standing start / run-up)
| Ramp | Kinematic (= main) | Physics |
|---|---|---|
| 5°–20° | climbs / climbs | climbs / climbs |
| 25° | 7.0 s / 10.0 s | 6.6 s / 10.6 s |
| 30° | fails / 10.1 s | fails / 11.3 s |
| 35° | fails / 10.4 s | fails / **fails (70% up)** |
| 40° | fails / 11.2 s | fails / **fails (41% up)** |
| 45°, 55° | fails / fails | fails / fails |

Flat, kinematic vs physics: 39.9 vs 38.2 m in 5 s; spin 40 vs 44°/s; one-tread pivot 25 vs
34°/s. Per-preset tables are in `NOTES.md` and the test report.

## Decisions that need your OK
1. **Grip = steepest slope the tank can hold or climb from a standstill**, not "never, whatever
   the momentum" (the plan's words): your approved 30°–40° run-up climbs need momentum to win.
2. **Old values merged into knobs:** `max_tread_speed` → `top_speed`, `max_drive_accel` →
   `pulling_power ÷ weight`, `traction_coeff` → `grip` (degrees). Old names still work in code.
3. **Weight also divides idle drag, turn rate and tilt smoothing**; turn resistance and tilt
   smoothing stay as advanced values (for weight 1) instead of being fully derived.
4. **Preset values are my guesses** (table in the kinematic design doc). Nimble's 12 m/s top
   speed lets it climb 45° with a run-up.
5. **Physics run-up is weaker on 35°–40°** (lifting the nose onto the slope costs ~4 m/s). Keep
   it as a real difference, or ask for a fix (options in the physics design doc, section 8).
6. **Each tank has its own driver station**; keyboard levels are copied on a swap.
7. **Chase camera now smooths its look point up and down** (`look_smoothing` 6) for both tanks,
   to calm the physics tank's bounce. 0 = exactly as before.
8. Physics tank default **tippiness 0.3** (kinematic default stays 0 = no sway).
9. Physics turning weight comes from the advanced `max_sideways_rate` (6), set so its spin
   (44°/s) is close to the kinematic tank's (40°/s).

## Also found and fixed
- The Tab panel's "Reset to saved" didn't reset the hidden tank's values after a preset
  (physics branch only; found by the tests).

## Hand-test checklist (short)
**Kinematic branch:** drive as usual: it should feel exactly the same. Press 1, 2, 3: Heavy is
slow to start and coasts far; Nimble rocks back on take-off (chase view) while the slit view
does not rock; Slippery drifts outward in a fast turn. Tab panel shows the preset's values;
"Reset to saved" goes back.
**Physics branch:** T swaps at the same spot; the blue-grey tank settles quickly and sits still.
Drive the ledge strip with one tread over the edge, the steps and the crest; climb 30° with a
run-up in both tanks; phone and BRAKE with each tank; T in the starter level.

## Couldn't be tested in the cloud
Feel, visuals (no window or GPU: no screenshots), the phone, and the Inspector order of the
knobs (checked through Godot's property list, not on screen). Tests ran on Linux with the
official Godot 4.6.3 build; nothing Windows-specific was touched.
