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
