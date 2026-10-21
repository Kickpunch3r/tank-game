# Tank Game

The first playable foundation of a co-operative tank crew game, for a large physical
installation where several players run different stations of one tank (driver, gunner,
engineer). This build covers **driving only**: steering by two independent treads, on a test
course of slopes where steep ones can only be climbed with a run-up.

Built with **Godot 4.6.3** (GDScript). No addons or downloaded assets.

## Running the game
1. Start Godot: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe`.
2. Open (or Import) this folder's `project.godot`.
3. Press **Play** (F5). The test course is the main scene.

The ground, ramps and hills are built when the game starts, so they only appear after
pressing Play, not in the editor viewport.

## Controls

| Key | What it does |
|---|---|
| `W` / `S` | Left tread one level up / down (stays set) |
| `Up` / `Down` | Right tread one level up / down |
| `Space` (hold) | **Brake**: both levels to 0, stops the tank, holds it still on slopes |
| `R` | Reset the tank to the start |
| `V` | Switch view: chase camera / driver's vision slit |
| `F3` | Hide / show the debug display |
| `Tab` | Open / close the tuning panel (use the mouse on it) |
| `1` / `2` / `3` | Feel preset: heavy / nimble / slippery (until you quit; Tab panel "Reset to saved" goes back) |
| `T` | Swap tank: kinematic (green) / physics (blue-grey), at the same place |
| `F11` | Full screen / window (the game starts full screen) |

- **Levels:** each tread has 3 levels forward and 3 back: **0.25, 0.5 and full** (the phone's
  levers use the same notches).
- **Level 0 = engine idling:** that tread doesn't push and is held back by **Idle Drag**, so it
  slows by itself. With both levers at 0 the tank stops in about 3 s. On slopes steeper than
  about 18° it rolls back unless you **brake**.
- Driving: both treads forward = straight ahead. Left tread only = a slow, heavy pivot to the
  right round the idle tread. Opposite treads = spin on the spot (slow and heavy). Turning
  always costs speed (**Turn Scrub**); driving straight doesn't.
- **Hold-to-drive instead of levels:** in `scenes/tank.tscn`, select
  `DriverStation/KeyboardDriverInput` and untick **Use Tread Levels**.
- **Gamepad** (untested on real hardware): left stick up/down = left tread, right stick
  up/down = right tread, Back/Select = reset.
- All keys can be changed in **Project > Project Settings > Input Map** (actions starting
  with `driver_`, plus `view_toggle` and `debug_hud_toggle`).

## Changing things
- **While playing: the tuning panel (Tab).** Sliders for every driving value, the new air and
  landing values (air gravity, nose dip, landing speed loss), the chase camera and the slit
  height. Drag a slider, or click the box beside it, type an exact value and press Enter (or
  click elsewhere). Typed values are used exactly and can go past the slider's ends (it stretches); only a few values have hard limits where the maths needs them (e.g. turn resistance 0 to 1). While
  typing, keys go to the box, not the tank. The mouse wheel scrolls the panel and never
  changes a value. Changes take effect immediately but **only last until you quit**:
  - **Copy values** puts the current numbers on the clipboard (and in the Output panel),
    grouped by where each one lives, so you can type them into the Inspector or paste them to
    Claude to make them permanent.
  - **Reset to saved** puts every slider back to how the game started.
  - **Reset point** chooses where `R` puts you: "Start field", or in front of any ramp, with a
    **Distance back** slider from 0 m (touching the ramp, at rest) to 70 m (full run-up).
    **Reset now** goes there straight away.
- **Terrain (mud, sand):** each terrain is a file in `terrain/` (`mud.tres`, `sand.tres`) with
  grip, drag, top speed and sink depth; click it to edit, or use the Tab panel. To add a patch
  of terrain to a scene, add a `TerrainPatch` node, give it a terrain and a size, and move,
  turn or tilt it into place (it shows in the editor). Ramps can have terrain too: add the
  terrain name at the end of a line in a ramp list, e.g. `20  no ledge  mud`
  (`levels/terrain_ramps.txt`).
- **How the tank drives:** click `tuning/tank_tuning.tres` and change values in the
  Inspector. Each value is explained in plain language there (from `scripts/tank_tuning.gd`).
  The first six are the **feel knobs** (below); the rest are "Advanced".
- **Feel presets:** `tuning/presets/heavy.tres`, `nimble.tres`, `slippery.tres` hold just the
  six knobs. Click one to change it; keys 1/2/3 put it on both tanks while driving.
- **How the physics tank drives:** `tuning/physics_tank_tuning.tres`: the same six knobs, then
  its own "Advanced" values (springs, centre of mass, sideways hold).
- **The ramps:** edit `levels/slope_ladder.txt` (any text editor), one line per ramp, like
  `25  ledge` or `30  no ledge`. Save and press Play.
- **Ramp size and spacing:** select the `SlopeLadder` node in `scenes/test_course.tscn`.
- **The slit:** select `Visual/Hull/DriverSlitCamera` in `scenes/tank.tscn` for slit height,
  edge thickness and colours.
- **Tank art:** the tank's meshes are under `Visual/Hull/Sway` in `scenes/tank.tscn` (that node
  does the tippiness rocking; the slit camera is outside it so it never rocks). The physics
  tank's meshes are under `Visual/Hull` in `scenes/physics_tank.tscn` (its whole body tilts).

## How to tune (the six feel knobs)
| Knob | What it does |
|---|---|
| `weight` | How heavy it feels (1 = normal, 2 = twice as heavy): slower to speed up, brake and turn, coasts further, hull follows the ground more lazily |
| `top_speed` | Top speed in m/s (10 = 36 km/h). Also how far a run-up carries it up a steep slope |
| `pulling_power` | How hard the treads push (and brake). The real push is pulling power ÷ weight |
| `grip` | The steepest slope (degrees) it can hold, or climb from a standstill |
| `sideways_grip` | 1 = no sliding in turns; lower = it drifts outward in turns at speed |
| `tippiness` | 0 = rigid hull, 1 = the hull rocks back, dips and leans a lot (looks only) |

1. Change **one knob at a time** (Tab panel, or the Inspector to keep it).
2. Watch the **F3 display**: it shows the six knobs, the preset they match, the slope you can
   climb from a standstill (grip, or the engine if that's weaker) and the sideways slide.
3. Try it on the **ramps** (Tab panel "Reset point" puts you at any ramp, with or without a
   run-up), then run the tests: the report has the slope table for the saved tuning and for
   each preset.
4. Happy with it? **Copy values** and type them into `tuning/tank_tuning.tres` (or a preset).

## Comparing the two tanks
There are two tanks: the **kinematic** tank (green, rules-based: what the game has always used)
and the **physics** tank (blue-grey: a real physics body on 8 springs, so it rocks, tips off
ledges and has to lift its nose onto slopes). **T** swaps between them at the same spot; both
use exactly the same controls (keyboard, phone, brake). The F3 display says which one is active.
The six feel knobs and the presets mean the same in both.

What to try (Tab panel "Reset point" takes you to each place):
1. Climb the **30°** ramp from a standstill and with a run-up (Distance back 70), in each tank.
2. Drive along the **ledge strip** with one tread over the edge (start "Ledge strip", climb
   the little ramp, steer right until a tread hangs over).
3. **Spin on the spot** on a slope (e.g. stop half-way up 20°, opposite levers).
4. Drive over the **steps** and the **crest**.
5. Try each **preset** (1/2/3) in each tank.

## Phone controller
Drive the tank from a phone with two on-screen tread levers. The game hosts the page itself.
The bottom-left of the screen always says how to connect and what's happening.

### By USB cable (Android, works on this laptop)
On this laptop Windows won't let Godot onto the network (that needs admin rights), so the phone
connects through a USB cable instead, using Google's `adb` tool. The game runs adb for you.

**One-time setup (about 15 minutes):**
1. **Phone:** Settings > About phone > tap **Build number** 7 times (unlocks Developer options).
   Then Settings > (System >) **Developer options** > turn on **USB debugging**.
2. **Laptop:** download "SDK Platform-Tools for Windows" from
   `developer.android.com/tools/releases/platform-tools` and unzip it into **Documents**, so
   you have `Documents\platform-tools\adb.exe`. Nothing is installed.
3. Plug the phone in with a USB cable that carries data (some cables only charge). The phone
   asks **"Allow USB debugging?"**: tick "Always allow from this computer" and tap **Allow**.

**Each time:** start the game, plug the phone in, wait until the bottom-left says
**"USB phone: ready"**, then open **`http://localhost:8080`** in the phone's browser (Chrome)
and turn the phone sideways. Re-plugging is fine; the game notices within a few seconds.

What the bottom-left line means:
- *adb not found*: platform-tools isn't in Documents (or set **Adb Path** on the
  `PlayerRig/UsbPhoneLink` node to wherever `adb.exe` is).
- *plug in an Android phone*: no phone found. Check the cable carries data and USB debugging is on.
  If the phone is plugged in and it still says this, Windows may need a USB driver for that phone
  (which needs admin rights): try another phone if you can.
- *tap "Allow" on the phone*: the phone is waiting for you to allow USB debugging.
- *ready*: open `http://localhost:8080` on the phone.

iPhones can't connect by USB this way.

### By Wi-Fi (on a computer where Godot is allowed onto the network)
1. Select `PlayerRig/ControllerServer` (in `scenes/player_rig.tscn`) and tick **Allow Wifi Phones**.
2. Phone and computer on the same network. eduroam, library and most public Wi-Fi block devices
   from talking to each other: use a private router or a hotspot.
3. Start the game; the bottom-left shows the address to open on the phone (e.g.
   `http://192.168.137.1:8080`).
4. First time: allow Godot through Windows Firewall on **private** networks (needs admin rights).

Using it:
- Left lever = left tread, right lever = right tread. Both thumbs work at once.
- Each lever has **7 notches** (full back, 0.5 back, 0.25 back, 0, 0.25, 0.5, full): it snaps
  to the nearest, buzzes as it clicks into each one (a longer buzz at 0), and **stays where you
  leave it**.
- **BRAKE** (the big red button in the middle): hold to brake; pressing it also puts both
  levers back to 0.
- **Settings** on the phone: turn on "spring back to 0", turn vibration off, or go full screen.
- The first phone to connect drives; other phones watch until the driver leaves.
- While a phone is driving, it overrides the keyboard and gamepad. If the phone goes quiet for a
  quarter of a second (cable pulled, Wi-Fi drops, phone locks), the game **brakes for 3 seconds**
  so the tank stops, then the keyboard works again.
- Android phones buzz when a lever crosses 0 and when the tank hits a wall (iPhones don't vibrate
  from web pages).
- The phone screen may lock while driving: raise the phone's auto-lock time.

## Ableton Push 3 controller
Drive with the Push 3's pads, laid out like the phone: two lit levers and a red brake square.
No Ableton Live or drivers needed; plug the Push in by USB and switch it on.

```
row 7   .  .  .  .  .  .  .  .     (free, for later)
row 6   L  L  .  .  .  .  R  R     full forward
row 5   L  L  .  .  .  .  R  R     0.5 forward
row 4   L  L  .  B  B  .  R  R     0.25 forward
row 3   L  L  .  B  B  .  R  R     0 (stop)
row 2   L  L  .  .  .  .  R  R     0.25 back
row 1   L  L  .  .  .  .  R  R     0.5 back
row 0   L  L  .  .  .  .  R  R     full back
```

- **Levers** (two columns each side): press a pad to put the lever there; it stays when you let
  go. Each lever's lit pad is where it is (green forward, blue backwards, white at 0); the other
  notches are dim, the middle (0) a little brighter.
- **Brake** (the red 2 x 2 square in the middle): hold any of its pads to brake; pressing it also puts both levers to 0. The
  square lights white while braking.
- The lights show what the tank is actually being told, so they also follow the keyboard and
  the phone. They work with both tanks (T).
- **Lights need the relay page:** Godot can't send MIDI, so open `web/push_relay.html` in
  **Chrome or Edge**, press **Start** and allow MIDI. Keep it open while you play. (Same page as
  the finger-walking game; if that game is running too, close it, as both use port 9080.)
- If the Push is unplugged while driving, its levers go to 0 and the game brakes for 3 s.
- F3 shows the Push's status: connected or not, its lever levels, and whether the relay page is
  connected.
- **Colours** are Push palette numbers on the `PlayerRig/PushLightSender` node (Inspector). The
  relay page's "Show colours" buttons light every palette colour so you can pick.

## Levels
- **Starter level:** open `levels/starter/starter.tscn` and press **F6** (Run Current Scene).
  It is built from `levels/starter/height.png` and has mountains round the edge, a flat start
  with a strip running north, a ridge with a pass, rolling hills, a mesa with 15°/25°/35°/cliff
  sides, a shallow basin and dunes.
- **Making your own:** paint a greyscale height image in Photoshop and point a level scene at
  it. Step-by-step guide: [docs/making_levels.md](docs/making_levels.md).
- In a level, the Tab panel has a **Level ground** section (size, max height, smoothing) that
  rebuilds the ground live.

## Running the tests
```bash
"C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn
```
- Takes about a minute (the physics tank's slope tests run 3 times each). Prints a results table, including every ramp from a standing start and
  with a run-up, and saves it to `tests/last_results.txt`.
- Exit code 0 = everything passed, 1 = something failed.
- **To watch the tests:** open `tests/test_runner.tscn` in the editor and press **F6**.

## Folders

| Folder | Contents |
|---|---|
| `scenes/` | `test_course.tscn` (main scene), `tank.tscn` (kinematic), `physics_tank.tscn`, `player_rig.tscn` (both tanks + cameras + debug display + Tab panel, shared by every level) |
| `levels/<name>/` | A level: `height.png` and its scene (e.g. `levels/starter/`) |
| `tools/` | Helper scripts, e.g. the one that generated the starter height map |
| `scripts/net/` | Phone controller: servers, station registry, phone input |
| `web/` | `controller.html`: the page phones open (one self-contained file) |
| `scripts/` | Game scripts: tank, treads, stations, inputs, cameras, course builders, HUD |
| `tuning/` | `tank_tuning.tres` and `physics_tank_tuning.tres`: all driving numbers; `presets/`: heavy, nimble, slippery |
| `levels/` | Ramp lists: `slope_ladder.txt` (firm ramps), `terrain_ramps.txt` (sand and mud ramps) |
| `terrain/` | Terrain types: `mud.tres`, `sand.tres` |
| `art/` | Shaders and (later) models and sprites |
| `tests/` | Automated test runner and test suites |
| `docs/` | Design documents |

More detail (architecture, decisions, test results, known issues, things to check by hand) is
in [NOTES.md](NOTES.md). The original build plan is [TANK_PLAN.md](TANK_PLAN.md).
