# Little Tank (mobile web game)

A separate, small top-down game for phones, loosely based on the installation game. It does not
use Godot: it is one web page, `index.html`, drawn in 3D with three.js (loaded from a public CDN).

- **Play:** open `index.html` in a browser (needs an internet connection for three.js), or use the
  private claude.ai link Claude publishes while working.
- **Controls:** two thumb levers, one per tread. On a desktop: W/S for the left tread, Up/Down
  arrows for the right.
- **Settings:** the `SET` block near the top of the script in `index.html`.

## State (step 1, 2026-11-10): a spike to prove the platform
- Portrait, camera fixed north-up, hand-made test patch (not the real landscape).
- Kinematic tank: it rests on the ground like a stiff plank, so it tilts on slopes, leans when
  its middle nears a cliff edge, tips over and falls. Slower uphill, stalls at 35 degrees. Ground
  steeper than 50 degrees is a wall.
- Test patch: mesa (3 high) with a gentle and a steep ramp, a low terrace (1 high), a hill too
  steep to finish climbing, rolling ground, rock wall round the edge.
- Checked by script in a headless phone-sized browser: both ramps, cliff fall and landing, wall
  block, hill stall, turning direction, two-finger lever touch.
- **Untested:** on a real phone (frame rate, lever feel, safe areas).
