# Little Tank (mobile web game)

A separate, small top-down game for phones, loosely based on the installation game. It does not
use Godot: it is one web page, `index.html`, drawn in 3D with three.js (loaded from a public CDN).

- **Play:** the private claude.ai link Claude publishes while working, or the public GitHub Pages
  copy at https://kickpunch3r.github.io/tank-game/ (the only one where shake-to-fire can work).
  Opening `index.html` straight in a browser also works (needs internet for three.js).
- **Controls:** two thumb levers, one per tread. On a desktop: W/S for the left tread, Up/Down
  arrows for the right.
- **Tests:** `cd mobile/tests`, `npm install` once, then `node run_tests.js` (details in
  `mobile/CLAUDE.md`).
- **Settings:** the `SET` block near the top of the script in `index.html`.

## State (step 2, 2026-11-10): one test level
- Portrait, camera fixed north-up. Levels are strips 28 units wide that run up the screen; the
  camera never moves sideways, shows the full width, and follows the tank north with the tank
  mid-screen. Terrain continues past the playable strip so the screen is always full; invisible
  walls at the screen's side edges and the level's ends keep the tank in.
- Kinematic tank: it rests on the ground like a stiff plank, so it tilts on slopes, leans when
  its middle nears a cliff edge, tips over and falls. Slower uphill, stalls at 35 degrees. Ground
  steeper than 50 degrees is a wall.
- Test level (numbers in the `LEVEL` block): hilly plain, six road shelves zig-zagging up a
  mountain 21 high, a narrow winding cliff path with a chasm (a ridge with drops on both sides in
  the middle), then a flag. Four checkpoints; falling into the chasm returns to the last one.
- Cannon: a laser. An instant straight beam along the barrel, up to 45 units, stopped by the
  first ground it meets. Glowing red beam with a white core, a burst of sparks at the muzzle and
  at the hit, hull recoil and a 1.5 s reload. Nothing to damage yet. Fired from the **Debug** menu's Fire button, or by
  shaking the phone where the page is allowed to read the motion sensor (not in the claude.ai
  link; iPhones also need a tap on "Allow shake"). The Debug menu shows the shake status.
- Checked by script in a headless phone-sized browser: an autopilot drives start to flag (about
  110 s), chasm fall and return, falling off a road shelf, the bank between shelves blocks, the
  invisible side wall keeps the tank on screen.
- **Untested:** shake on any real phone (only simulated motion events). Also on a real phone (frame rate with the bigger level, lever feel, difficulty).
- Known rough edges: diagonal cliffs look stair-stepped (the ground is a 0.5-unit grid); the
  mountain road is wide shelves, not a narrow road.
