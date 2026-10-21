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
| `W` / `S` | Left tread one level up / down (levels −3 to +3, stays set) |
| `Up` / `Down` | Right tread one level up / down |
| `Space` | All stop: both treads to level 0 (the tank glides to a halt) |
| `R` | Reset the tank to the start |
| `V` | Switch view: chase camera / driver's vision slit |
| `F3` | Hide / show the debug display |
| `Tab` | Open / close the tuning panel (use the mouse on it) |
| `F11` | Full screen / window (the game starts full screen) |

- Driving: both treads forward = straight ahead. Left tread only = turn right. Opposite
  treads = spin on the spot.
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
- **The ramps:** edit `levels/slope_ladder.txt` (any text editor), one line per ramp, like
  `25  ledge` or `30  no ledge`. Save and press Play.
- **Ramp size and spacing:** select the `SlopeLadder` node in `scenes/test_course.tscn`.
- **The slit:** select `Visual/Hull/DriverSlitCamera` in `scenes/tank.tscn` for slit height,
  edge thickness and colours.

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
- Levers spring back to 0 when you let go. **Settings** on the phone switches to "stay where
  left", turns vibration off, or goes full screen.
- The first phone to connect drives; other phones watch until the driver leaves.
- While a phone is driving, it overrides the keyboard and gamepad. If the phone goes quiet for a
  quarter of a second (cable pulled, Wi-Fi drops, phone locks), the tank stops and the keyboard
  works again.
- Android phones buzz when a lever crosses 0 and when the tank hits a wall (iPhones don't vibrate
  from web pages).
- The phone screen may lock while driving: raise the phone's auto-lock time.

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
- Takes a few seconds. Prints a results table, including every ramp from a standing start and
  with a run-up, and saves it to `tests/last_results.txt`.
- Exit code 0 = everything passed, 1 = something failed.
- **To watch the tests:** open `tests/test_runner.tscn` in the editor and press **F6**.

## Folders

| Folder | Contents |
|---|---|
| `scenes/` | `test_course.tscn` (main scene), `tank.tscn`, `player_rig.tscn` (tank + cameras + debug display + Tab panel, shared by every level) |
| `levels/<name>/` | A level: `height.png` and its scene (e.g. `levels/starter/`) |
| `tools/` | Helper scripts, e.g. the one that generated the starter height map |
| `scripts/net/` | Phone controller: servers, station registry, phone input |
| `web/` | `controller.html`: the page phones open (one self-contained file) |
| `scripts/` | Game scripts: tank, treads, stations, inputs, cameras, course builders, HUD |
| `tuning/` | `tank_tuning.tres`: all driving numbers |
| `levels/` | Ramp lists: `slope_ladder.txt` (firm ramps), `terrain_ramps.txt` (sand and mud ramps) |
| `terrain/` | Terrain types: `mud.tres`, `sand.tres` |
| `art/` | Shaders and (later) models and sprites |
| `tests/` | Automated test runner and test suites |
| `docs/` | Design documents |

More detail (architecture, decisions, test results, known issues, things to check by hand) is
in [NOTES.md](NOTES.md). The original build plan is [TANK_PLAN.md](TANK_PLAN.md).
