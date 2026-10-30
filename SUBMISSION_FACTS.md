# Submission facts: Tank Game

Facts gathered from this project's files, git history and docs (branch `main`; first written at
commit `a7059d3`, updated 2026-10-30 after the physics tank was chosen). Reasons are only given where the project writes
them down; everything else says "reason: ask the user". Nothing in the game was changed.

---

## 1. Readme section

### How to run
**No standalone Windows build exists yet**: the project has no export preset
(`export_presets.cfg`). Until one is made, it runs from the Godot 4.6.3 editor: open
`project.godot` and press Play (F5); the main scene is the test course.

To make the Windows build (Godot 4.6.3):
1. Editor > **Manage Export Templates** > download the 4.6.3 templates (official Godot download).
2. Project > **Export** > Add > **Windows Desktop**.
3. In the preset's **Resources** tab, "Filters to export non-resource files", add:
   `web/*, levels/*.txt`. The game reads these as plain files at runtime (phone page
   `web/controller.html`, Push relay page `web/push_relay.html`, ramp lists
   `levels/slope_ladder.txt` and `levels/terrain_ramps.txt`); without them the ramps and the
   phone page are missing. (Recorded in `NOTES.md`, "Known issues" and "Phone controller".)
4. Export Project > an empty folder > `TankGame.exe` (with "Export With Debug" off for a release build).
5. Copy `web/push_relay.html` into the same folder (the Push 3 pad lights need it as a normal
   file the marker can open in a browser).
6. Zip the folder. The marker runs `TankGame.exe`; no Godot needed.
- Untested: no export has been made, so steps 3–4 are unconfirmed in practice.
- The painted **starter level** (`levels/starter/starter.tscn`) is not reachable from the main
  scene, and it loads its height image with `Image.load_from_file` on a real file path, which
  probably fails inside an exported `.pck` (unconfirmed). It is editor-only (F6) as things stand.

### Goal
Drive a heavy tank (a physics body on 8 springs) by controlling its left and right treads separately, around a test course of
ramps from 5° to 55°, rolling bumps, mud and sand, a ledge strip, steps and a crest. Gentle
ramps (up to 20°) can be climbed from a standstill, 25° only with a run-up, and 30° and
steeper not at all. There is no win or lose condition, score or timer: it is a
driving prototype for the driver station of a planned co-operative tank crew game.

### Player controls
| Key | Action |
|---|---|
| `W` / `S` | Left tread one level up / down (levels 0.25, 0.5, 1 forward and back; stays where set) |
| `Up` / `Down` | Right tread one level up / down |
| Both treads forward / one tread / opposite treads | Straight / pivot round the idle tread / spin on the spot |
| `Space` (hold) | Brake: both levels to 0, stops the tank and holds it on slopes |
| `R` | Reset the tank to the reset point (default: the start) |
| `V` | Switch view: chase camera / driver's vision slit |
| `F11` | Full screen / window (starts full screen) |
| Ableton Push 3 (optional) | Pads: two lever columns each side (7 notches), 2×2 brake square in the middle (setup below) |

### Ableton Push 3 setup (optional)
The keyboard works on its own; this is only for a marker who has a Push 3.
1. Plug the Push 3 into the computer by USB and switch it on. No Ableton Live or drivers are
   needed. Close Ableton Live if it is open (on Windows a MIDI device can usually only be used
   by one program at a time; unconfirmed for the Push).
2. Start the game. The Push is found when the game starts: if it was plugged in later,
   restart the game. F3 shows whether the Push is connected.
3. Drive: press a pad in the left two columns to set the left tread (row 3 = stop, rows above
   = forward 0.25 / 0.5 / full, rows below = backwards); the right two columns set the right
   tread. A lever stays where you pressed. Hold the red 2×2 square in the middle to brake
   (it also sets both levers to stop).
4. Pad lights (optional, driving works without them): open `push_relay.html` (in the game's
   folder) in **Chrome or Edge**, press **Start** and allow MIDI. Keep the page open.
- If the Push is unplugged while driving, the game brakes for 3 s.
- Untested: a fresh Windows machine; a Push 3 in standalone mode (it may need to be switched to
  control mode, unconfirmed).

### Debugging controls
No control is limited to debug builds (the code never checks `OS.is_debug_build()`), so
everything in game below also works in an exported release build.

| Key / feature | What it does | Release build? |
|---|---|---|
| `F3` | Debug display: inputs, tread speeds, slope, grip, preset, knobs, climbable limit, phone/Push status; physics tank: probe diagram, pitch/roll | Yes (shown by default) |
| `Tab` | Tuning panel: live sliders for every driving, camera and terrain value; Copy values; Reset to saved; Reset point (any ramp, distance back 0–70 m, ledge strip, steps, crest); Reset now; Debug tank swap | Yes |
| Tab panel > Debug > "Swap to kinematic tank (old)" | Swap to the older kinematic tank (green) at the same spot, and back | Yes |
| `R` + Tab "Reset point" | Teleport to a chosen ramp or feature, at rest | Yes |
| Phone controller | Two on-screen levers and a BRAKE button (USB + adb, or Wi-Fi off by default). Still in the game, not documented for markers | Yes |
| Gamepad | Sticks drive the treads (never tested on a real gamepad) | Yes |
| Hold-to-drive mode | Untick `Use Tread Levels` on `DriverStation/KeyboardDriverInput` | Editor setting only |
| Test runner `tests/test_runner.tscn` | 210 automated checks, headless or watched (F6); `--only=<suites>` runs some suites | Editor / console only |
| Starter level `levels/starter/starter.tscn` | Painted-height level, run with F6 | Editor only |

### Credits
| Asset | Author | Licence |
|---|---|---|
| Godot Engine 4.6.3 (includes Jolt Physics) | Godot Engine contributors (Juan Linietsky, Ariel Manzur and contributors); Jolt by Jorrit Rouwe | MIT. **Needs attribution:** an exported game must include Godot's licence notice and its third-party notices (see Godot docs, "Complying with licenses") |
| Atkinson Hyperlegible font (used by `web/push_relay.html`, loaded from Google Fonts, not bundled) | Braille Institute of America | SIL Open Font License 1.1. **Credit it** (the relay page ships with the build for the Push lights) |
| `web/push_relay.html` | Copied from the developer's own finger-walking game | Own work |
| Android Platform Tools (`adb`) | Google | Not bundled: the user downloads it (Android SDK licence terms). Credit as a required tool, not an asset |
| Everything else (meshes, shaders, course, height image, phone page) | Made in this project (primitive meshes, code-built course; height image made by `tools/generate_starter_heightmap.gd`) | Own work |

No other third-party assets or addons (CLAUDE.md: "No addons, no downloaded assets").

---

## 2. Initial design vs final product

**Earliest design:** `TANK_PLAN.md`, uploaded 2026-10-21 17:18 (commit `1e3cdd5`), deleted
2026-10-22 (`ec5a114`, still in git history). It planned the first playable foundation of a
co-operative crew tank game (driver, gunner, engineer; big custom controllers; separate screens
or vision slits), building **driving only**: independent treads, a "Slope Ladder" of ramps
(5–55°) where momentum decides mid-steep climbs, a kinematic `CharacterBody3D` tank ("Do not use
`RigidBody3D` or simulated suspension"), 8 tunables in one `TankTuning` resource, keyboard and
gamepad input through a `DriverStation`, chase and vision-slit cameras, an F3 debug HUD and a
headless test runner, in 7 milestones. Built as planned on 2026-10-21 (`2fc0209`…`565f4c2`);
the slope targets were all met.

Later plans added: `PHONE_CONTROLLER_PLAN.md` (`eb91bc6`), `KINEMATIC_TUNING_PLAN.md` and
`PHYSICS_COMPARISON_PLAN.md` (in history by `eebf8f3`). All four deleted in `ec5a114`; reason: ask the user.

| # | Planned | Built | When | Reason |
|---|---|---|---|---|
| 1 | Analogue tread input (hold `W`/`S`, stick Y) | Notched levers: each key press steps a level and it stays; levels later set to 0.25 / 0.5 / 1 | `95abca3` (21 Oct); levels `ea53bb4` (21 Oct) | NOTES: "Keyboard tread levels (developer's idea)"; levels "developer's design". Why: ask the user |
| 2 | Reset `R` only; no brake | Hold-Space brake (and phone/Push brake buttons); level 0 = engine idling with "idle drag" | Space "all stop" `95abca3`; brake + idle drag `ea53bb4` (21 Oct) | Idle drag quoted: "a lever at 0 at speed barely turned the tank (1° in 2 s), because that tread freewheeled; the developer's instinct (an unpowered tread should be dragged, making a slow pivot) led to idle drag." Separate brake: ask the user |
| 3 | Box or simple collision implied | Capsule (round) collision shape | `8dc00d1` (21 Oct) | NOTES: "an upright box on a 35° slope rests on its edge with its centre ~1.7 m above the surface, so the tilted hull would float." |
| 4 | `turn_resistance` tuned to targets | Raised 0.4 → 0.75; later turn scrub added | `8dc00d1`; `ea53bb4` | NOTES: "because spinning was ~230°/s". Turn scrub: ask the user |
| 5 | Every ramp has a flat landing on top | Ramps alternate "ledge" / "no ledge" (sharp crest), read from a text file | `73b6121` (21 Oct) | NOTES: "alternate by default (developer's idea)". Why: ask the user |
| 6 | 8 tunables edited in the Inspector | In-game Tab tuning panel (live, session-only), plus many new values (engine power fade, warm-up, air/landing, turn scrub, terrain) | `23063df`, `b55aa65`, `c0e4262`, `ea53bb4` (21 Oct) | Session-only: "developer's choice, over saving into the .tres"; engine power: "developer's request". Why a panel: ask the user |
| 7 | Not planned | Terrain: mud and sand patches and ramps | `b8f77f3` (21 Oct) | Ask the user |
| 8 | Not planned | Level builder: ground from a painted height image, starter level | `b0b0b1a` (21 Oct) | Ask the user (NOTES refers to a "level plan step 1 / 2a" that is not in the repo) |
| 9 | Keyboard + gamepad only (custom hardware "later") | Phone controller (web page, Wi-Fi then USB) and Ableton Push 3 pads | Phone `6744cfe`…`e5e32bb` (21 Oct); Push `05492d2` (22 Oct) | USB: "developer's choice, because Windows Firewall needs admin rights to let Godot onto the network on this laptop". Phone and Push themselves: ask the user |
| 10 | Gamepad as a main input | Gamepad kept but untested; no gamepad brake | `ea53bb4` | Hand-off doc: "the developer will never use one". Why: ask the user |
| 11 | 8 raw tunables | Six "feel knobs" (weight, top speed, pulling power, grip in degrees, sideways grip, tippiness) on top, old values under "Advanced"; three presets on 1/2/3 | `7e2fd5f`…`ebdf5cf` (21 Oct) | Physics plan: "The developer finds many tuning variables hard to manage, so simplicity of tuning is a hard requirement" |
| 12 | "Do not use `RigidBody3D` or simulated suspension" | A second, physics tank on 8 spring probes, swappable with `T`; ledge strip, steps and crest added | `cad8dd8`…`2b57a7d` (21 Oct) | Physics plan: "The kinematic tank samples the ground at roughly one point, so it cannot lurch when one tread drops off a ledge, and it snaps between slope angles instead of easing onto an incline." |
| 13 | Six knobs only | Physics tank's knob section grew to 10 (warm-up, throttle response, idle drag, turning heaviness) | `9cdf93c`, `c79b3e0` (22 Oct) | NOTES: "The developer wants the feel-knob section to grow into 'the variables I find most important', not stay at six"; "They were Advanced only because the plan said 'six knobs'; all three are tuned by feel." |
| 14 | Push brake not planned | Brake square 4×4, then 2×2 | `05492d2` → `98798f3` (22 Oct) | NOTES: "at the developer's request". Why: ask the user |
| 15 | Slope targets (one tank): 30°–35° climb with a run-up, 45°+ never | Kinematic tank meets them. Physics tank at weight 1 failed 35°–40° with a run-up (loses ~4 m/s lifting its nose onto the slope, physics design doc §8); the chosen Heavy physics tank climbs 20° standing and 25° with a run-up, 30°+ fail | `39ce6f2` (21 Oct); Heavy 2026-10-30 | Developer: run-up shortfall "fine, leave it". Heavy's lower limits: ask the user |
| 16 | Multiple stations (gunner, engineer), separate screens | Not built (driving only, as planned for this build) | n/a | Plan: "This build covers only driving" |
| 17 | Two tanks to compare, three presets (heavy / nimble / slippery), T to swap | The physics tank with the Heavy values is the game's tank; presets and keys 1/2/3 removed; T removed, the kinematic tank kept as a Tab panel debug option marked "(old)" | 2026-10-30 (this commit) | Developer: "this one is the best and the one I've decided on" |

---

## 3. Work not in the final build

Started or built, but off, unreachable or unfinished in the game as shipped:
- **Starter level** (to be replaced by a new level): (`scripts/level_terrain.gd`, `level_root.gd`,
  `level_start.gd`, `levels/starter/`, `tools/generate_starter_heightmap.gd`,
  `docs/making_levels.md`): works in the editor (F6) only; not reachable from the main scene;
  probably can't load its image in an export.
- **Kinematic tank:** replaced by the physics tank as the game's tank (2026-10-30); still in the
  build as a Tab panel debug option, marked "(old)".
- **Feel presets** (heavy, nimble, slippery, keys 1/2/3): removed 2026-10-30; Heavy's values
  became the physics tank's saved tuning. The preset files are in git history
  (`tuning/presets/*.tres` at commit `a7059d3`).
- **Gamepad input:** built, never tested on hardware.
- **Ableton Push 3:** built and tested only with pretend MIDI; light colours never seen on a
  real Push; unplug detection on Windows unconfirmed.
- **Phone controller:** built and confirmed on a real phone, but not documented for markers
  (developer: mobile controls are "too annoying"). Wi-Fi mode off by default.
- **Hold-to-drive keyboard mode:** built, off by default.
- **Values built but off by default:** air gravity, nose dip, landing speed loss, engine power
  fade, kinematic warm-up, physics warm-up.
- **Planned, not built:** gunner and engineer stations; separate screens per camera
  (`SubViewport`); ice, road and shallow-water terrain; camera shake / landing thump; QR code for
  the phone URL ("no addon-free way").
- **For the "unused assets" zip:** the preset files from git history, `levels/starter/` (scene + `height.png`),
  `tools/generate_starter_heightmap.gd`, `docs/making_levels.md`. Design documents (`docs/*.md`, the four deleted plans from git history,
  `docs/tuning_settings.csv` / `.xlsx`) are supporting material rather than assets.
- **Not for any zip:** `docs/~$tuning_settings.xlsx` is an Excel lock file committed by
  accident (`ec5a114`); `tests/last_results.txt` and `.godot/` are generated.

---

## 4. How it was made

- **Engine:** Godot 4.6.3 stable, GDScript with static typing, Forward+ renderer, Jolt physics
  at 60 Hz. No addons, no downloaded assets; primitive meshes only.
- **Development:** with Claude (Anthropic's AI coding assistant): 41 of 43 commits carry a
  "Co-Authored-By: Claude" line (all but the two initial uploads). Design was discussed before
  code, in small play-testable steps (CLAUDE.md "How to work with me"); two branches were built
  by Claude working alone overnight from a hand-off document (`docs/handoff_overnight_tuning_and_physics.md`).
- **Version control:** git + GitHub (`Kickpunch3r/tank-game`, private). 43 commits on the
  newest branch, from 2026-10-21 17:18 to 2026-10-22 11:41 (+11:00). Branches: `main`,
  `phone-controller`, `kinematic-tuning`, `physics-tank`, `push-controller` (newest; each
  built on the one before). **`main` stops at `eebf8f3` (21 Oct)**: the later branches are not
  merged.
- **Testing:**
  - Automated headless test runner (`tests/test_runner.tscn`), driving tanks by writing into
    their `DriverStation`. Grew from 42 checks (milestone 5) to **210 checks, all passing**
    (2026-10-30). Covers input, views/HUD, tuning panel, starting tank, tank swap, phone
    (local ports, pretend adb), Push 3 (pretend MIDI), course shape, flat driving, every ramp
    standing and with a run-up for both tanks (physics: 3 runs, majority), brake/idle/warm-up/
    turning, terrain, level builder, stability and a settings-spreadsheet consistency check.
  - Default-parity test: the six-knob tuning reproduces the original slope table exactly.
  - Play-testing by hand on the test course; phone controller confirmed on a real phone over
    USB (`e5e32bb`: "works great").
- **Milestones in order** (all 2026-10-21 unless marked):
  1. Skeleton (`2fc0209`) 2. Input stations (`2bcbb0f`) 3. Movement model (`8dc00d1`) +
  keyboard levels (`95abca3`) 4. Slope Ladder (`73b6121`) 5. Tests (`bac0327`) 6. Slit camera
  and HUD (`53da248`) 7. Docs (`565f4c2`) 8. Tuning panel (`23063df`) 9. Engine power
  (`b55aa65`) 10. Terrain (`b8f77f3`) 11. Panel typing (`c0e4262`) 12. Level builder
  (`b0b0b1a`) 13. Cliff-bounce fix, full screen (`77eeef0`) 14. Phone controller
  (`6744cfe`–`69cd0ee`) 15. Phone over USB (`1381ca8`) 16. Real-phone test (`e5e32bb`)
  17. Brake, idling, levels, warm-up, turn scrub (`ea53bb4`) 18. Feel knobs and presets
  (`7e2fd5f`–`ebdf5cf`) 19. Physics tank (`cad8dd8`–`2b57a7d`) 20. Push 3 controller (22 Oct,
  `05492d2`, `98798f3`) 21. Physics feel knobs and settings spreadsheet (22 Oct, `9cdf93c`,
  `c79b3e0`, `ec5a114`).

---

## 5. Questions for you

Answered on 2026-10-30: the game uses the physics tank with the Heavy values; presets removed;
the kinematic tank stays as a debug option marked "(old)"; the 35°–40° run-up shortfall stays;
both games are submitted as prototypes (teacher approved); markers will use a keyboard, the
Push 3 is optional and the phone isn't documented for them; a new level will replace the
starter level; the Excel lock file stays.

Still open (for the report):
1. Name and student ID for the readme? (Git commits use `102571715@student.swin.edu.au`; is
   102571715 your ID?)
2. Project name for the readme: "Tank Game", or something else?
3. Why did you make each change marked "ask the user" in section 2 (notched levels, separate
   brake, ledge/no-ledge ramps, the tuning panel, terrain, level builder, phone, Push 3, 2×2
   brake, deleting the old plans, Heavy's lower climbing limits)?
4. Is there a level plan document? NOTES mentions "level plan step 1 / 2a", but none is in git.
5. Did anyone else play-test it? Any notes for the optional play-testing document?
