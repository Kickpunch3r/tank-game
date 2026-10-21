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
