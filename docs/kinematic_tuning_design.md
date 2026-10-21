# Kinematic tank tuning: design decisions

Made while working alone overnight (branch `kinematic-tuning`, from `KINEMATIC_TUNING_PLAN.md`
and `docs/handoff_overnight_tuning_and_physics.md`). Each decision lists the alternatives and why.
Push back on any of them.

## 1. The six knobs replace three old values; everything else moves to "Advanced"
- **How it works now:** `TankTuning` starts with the six feel knobs (`weight`, `top_speed`,
  `pulling_power`, `grip`, `sideways_grip`, `tippiness`), then one "Advanced (do not usually
  touch)" group with every other old value, unchanged.
- Three old values were the same thing as a knob, so the knob *is* that value now:
  - `max_tread_speed` → `top_speed` (same number, m/s)
  - `max_drive_accel` → `pulling_power / weight` (same number at weight 1)
  - `traction_coeff` → `grip` as an angle: `traction_coeff = tan(grip)`. Default grip
    **28.8108°** = atan(0.55). (28.81° was tried first: the 35° standing test then got "4% up"
    instead of "3% up", so the extra digits are kept for exact parity.)
- The old names still work in code (they read and write the knob), so nothing else had to change.
- **Alternatives:** keep `max_tread_speed` etc. as separate advanced values alongside the knobs
  (rejected: two values for one thing, and it's unclear which wins); derive everything and delete
  the old values (rejected by the hand-off: you approved the current feel and tune them live).

## 2. Weight is a multiplier, 1 = today's tank
- `weight` 1 = the normal tank, 2 = twice as heavy. `pulling_power` is "m/s per second at weight 1".
- **Alternative:** weight in tonnes and pulling power in kilonewtons (more "real", but bigger,
  less readable numbers, and the default would need a conversion to keep today's feel).
- The physics tank uses the same meaning: its mass is `weight` × a fixed base mass, and its
  push is `pulling_power` × base mass, so acceleration = pulling_power / weight in both tanks.

## 3. Presets are a separate, tiny resource type (`TankFeel`)
- A preset file holds only the six knobs. Pressing 1/2/3 copies them onto the tank's tuning.
- **Why not inheritance** (`TankTuning extends TankFeel`)? Checked headlessly in Godot 4.6.3:
  the Inspector lists a subclass's own values *before* the inherited ones, so "Advanced" would
  show above the six knobs. So each tuning resource declares the six knobs itself, with the same
  names, and `TankFeel.KNOB_NAMES` is the shared list. A test checks both tunings have them.

## 4. The Tab panel rows come from the tuning resource
- `TankTuning.panel_settings()` lists its rows (knobs first). The panel adds the camera, slit,
  level and terrain rows itself. This lets the physics tank list its own rows later without
  copying the panel.
- The panel can now `rebuild()` itself from the current values (used after a preset switch).
  "Reset to saved" still goes back to the values at the start of the game, even after a rebuild.

## 5. What weight changes (all exactly today's numbers at weight 1)
| Effect | Rule | Why |
|---|---|---|
| Speeding up and braking | push = `pulling_power / weight` | the plan |
| Idling (lever at 0) | drag = `idle_drag / weight` | so a heavy tank coasts further, as the plan's test asks |
| Turning | turn rate × `(1 − turn_resistance) / weight` | "slows turn response" |
| Hull tilt | `tilt_smoothing / weight` | "tilt lags more" |
| Rolling resistance, turn scrub | unchanged | friction grows with weight, so the slow-down it causes doesn't change |

- **Turn resistance and tilt smoothing stay as advanced values** (the plan says "derived from
  weight"). They are now the values *for weight 1*, and weight scales them. Deriving them purely
  from weight would have removed two values you tune live, for no gain.
- Measured: weight 2 takes 3.97 s to reach 9.5 m/s (1.95 s at weight 1) and coasts 28.2 m after
  letting go (14.6 m).

## 6. Tippiness: a new `Sway` node holds the meshes
- `Visual/Hull` (tilts to the ground) now has a child `Sway` (script `HullSway`) holding all the
  meshes. The slit camera stays on `Visual/Hull`, beside `Sway`, so the sway can't move it.
- The sway is a damped spring toward a target angle: target pitch = tippiness × 1.5°
  (`sway_degrees_per_accel`) per m/s² of speeding up or braking; target roll the same per m/s²
  of turning (speed × turn rate), leaning outward. At most 12°. At tippiness 1, a full-power
  start gives about 7.5°.
- Tests: the path is identical with tippiness 0 and 1, and the slit camera is in exactly the same
  place and direction.
- **Alternatives:** sway `Visual/Hull` and counter-rotate the camera (fragile: any rounding shows
  as camera wobble); sway `Visual` (same problem, the camera is under it).
- **For art later:** put models under `Visual/Hull/Sway`.

## 7. Sideways slide
- **How it works now:** each frame the tank turns a little. The part of its old motion that now
  points sideways is added to a "slide" velocity (flat, in the world), which fades away at
  `slide decay rate` per second. The slide is added to the tank's motion.
- Fade rate from the knob (`TankFeel.slide_decay_rate`): `0.3 + slide_decay_scale × g / (1 − g)`
  where g = `sideways_grip`. At 1 there is no slide at all (the code is skipped, so the default
  is exactly today's tank). At 0.5 it fades at 3.3 per second (gone in about a second), at 0.3
  at 1.6 per second, at 0 at 0.3 per second (a long skate). `slide_decay_scale` (3) is advanced.
- Hitting a wall stops the part of the slide going into the wall. In the air the slide is kept.
- Measured: at 10 m/s, swinging into a hard turn (levers 1 and 0.25): slide up to 0.73 m/s
  at sideways grip 0.3; 0 at sideways grip 1.
- Found while testing: even with no slide, the tank's real motion lags its turn by one frame
  (it moves along the heading it had at the start of the frame), about 2 cm/s sideways in that
  turn. That was already the case on `main` and is left alone.
- **Alternatives:** slide only on the tread speeds (can't express sideways motion); a
  grip-limited sideways friction force like the physics tank (more realistic, but more values
  and it would change the default feel).

## 8. Grip as an angle: "steepest slope it can *hold*", not "ever climb" (needs your OK)
- **How it works now:** `grip` is in degrees; the tank's push is capped at
  tan(grip) × g × cos(slope), so on a slope steeper than `grip` it can't hold or climb under
  power. A run-up can still carry it further up by momentum, exactly as before.
- **The plan says** steeper slopes than `grip` should be unclimbable "whatever the momentum".
  That contradicts the approved targets (30–40° climbable only with a run-up, at 28.8° grip)
  and the hand-off says the current project wins. So I kept the momentum behaviour, and the
  grip test checks the standing start only.
- Measured (pulling power raised to 20 so the engine isn't the limit):

  | Grip | Steepest climbed, standing | Steepest climbed, run-up (info) |
  |---|---|---|
  | 25° | 20° | 35° |
  | 35° | 30° | 45° |
  | 45° | 40° | 55° |

- **If you want "never, whatever the momentum":** add a hard cut-off (e.g. the treads stop
  pushing and gravity wins above grip + N degrees). Not built.
- The physics tank doesn't exist on this branch; its `grip` will use the same degrees and
  `tan()` (noted for the physics branch).

## 9. Presets and switching
- Files: `tuning/presets/heavy.tres`, `nimble.tres`, `slippery.tres` (type `TankFeel`: six knobs
  only). Keys **1 / 2 / 3** (Input Map `preset_1..3`), handled by a new `PresetSwitcher` node in
  the player rig. It sets the knobs on every tank in its `tanks` list (just `Tank` on this
  branch), then rebuilds the Tab panel so it shows the new values.
- Session-only, like the Tab panel: **Reset to saved** goes back to `tank_tuning.tres`.
  **Copy values** lists the knobs under `tuning/tank_tuning.tres` (where they'd be saved).
- **Which preset is active is worked out from the values** (`PresetSwitcher.preset_name_for`):
  the HUD shows a preset's name only while all six knobs match it. Change one knob in the panel
  and it shows "none". No stored state that could go out of date.
- Starting values (my guesses, for you to tune):

  | Knob | Saved tuning | Heavy | Nimble | Slippery |
  |---|---|---|---|---|
  | weight | 1 | 2 | 0.7 | 1 |
  | top_speed | 10 | 8 | 12 | 10 |
  | pulling_power | 5 | 8 (push 4) | 5 (push 7.1) | 5 |
  | grip | 28.8° | 30° | 32° | 18° |
  | sideways_grip | 1 | 1 | 0.8 | 0.25 |
  | tippiness | 0 | 0.25 | 0.6 | 0.4 |

- Note: Nimble's higher top speed lets it climb the 45° ramp with a run-up (8.5 m/s more speed
  at the base than the 45° ramp can soak up). That breaks the "45° always fails" target, but
  only in that preset; the target is for the saved tuning. Lower Nimble's top speed to 10 if
  45° should stay impossible in every preset.
- No key for "back to the saved tuning" (use the panel's Reset to saved). A 4th key could do it.

## 10. HUD
- New lines: sideways slide speed; the active preset; the six knob values; "climbable from a
  standstill" = the lower of the grip angle and the engine's limit (asin(push / g)), shown with
  both, e.g. "28.8° (grip 28.8°, engine 30.7°)".

## Hand-test checklist (kinematic branch)
Nothing below could be tried in the cloud (no window, no screen, no phone). Start the game (F5).
1. **Nothing changed by default:** drive around, climb 25° from a standstill, 30°–40° with a
   run-up, brake with Space, let go to idle. Should feel exactly as before.
2. **Press 1 (Heavy):** F3 shows "Preset: Heavy". Slower start, longer coast when you put both
   levers to 0, slower turns. 25° from a standstill now fails (the engine is too weak).
3. **Press 2 (Nimble):** quick, the hull rocks back on take-off and dips on braking. Open Tab:
   the knobs show Nimble's values.
4. **Press 3 (Slippery):** at full speed, put one lever to 0.25: the tank drifts outward in the
   turn (F3 "Sideways slide" goes up), then the drift fades.
5. **Tippiness and the slit:** press 2, switch to the slit view (V), speed up and brake. The
   *chase view* hull should rock; the *slit view* must not rock (it only tilts with the ground).
6. **Tab panel:** after pressing 1/2/3, the six knobs at the top show the new values; "Reset to
   saved" puts everything back and F3 says "Preset: none".
7. **Phone:** the presets are keyboard-only; the phone drives as before (not affected).
