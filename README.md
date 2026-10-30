# Tank Game

The first playable foundation of a co-operative tank crew game, for a large physical
installation where several players run different stations of one tank (driver, gunner,
engineer). This build covers **driving only**: steering by two independent treads, on a test
course of slopes where steep ones can only be climbed with a run-up.

Built with **Godot 4.6.3** (GDScript). No addons or downloaded assets.

## Running the game
1. Start Godot: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe`.
2. Open (or Import) this folder's `project.godot`.
3. Press **Play** (F5). The game starts in the **Proving Ground** level
   (`levels/proving_ground/proving_ground.tscn`).

The ramps, the course pieces and the route markers are built when the game starts, so they only
appear after pressing Play, not in the editor viewport.

**The Proving Ground:** you start facing north on a road. The **test area** (ramps 5°–55°, ledge
strip, steps, crest, a mud and a sand square) is just to your right. The road leads to a fork:
the **high route** (orange posts, west) climbs onto a ridge and runs along a sandy ledge above a
cliff and a lake; the **low route** (blue posts) goes through a mud basin, across a river at a
shallow ford and over sand dunes. Both end at the **goal** plateau in the north, marked by a
big turning gold cube. The mountains,
the cliffs, the steep cone hill, the mesa and the river's deep water can't be driven through.

**The old test course** (`scenes/test_course.tscn`, open it and press F6) is still there for
development.

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
| `F11` | Full screen / window (the game starts full screen) |

- **Levels:** each tread has 3 levels forward and 3 back: **0.25, 0.5 and full** (the phone's
  levers use the same notches).
- **Throttle bars** (bottom-left = left tread, bottom-right = right tread) show each lever's
  notch: green forward, blue back, white at stop, red **BRAKE**. The top notch is **TURBO**
  (orange, with flickering flames when engaged). It is the full level as before: it looks
  special but pushes no harder. The bars show in the slit view too.
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
  - **Debug:** "Show test labels" shows the floating labels on the test ramps and course
    pieces (hidden at the start), and "Swap to kinematic tank (old)".
- **Terrain (mud, sand):** each terrain is a file in `terrain/` (`mud.tres`, `sand.tres`) with
  grip, drag, top speed and sink depth; click it to edit, or use the Tab panel. To add a patch
  of terrain to a scene, add a `TerrainPatch` node, give it a terrain and a size, and move,
  turn or tilt it into place (it shows in the editor). Ramps can have terrain too: add the
  terrain name at the end of a line in a ramp list, e.g. `20  no ledge  mud`
  (`levels/terrain_ramps.txt`).
- **How the tank drives:** click `tuning/physics_tank_tuning.tres` (the physics tank, the one
  the game uses) and change values in the Inspector: its feel knobs first, then "Advanced"
  (springs, centre of mass). Its saved values are the chosen **Heavy** tank (weight 2, top
  speed 8, pulling power 8, grip 30°, sideways grip 1, tippiness 0.25).
- **The old kinematic tank:** `tuning/tank_tuning.tres` (same six knobs, then "Advanced").
- **The ramps:** edit `levels/slope_ladder.txt` (any text editor), one line per ramp, like
  `25  ledge` or `30  no ledge`. Save and press Play.
- **Ramp size and spacing:** select the `SlopeLadder` node in `scenes/test_course.tscn`.
- **The slit:** select `Visual/Hull/DriverSlitCamera` in `scenes/tank.tscn` for slit height,
  edge thickness and colours.
- **Tank art:** the tank's meshes are under `Visual/Hull/Sway` in `scenes/tank.tscn` (that node
  does the tippiness rocking; the slit camera is outside it so it never rocks). The physics
  tank's meshes are under `Visual/Hull` in `scenes/physics_tank.tscn` (its whole body tilts).

## How to tune (the six feel knobs)
Every setting, with what it does and what raising or lowering it does, is in the spreadsheet
[docs/tuning_settings.csv](docs/tuning_settings.csv) (opens in Excel, Google Sheets or LibreOffice).

| Knob | What it does |
|---|---|
| `weight` | How heavy it feels (1 = normal, 2 = twice as heavy): slower to speed up, brake and turn, coasts further, hull follows the ground more lazily |
| `top_speed` | Top speed in m/s (10 = 36 km/h). Also how far a run-up carries it up a steep slope |
| `pulling_power` | How hard the treads push (and brake). The real push is pulling power ÷ weight |
| `grip` | The steepest slope (degrees) it can hold, or climb from a standstill |
| `sideways_grip` | 1 = no sliding in turns; lower = it drifts outward in turns at speed |
| `tippiness` | 0 = rigid hull, 1 = the hull rocks back, dips and leans a lot (looks only) |
| `warm_up_time` | **Physics tank only, in its feel knobs:** seconds for each tread's push to build up from nothing to full when you ask for more power (0 = instant). Never delays the brake. (The kinematic tank has the same setting under Advanced.) |

1. Change **one knob at a time** (Tab panel, or the Inspector to keep it).
2. Watch the **F3 display**: it shows the six knobs, the slope you can
   climb from a standstill (grip, or the engine if that's weaker) and the sideways slide.
3. Try it on the **ramps** (Tab panel "Reset point" puts you at any ramp, with or without a
   run-up), then run the tests: the report has the slope table for the saved tuning.
4. Happy with it? **Copy values** and type them into `tuning/physics_tank_tuning.tres`.

## The two tanks
The game uses the **physics** tank (blue-grey: a real physics body on 8 springs, so it rocks,
tips off ledges and has to lift its nose onto slopes), tuned as the **Heavy** tank. It climbs
up to 20° from a standstill and 25° with a run-up; 30° and steeper fail.

The older **kinematic** tank (green, rules-based) is kept for comparison: the Tab panel's
**Debug** section has **Swap to kinematic tank (old)** (and a button to swap back). It appears
at the same spot; both use exactly the same controls. The F3 display says which one is active.

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
  the phone. They work with both tanks.
- **Lights need the relay page:** Godot can't send MIDI, so open `web/push_relay.html` in
  **Chrome or Edge**, press **Start** and allow MIDI. Keep it open while you play. (Same page as
  the finger-walking game; if that game is running too, close it, as both use port 9080.)
- If the Push is unplugged while driving, its levers go to 0 and the game brakes for 3 s.
- F3 shows the Push's status: connected or not, its lever levels, and whether the relay page is
  connected.
- **Colours** are Push palette numbers on the `PlayerRig/PushLightSender` node (Inspector). The
  relay page's "Show colours" buttons light every palette colour so you can pick.

## Levels
- **Proving Ground** (main scene): `levels/proving_ground/` has `height.png` (heights) and
  `terrain.png` (red = mud, yellow = sand); edit either in Photoshop. See the guide below.
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
- Takes about two minutes (the physics tank's slope tests run 3 times each, and the Proving
  Ground's routes are driven end to end). Prints a results table, including every ramp from a standing start and
  with a run-up, and saves it to `tests/last_results.txt`.
- Exit code 0 = everything passed, 1 = something failed.
- **To watch the tests:** open `tests/test_runner.tscn` in the editor and press **F6**.

## Folders

| Folder | Contents |
|---|---|
| `scenes/` | `test_course.tscn` (main scene), `physics_tank.tscn`, `tank.tscn` (old kinematic tank), `player_rig.tscn` (both tanks + cameras + debug display + Tab panel, shared by every level) |
| `levels/<name>/` | A level: `height.png` (and optional `terrain.png`) and its scene (`levels/proving_ground/` is the main scene) |
| `tools/` | Helper scripts, e.g. the one that generated the starter height map |
| `scripts/net/` | Phone controller: servers, station registry, phone input |
| `web/` | `controller.html`: the page phones open (one self-contained file) |
| `scripts/` | Game scripts: tank, treads, stations, inputs, cameras, course builders, HUD |
| `tuning/` | `physics_tank_tuning.tres` (the game's tank) and `tank_tuning.tres` (old kinematic tank): all driving numbers |
| `levels/` | Ramp lists: `slope_ladder.txt` (firm ramps), `terrain_ramps.txt` (sand and mud ramps) |
| `terrain/` | Terrain types: `mud.tres`, `sand.tres` |
| `art/` | Shaders and (later) models and sprites |
| `tests/` | Automated test runner and test suites |
| `docs/` | Design documents |

More detail (architecture, decisions, test results, known issues, things to check by hand) is
in [NOTES.md](NOTES.md).
