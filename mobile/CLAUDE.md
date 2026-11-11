# Little Tank: the mobile web game (this folder)

A separate top-down phone game, loosely based on the Godot installation game in the rest of this
repository. **It does not use Godot.** It is one web page, `index.html`, drawn with three.js.
Read `README.md` in this folder for what is built so far.

## Which rules apply here
- The root `CLAUDE.md` section **"How to work with me" applies in full** (discuss design first,
  small play-testable steps, plain explanations, say what is untested).
- The root file's Godot, Windows laptop, `.tscn`, tuning spreadsheet and Godot test-runner rules
  **do not apply** to work in this folder. Leave the Godot game untouched unless asked.
- This game is usually developed in a Claude cloud session (Linux container), not on the laptop.
  Work is lost unless committed and pushed. Commit at the end of a task.

## Decisions already made (don't re-ask)
- Web game, three.js r128 loaded from cdnjs. No build step, no other libraries.
- Portrait. Camera fixed north-up, never moves sideways, shows the level's full width, follows
  the tank north, tank in the middle of the screen. Levels are strips 28 units wide that run up
  the screen.
- The level's edges are never shown: terrain is built past the playable strip so it fills the
  screen, and invisible walls at the screen's side edges keep the tank in view (`PLAY`,
  `visibleWidthFactor`).
- Two thumb levers, one per tread.
- Kinematic tank (no physics engine). It can teeter on and fall off cliffs; slopes slow it.

## How the code is laid out (`index.html`, top to bottom)
1. `<style>` and HUD markup (levers, buttons, banner, readout).
2. `SET`: every driving and camera number worth tweaking.
3. **Terrain:** `LEVEL` (the level's numbers), `surface(x, n)` (the level's shape; `n` is distance
   north of the start), filled into a height grid of 0.5-unit squares. `groundHeight(x, z)` reads
   it. World axes: x is east, z is south, so north is `-z` and `n = -z`.
4. **Scene:** lights, terrain mesh coloured by steepness and surface kind, tank model, flag.
5. **Tank:** `stepTank(dt)`. The tank samples ground heights under its footprint and rests on
   them like a stiff plank (`restOnProfile`), which gives slope tilt, teetering and tipping off
   edges. `hitsWall` blocks moves into ground steeper than `SET.wallDeg`.
6. **Controls:** levers write into `levers`; the tank reads only that (same idea as the Godot
   game's `DriverStation`).
7. **Camera**, **Progress** (checkpoints, chasm fall, flag), **Main loop** (fixed 60 steps/s).
8. `window.tankGame`: hooks the tests use to drive the tank and step time.

Keep it one file until a second level is added; then move level data into its own file.

## Testing (do this before handing over)
```
cd mobile/tests
npm install            # once per session
node run_tests.js      # add --shots to save screenshots into mobile/tests/shots/
```
- All checks must pass. The autopilot check proves the level can still be driven start to flag;
  if the level's shape changes, update the autopilot's waypoints in `run_tests.js` to match.
- Use the Playwright and Chromium already installed in the cloud session. Do not install them.
- The cloud container cannot reach cdnjs, so the test feeds the page three.js from npm. This is
  expected and is not a bug in the page.
- Look at the screenshots (`--shots`) after any visual change.
- Headless tests cannot judge feel or phone frame rate. Say so, and ask for a phone play-test.

## Publishing so the developer can play on their phone
- The game is published as a private claude.ai Artifact at
  **https://claude.ai/artifact/HarYNW55BLuCwd9hvWrGzS**
- After a change passes the tests, publish `mobile/index.html` with the Artifact tool, passing
  that address as `url` so the same link is updated (read it first with `action: "read"`, as the
  tool requires). Do not create a new artifact.
- `index.html` has no `<!doctype>`, `<html>`, `<head>` or `<body>` tags on purpose: the Artifact
  page adds them. Scripts may only load from cdnjs; everything else must be inside the file.
- Tell the developer to refresh the link, and what to try.

## Keep up to date
- `mobile/README.md`: the "State" section (what is built, what is tested, what is untested).
- One short numbered entry in the root `NOTES.md` per session.
