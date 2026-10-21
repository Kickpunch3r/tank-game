# Physics tank: design decisions

Made while working alone overnight (branch `physics-tank`, built on `kinematic-tuning`, from
`PHYSICS_COMPARISON_PLAN.md` and `docs/handoff_overnight_tuning_and_physics.md`). Each decision
lists the alternatives and why. Push back on any of them.

## 1. Body, springs and probes
- **How it works now:** `PhysicsTank` (`scripts/physics_tank.gd`, scene `scenes/physics_tank.tscn`)
  is a `RigidBody3D`. 8 `RayCast3D` probes (4 per tread, at 1.875 m and 0.625 m in front of and
  behind the middle, 1.5 m either side) look down from 0.85 m above the tread bottoms. Each
  probe that finds ground within the spring length (1 m) pushes the hull up at its own place:
  stiffness × squash − damping × downward speed (never pulling).
- **Stiffness is derived** from weight and a fixed target sag (15% of the spring): each spring
  carries 1/8 of the weight at 15% squash. **Damping is derived** as 0.45 of "critical" for 1/8
  of the mass. Neither is a value you set. Measured: dropped from 0.3 m, settles within 2 s at
  exactly 15% squash, then moves 0.1 mm in the next second.
- Probes are made by the script (generated content, per CLAUDE.md), not saved in the scene.
- **Collider:** a box with sloped nose and tail (a 12-point convex shape), 3.6 × 0.95 m, 3.8 m
  long underneath and 5 m on top, its bottom 0.35 m above the tread bottoms. The plan said "a
  simple box": the slopes let it ride up onto step edges instead of stopping dead on them.
  In normal driving the collider never touches the ground; the springs carry it.
- **Physics engine: Jolt** (as the project already used). **Tick: 60 Hz**, unchanged: no jitter
  was seen, so it wasn't raised (raising it would also change the kinematic tank's timing).
- **Godot's own damping replaced, not added:** RigidBody3D adds the project's default damping
  (0.1) to its own by default; that cost 0.25 m/s of top speed. The tank now uses
  `DAMP_MODE_REPLACE` with linear damping 0 and angular 0.1 (advanced values).

## 2. Drive and grip
- Each tread is in one of the kinematic tank's three states: **braking** (target 0, holds
  against gravity), **idling** (lever 0: idle drag ÷ weight), **driving** (chases lever × top
  speed). The push = (target − tread speed) × `throttle_response` (5 per second), minus gravity
  along the tank, capped at `pulling_power / weight`. So it fades to nothing at top speed (the
  plan's "top speed" rule) without a separate fade value.
- A tread's push is shared equally over its grounded probes, along the ground under each probe.
- **Sideways:** each grounded probe pushes against its sideways speed (× a rate from
  `sideways_grip`) and against gravity's sideways pull (so it doesn't creep down side slopes).
- **Grip cap:** forward push and sideways hold together are at most tan(grip) × how hard that
  probe is pressed. A lightly loaded probe (lifted tread, steep slope) grips less by itself.
- **Turning heaviness comes from the sideways hold.** A turning tank drags the front and back
  of its treads sideways. With the hold rate at 20 per second it could only spin at 12°/s; the
  advanced `max_sideways_rate` is 6 per second (sideways_grip 1), which gives a 44°/s spin and
  a 34°/s one-tread pivot (kinematic: 40°/s and 25°/s). Straight: 38.2 m in 5 s (kinematic 39.9).
- **Alternative considered:** a "belt slip" friction model (each probe's friction points against
  the slip between belt and ground). More realistic, but it spins at ~220°/s with these numbers
  and would need an engine-power model to tame it: more values, against the plan's "simple".

## 3. Controls
- The physics tank has its own `DriverStation` with the same three sources (keyboard, gamepad,
  phone), so it reads input exactly like the kinematic tank. A test drives both with the same
  station values (left only, right only, both, opposite) and checks they move and turn the same
  way.

## 4. Tuning resource and presets
- `PhysicsTankTuning` (`tuning/physics_tank_tuning.tres`): the six knobs first, same names and
  meanings as `TankTuning`, then "Advanced". Built in milestone 1 (not 3) because the springs
  are derived from it.
  - `weight`: mass = weight × 30 000 kg (`base_mass`). `pulling_power`: push = pulling_power ÷
    weight, as in the kinematic tank. `grip`: degrees, tan() inside, per probe.
  - `sideways_grip`: sideways hold rate = the kinematic tank's slide fade rate for the same
    knob value (`TankFeel.slide_decay_rate`), capped at `max_sideways_rate` (6). So 1 = as firm
    as the tank allows, lower = it drifts.
  - `tippiness`: centre of mass height, from 0.2 m (0) to 2.2 m (1) above the tread bottoms.
    Default **0.3** (0.8 m), not 0: a physics tank with no tippiness at all would be unreal, and
    the kinematic default of 0 means "no sway picture", which a physics tank can't have anyway.
- **The same preset files** (`tuning/presets/*.tres`) and the same `PresetSwitcher` set the six
  knobs on both tanks at once, so a swap keeps the preset.

## 5. Two tanks in one rig, swapped with T
- **How it works now:** `scenes/player_rig.tscn` holds both `Tank` and `PhysicsTank`. Its new
  root script `PlayerRig` keeps `active_tank`. **T** (Input Map `tank_swap`) swaps: the other
  tank is put where the active one is (upright, same heading, 0.2 m up, at rest), takes over
  its reset point and level start, and the keyboard lever levels carry over (the phone's carry
  over by themselves). The chase camera, the slit view in the V cycle, the HUD and the Tab panel
  are pointed at it, and the panel rebuilds.
- **The hidden tank is switched off** (`process_mode = DISABLED`, hidden). Disabled nodes get no
  input and Godot removes a disabled body from the physics world, so it can't react or be hit.
- **Each tank keeps its own DriverStation** (the hand-off's first option). **Alternative:** one
  station on the rig that the active tank reads: less duplication, but tests and the test
  runner spawn single tanks from `tank.tscn` with their own station, and every test reaches
  `tank.driver_station`, so it would have meant changing much more. The cost: the keyboard
  levels must be copied on a swap (done, and tested).
- **Shared interface (duck typing, no common class):** both tanks have `driver_station`,
  `tuning` (with `panel_settings()` and the six knobs), `bumped`, `place_at()`,
  `reset_to_spawn()`, `set_spawn()/get_spawn()`, `set_home()/get_home()`,
  `standing_start_distance(angle)`, `display_name()` and `debug_lines()`. A common base class
  isn't possible (one is a `CharacterBody3D`, the other a `RigidBody3D`).
- The HUD asks the active tank for its `debug_lines()` and adds the shared lines (keyboard
  levels, preset, knobs, climbable limit, view, phone). Nothing was copied.
- Levels: `LevelRoot` gives every tank in the rig the level's start. Tested in the starter
  level: T, drive 45 m on the painted ground, R back to the start.
- The kill plane resets anything with `reset_to_spawn()`; the phone buzz is connected for both.
- **Bug found and fixed:** "Reset to saved" in the Tab panel only reset the tank on show, so a
  preset left the hidden tank's knobs changed. The panel now remembers both tanks' tunings at
  the start and puts both back.

## 6. Chase camera pitch damping
- The chase camera already never rolls. It now also smooths how its look point moves up and
  down (`look_smoothing`, 6 per second), so the physics tank's spring bounce doesn't tip the
  view. This applies to the kinematic tank too, for a fair comparison; on ramps its look point
  now lags a little behind. `look_smoothing` 0 = the old behaviour. The slit camera still tilts
  with the hull (your choice).

## 7. Course additions
- **How it works now:** one new node in `scenes/test_course.tscn`, `ComparisonFeatures` at
  (100, 0, 90), the open ground south of the bumps. Its script builds three lanes when the game
  starts, each driven toward −Z from a start point at z = 125:
  - **Ledge strip** (x 73): a 1.2 m high, 6 m wide, 50 m long platform with a 10° ramp up onto
    it. Its +X edge is the drop.
  - **Steps** (x 100): 8 × 8 m blocks 0.2, 0.4 and 0.6 m high, 7 m apart.
  - **Crest** (x 125): a 3.5 m high hill with 15° slopes both sides.
- The Tab panel's reset-point list now includes the three start points ("Distance back" only
  applies to ramps).
- Nothing existing moved. Measured with the physics tank: with its middle 0.5 m inside the
  edge it teeters (12° roll standing, 22° driving) and stays on; with its middle at or past the
  edge it tips and falls off. Steps up to 0.6 m and the crest drive cleanly (pitch −21° to +17°).
- **Alternatives:** add the features to `levels/slope_ladder.txt` (it only knows ramps); edit
  them into the scene by hand as nodes (bigger scene file, against CLAUDE.md's "keep scenes small").

## 8. Tests and tuning results
- **No tuning changes were needed for the targets**: 45° and 55° always fail (every one of 3
  runs, standing and run-up), steeper is never easier, everything up to 25° climbs.
- **Physics vs kinematic, slope ladder** (physics: majority of 3 runs; all 3 agreed every time):

  | Ramp | Physics standing | Physics run-up | Kinematic standing | Kinematic run-up |
  |---|---|---|---|---|
  | 5° | 3.5 s | 10.2 s | 3.2 s | 10.0 s |
  | 10° | 3.7 s | 10.2 s | 3.5 s | 10.0 s |
  | 15° | 4.0 s | 10.2 s | 4.0 s | 10.0 s |
  | 20° | 4.8 s | 10.3 s | 4.8 s | 10.0 s |
  | 25° | 6.6 s | 10.6 s | 7.0 s | 10.0 s |
  | 30° | fails (44% up) | 11.3 s | fails (4%) | 10.1 s |
  | 35° | fails (23%) | **fails (70%)** | fails (3%) | climbs 10.4 s |
  | 40° | fails (17%) | **fails (41%)** | fails (4%) | climbs 11.2 s |
  | 45° | fails (12%) | fails (28%) | fails (3%) | fails (78%) |
  | 55° | fails (7%) | fails (13%) | fails (5%) | fails (49%) |

- **Why the physics tank's run-up is weaker on 35°–40° (needs your call):** both arrive at
  9.98 m/s, but the physics tank has to lift its 30-tonne nose onto the slope: in the first
  second on the 35° ramp it drops to 5.4 m/s (40°: 4.2 m/s), while the kinematic tank, which
  tips onto the slope instantly, only loses what gravity takes (~1.2 m/s). This is the "nose
  rides up onto an incline" behaviour the plan wanted, and it costs momentum. If 35° should
  climb with a run-up in the physics tank too, options are: a higher top speed, softer springs
  (`target_sag` up), or a slanted front probe like a real tank's raised front idler (not built).
- "Got N% up" on standing starts is higher for the physics tank because it starts with its
  front probes at the foot of the slope (the kinematic tank's middle is there), so part of it is
  already on the ramp, and its rear probes push from flat ground for a moment.
- Stability: flat ground at full speed into a spin: 1.9° tilt; across the bumps at full speed:
  14° tilt; every preset's spin at speed under 4°. No NaNs, nothing fell through the ground.
- **Test time:** the full suite now takes about 70 s (was 14 s), mostly the physics slope
  ladder run 3 times standing and 3 times with a run-up, as the plan asks.

## 9. HUD
- The physics tank's `debug_lines()`: tread speeds with grip "ok" or "SATURATED" per tread,
  forward speed and brake, hull pitch and roll, and a 4-row probe diagram (left and right tread,
  front to back): `#  15%` = touching with the spring squashed 15%, `.  ---` = in the air.
  Shared lines (keyboard levels, preset, knobs, climbable limit, view, phone) come from the HUD.

## Hand-test checklist (physics branch)
Nothing below could be tried in the cloud (no window, no screen, no phone). Start the game (F5).
1. **Swap:** press T. The tank turns blue-grey, stays where it was, facing the same way, at
   rest. F3 says "Tank: PHYSICS" and shows the probe diagram. Press T again: back to green.
2. **Rest:** the physics tank should settle within a second or two and sit still (no shiver).
3. **Drive:** same keys and levels as always; the hull should rock gently on take-off and
   braking, and lean in turns. Space brakes and holds it on a slope.
4. **Phone:** connect as usual, press T: the phone drives whichever tank is active; the BRAKE
   button and the 3 s watchdog brake work for the physics tank. Does hitting a wall buzz?
5. **Ledge strip** (Tab > Reset point > "Ledge strip"): climb the small ramp, steer right until
   one tread hangs over: it should lean, teeter, and fall off if you go further.
6. **Steps and crest:** drive over at half and full speed; watch the nose lift and drop.
7. **Ramps:** 30° from a standstill (fails) and with a run-up (climbs) in both tanks; 35° with
   a run-up: kinematic climbs, physics doesn't (see section 8).
8. **Presets 1/2/3** in the physics tank: Nimble has a high centre of mass (rocks more),
   Slippery drifts sideways in turns.
9. **Starter level** (`levels/starter/starter.tscn`, F6): T works there too.
10. **Chase camera:** is the view calm over the bumps? (`look_smoothing` on the ChaseCamera.)
