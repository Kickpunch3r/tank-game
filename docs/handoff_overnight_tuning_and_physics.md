# Overnight hand-off: kinematic tuning + physics tank comparison

For a cloud agent working alone overnight. You are picking up a Godot 4.6.3 tank game. Your job
is to carry out two existing plans in the repository root:

1. `KINEMATIC_TUNING_PLAN.md` (branch `kinematic-tuning`)
2. `PHYSICS_COMPARISON_PLAN.md` (branch `physics-tank`)

**Both plans were written before a lot of recent work.** Where a plan and the current project
disagree, the current project (code, `README.md`, `NOTES.md`, this hand-off) is the source of
truth, as `PHYSICS_COMPARISON_PLAN.md` section 2a already says. Section 4 below lists the known
disagreements and what to do about each.

The developer (art/design background, learning GDScript) will read your results in the morning.
Write for them: plain language, short, "how it works now" kept separate from "how it could work".

---

## 1. Order of work and branches

Do the plans **one after the other in this one session** (they touch the same shared files: the
Tab panel, debug display, test runner, input map and player rig, so doing them in parallel would
collide).

1. `git checkout -b kinematic-tuning` from `main`. Carry out the kinematic plan, **committing after
   each of its milestones**. Push the branch.
2. `git checkout -b physics-tank` **from `kinematic-tuning`** (the physics tank shares the six
   knob names, grip-as-an-angle, the preset files' names and the preset-switching code). Carry
   out the physics plan, committing after each milestone. Push the branch.
3. **Never merge into `main`, never force-push, never rewrite history.** The developer merges
   after trying both by hand.

If you run out of time, a finished kinematic branch plus a partly-done physics branch (each
milestone committed and described) is a good result. Don't leave anything half-written
uncommitted.

## 2. Setting up and running the tests

This project was developed on Windows. In the cloud you'll be on Linux, so get the matching
Godot build (the official engine binary is the only download allowed; no addons or assets):

```bash
curl -L -o godot.zip https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip
unzip godot.zip
GODOT=./Godot_v4.6.3-stable_linux.x86_64
$GODOT --headless --path . --import          # registers scripts and classes; run after adding any class_name
$GODOT --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```

- Keep the Godot binary **outside the repository** (or make sure it's never committed).
- `--fixed-fps 60` runs physics as fast as possible; the full suite takes a few seconds.
- Exit code 0 = all passed. The report is printed and saved to `tests/last_results.txt`
  (git-ignored).
- **Baseline before you change anything: 138 of 138 checks pass on `main`.** Run it first and
  confirm. If it doesn't, stop and record why in your report before doing anything else.
- **Every commit must leave all tests passing**, or the commit message and report must say
  exactly which check fails and why.
- Test runs bind the phone servers to 127.0.0.1 on ports 18080/18081 and never run the real
  `adb` (see `tests/test_runner.gd`). Keep it that way.
- No real window, GPU or phone exists in the cloud: you can't take screenshots or play. Say
  plainly what is untested, and put it in the hand-test checklist.

## 3. Read first

1. `CLAUDE.md`: the developer's working rules.
   - Treat **Independent work mode as ON** for this session, as it describes: make decisions
     yourself and record each one, with the alternatives and why, in
     `docs/kinematic_tuning_design.md` and `docs/physics_tank_design.md`.
   - You may create and edit `.tscn`/`.tres` files as text: reference files by path, don't
     hand-write UIDs, and load-check headlessly after every change. The "Godot closed" rule
     doesn't apply in the cloud.
2. `README.md`: the current controls and features.
3. `NOTES.md`, especially:
   - the movement model
   - Final tuning and test results (the slope table)
   - entries 13–17 at the end (cliff fix, phone, USB, brake, idle drag, warm-up, turn scrub)
4. The two plans.
5. The code you'll be changing:
   - `scripts/tank.gd`, `scripts/tank_tread.gd`, `scripts/tank_tuning.gd`
   - `scripts/tuning_panel.gd`, `scripts/debug_hud.gd`
   - `scenes/player_rig.tscn`, `scenes/tank.tscn`
   - `tests/*`

## 4. What has changed since the plans were written

### 4.1 Controls now (the "same controls" requirement means these)

| Action | Keyboard | Phone | Notes |
|---|---|---|---|
| Left tread | `W` / `S` step a level | Left lever (7 notches) | Levels stay where left |
| Right tread | `Up` / `Down` step a level | Right lever | |
| Levels | 3 forward, 3 back: **0.25, 0.5, 1** | Same (filled into the page from `TreadLevels`) | Defined once in `scripts/tread_levels.gd` |
| **Brake** (hold) | `Space` (input action is still called `driver_all_stop`) | Big BRAKE button | `DriverStation.brake`; brake wins over everything |
| Reset | `R` | | |
| Camera view | `V` | | |
| Debug display | `F3` | | |
| Tuning panel | `Tab` | | |
| Full screen | `F11` | | |

- **Level 0 is "idling", not braking:** no engine push, and `idle_drag` (3) slows that tread. One
  lever at 0 gives a slow, heavy pivot; both at 0 stop the tank in about 3.2 s.
- **Phone watchdog:** if the driver phone goes quiet for 0.25 s, its input stops and the game
  **brakes for 3 s** (`ControllerServer.LOSS_BRAKE_SECONDS`).
- **Gamepad:** still exists (sticks), but the developer will never use one. Don't add gamepad
  controls (no gamepad brake). Ignore the plan's gamepad columns beyond keeping what exists.
- `T`, `1`, `2`, `3` are **free**, so use them as the plans say.
- Physics plan section 2a asks you to list differences from its original controls table in
  `NOTES.md`. The table above is that list; copy it there.

### 4.2 `TankTuning` today (approved by the developer: "feels right")

The kinematic plan says "replace the current `TankTuning` contents with these six knobs".
**Don't delete the existing values.** The developer tunes them live in the Tab panel, tests use
them, and they approved the current feel. Instead:
- Make the **six knobs** the main, top section.
- Move every existing value into the **"Advanced, do not usually touch"** section.
- Where the plan says a value should be *derived* (turn resistance, tilt smoothing, slide decay),
  derive it **only if the default knob values reproduce today's numbers**. Otherwise keep it as
  an advanced value and record why.

Current values (defaults in `scripts/tank_tuning.gd`, some saved in `tuning/tank_tuning.tres`):

| Value | Default | What it does now |
|---|---|---|
| `max_tread_speed` | 10 | Top speed of each tread (m/s) |
| `max_drive_accel` | 5 | Hardest push; **also the brake's strength** (stop from 10 m/s in 1.97 s) |
| `rolling_resistance` | 0.1 | Always-on small drag |
| `idle_drag` | 3 | Drag on a tread at level 0 (engine idling) |
| `power_falloff_start`, `power_at_top_speed` | 1, 1 (off) | Push fades toward top speed |
| `warm_up_time` | 0 (off) | Push builds up when more power is asked for; never delays the brake |
| `traction_coeff` | 0.55 | Grip (about 29° holdable slope) |
| `g` | 9.8 | Gravity |
| `track_width` | 3 | Turning geometry |
| `turn_resistance` | 0.75 | Holds back turn rate |
| `turn_scrub` | 2 | Turning lowers the speed treads can hold (spin 40°/s, pivot 25°/s) |
| `air_gravity_scale`, `nose_dip`, `landing_speed_loss` | 1, 0, 0 | Jump feel (off by default) |
| `tilt_smoothing` | 8 | Hull picture follows the ground |

Terrain types (`terrain/mud.tres`, `terrain/sand.tres`) multiply grip and top speed and add drag.
Note: `TerrainType.top_speed` is a *multiplier*. Your new `top_speed` knob is in m/s. Document
the difference.

**Default parity is the most important kinematic check.** With default knobs, these must come out
the same as now (from `NOTES.md` and the test report):
- the 10-ramp slope table (standing and run-up)
- flat driving (39.9 m in 5 s)
- brake 1.97 s; idle stop 3.2 s
- spin 40°/s; pivot 25°/s

If any change, explain it.

Suggested mappings (decide and record):
- `grip` default ≈ atan(0.55) ≈ **28.8°**
- `pulling_power` / `weight` = `max_drive_accel`
- `top_speed` = `max_tread_speed`
- `sideways_grip` default **1** = no slide, which is today's behaviour
- If `weight` should also scale `idle_drag` or `turn_scrub`, decide, record, and keep parity at
  the default.

### 4.3 Other things the plans don't know about

- **Player rig:** the tank, chase camera, view switcher, debug display, Tab panel, phone server,
  USB link and phone status line live in `scenes/player_rig.tscn`. The test course and every
  painted level (`levels/starter/starter.tscn`, run with F6) use it, and `LevelRoot` adds it
  automatically.
  - Both tanks and the `T` swap must work in levels too, not just on the test course.
  - Tests reach the tank at `PlayerRig/Tank`. Keep that path working, or update every test.
- **The DriverStation is a child of the tank** (`Tank/DriverStation`, with keyboard, gamepad and
  phone sources). For two tanks:
  - either give the physics tank its own identical station,
  - or move the station up to the rig and let the active tank read it.

  Decide and record. Either way the phone (`PhoneDriverInput` finds the server by group) and the
  brake must work for whichever tank is active, and the hidden tank must not react to input.
- **The debug display, Tab panel and HUD expect `Tank`.** Make them work with whichever tank is
  active, for example through a small shared interface. Don't copy them. Rebuild the display from
  state, which is the developer's preference.
- **Tab panel:**
  - Show the six knobs first, then Advanced.
  - Typed values may go past the slider (it stretches); hard limits apply only where the maths
    breaks.
  - The wheel never changes values.
  - **Copy values** must keep naming the file each value belongs in.
  - **After a preset switch (1/2/3), the panel must show the new values.**
- **Cameras:** the chase camera already stays level. The **driver slit camera deliberately tilts
  with the hull**: the developer chose this. Physics plan section 5 ("damp pitch") applies to the
  chase camera only.
  - The kinematic `tippiness` sway is visual only and "must not affect the cameras". The slit
    camera sits under `Visual/Hull`, so make sure the sway doesn't move it. For example, sway a
    child node that the camera isn't under, or counter it. Record what you did.
- **Wall/cliff handling:** `Tank._blocked_by_wall()` stops treads spinning against walls and stops
  cliffs launching the tank. Keep it; the physics tank should simply not need it.
- **Physics engine:** the project uses **Jolt** (`project.godot`). Physics tick is the default 60 Hz.
- **Course additions** (ledge strip, steps, crest): prefer building them in code, like
  `CourseBuilder` / `SlopeLadder`. If you add nodes to `scenes/test_course.tscn`, keep the change
  small. Don't move existing test areas: ramps at z = −70, terrain ramps at x = −100, mud/sand
  patches at z = 35, bumps at x = 100, flat test area at (−100, 60), drop area at (−100, −20).

## 5. Rules

- Everything in `CLAUDE.md` and both plans' "working rules": no addons or downloads (except the
  Godot binary for running tests), don't delete files you didn't create, no force-push.
- **Don't change the kinematic tank's default feel on `main`.** Everything happens on the two
  branches.
- Commit messages: write the message to a file and use `git commit -F <file>`. End each with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Add new checks to the existing test runner (`tests/test_runner.gd`) as new suite files, like
  the others. One command must run everything.
- **If something stalls** (for example physics jitter that won't settle within about two hours of
  trying), take the simplest stable option, write down what you tried and why you stopped, and
  move on. Don't add tuning values to fix stability. Raise the physics tick rate first, as the
  plan says.

## 6. What to leave for the morning

1. Two pushed branches, each milestone a separate commit.
2. `docs/overnight_report.md`, in plain language, at most about a page:
   - what was done on each branch, and what wasn't
   - the test results, including the slope tables side by side
   - **decisions that need the developer's OK**, as a short list
   - **a hand-test checklist** for each branch (what to drive, what to press, what to look for)
   - what couldn't be tested in the cloud (feel, visuals, phone)
3. `docs/kinematic_tuning_design.md` and `docs/physics_tank_design.md`: each decision, the
   alternatives, and why.
4. `NOTES.md` and `README.md` updated as the plans' "deliverables" sections ask: new keys `T`,
   `1`/`2`/`3`, how to tune, and how to compare.
