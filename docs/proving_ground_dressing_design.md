# Proving Ground dressing and graphics extras: design decisions

Built in an overnight run (independent work mode) on 2026-10-30. Each decision lists the
alternatives and why, so you can push back.

## 1. Map dressing

All placement comes from `ProvingGroundLayout.scenery()` (one seeded plan, so the level looks the
same every time and tests can check it). `ProvingGroundScenery` builds it: one MultiMesh per kind
(one draw call each), plus one StaticBody3D holding every solid shape.

| What | Where | Decision | Alternatives considered |
|---|---|---|---|
| Dune sea | south-west, 152 x 78 m | Sand terrain; long crests (about 2.6 m tall) that wander with noise. Slopes mostly 6°, at most about 22°, so it's slow and rolling, not a wall. | Sharp dunes (too steep for the Heavy tank to cross); random bumps (looked like noise, not dunes). |
| Lake | where the river ends, west | 24 m of deep water with a shelving shore out to 42 m. Orange buoys ring the deep part. | A bigger lake (would swallow the low route's area). |
| Deep water | past the buoys | An invisible area: a tank that enters is put back at the level's start (its "home"), keyboard levers cleared. | Drowning animation or a fade (more work; can add later); a slow sink (unclear to players). |
| Big rocks | at the foot of the high road's raised parts, alternating sides, every ~18 m; two on top, 4 m off-centre | Solid, so they shape where you can drive; the lane on top stays wide enough to pass. | Rocks across the road (would block the route test and players). |
| Small rocks | scattered (15 m grid), plus a rubble patch by the test area at (40, 100) | Solid with real colliders, as you asked, so you can feel driving over them. | Visual only. |
| Boulder field | (−55, −108), 13 m across | Solid medium rocks to weave through. A flat run-up east of the cone is kept clear so you can still try driving up the cone. | Boulders anywhere (they blocked the cone's run-up). |
| Misty pine forest | north-east, 90 x 58 m | Pines on a jittered grid with clearings, solid trunks. The `MistyForest` HazeZone: fog thickens as the camera goes in (over 20 m) and soft mist sheets hang among the trees. Always misty, even with Haze switched off. | A fog volume (Forward+ only; your laptop could struggle and it isn't in Compatibility); just denser global fog (no "area"). |
| Trees | scattered (20 m grid) | Round trees, solid trunks. | |
| Bushes | scattered (9 m grid) | Not solid (you drive through); can be hidden from the Tab panel. | Solid bushes (too fiddly to drive among). |

Nothing is placed on the road, the routes (plus a shoulder), the test area, the spawn, the river
and lake, the goal, the cone, mesa, ridge, dunes, the mud basin, or slopes over about 20°.

## 2. Tank details (physics tank only)

`TankDetails` (`scripts/tank_details.gd`) sits in `Visual/Hull` and builds everything by script,
so the scene file stays small. Looks only: driving is unchanged.

- **Sloped front plate:** a wedge in front of the hull, below the driver's slit camera so it
  doesn't block the view. Chose a wedge added to the box over reshaping the hull (keeps the old
  box, so switching details off still shows a whole tank).
- **Road wheels:** 5 a side on the outside of the treads, each with a dark hub bar so you can see
  it turn. They turn by how far their tread has moved over the ground.
- **Track links:** a box just over each plain tread with `art/tread.gdshader`: dark cross gaps
  that move forward along the top and backward along the bottom, at that tread's speed.
- **Speed used:** each tread's speed over the ground (`left_tread_speed`/`right_tread_speed`), so
  when the tank is stuck and slipping the tracks stand still. Alternative: the lever position
  (tracks would spin while stuck: more dramatic but the tank doesn't model slip, so it would be a
  guess). Easy to change if you prefer spinning tracks.
- The old kinematic tank is not given details (it's a debug option).

## 3. Dust and spray

`TreadDust` (`scripts/tread_dust.gd`) sits in `Visual/Hull`: one GPUParticles3D per tread.

- Puffs come from the back of each tread going forward (the front in reverse), only while that
  tread touches the ground and moves faster than 0.6 m/s. More puffs the faster it goes (full at
  6 m/s).
- Colour: the ground's own colour, lightened (sand, mud), dusty earth on firm ground, and white
  spray when the tread is below the water (the level's `Water` node is in group `water_surface`).
- 40 soft puffs per tread, unshaded: cheap. Alternatives: CPU particles (slower), decals/tread
  marks (more work; maybe later).

## 4. Tab panel "Graphics" section

`GraphicsOptions` (`scripts/graphics_options.gd`) holds five switches, all on at the start; the
Tab panel lists them as tick boxes. Like the rest of the panel, changes last until you quit.

| Switch | What it does |
|---|---|
| Tank details | Hides the road wheels, track links and front plate (the plain box tank shows). |
| Dust and spray | Hides the dust. |
| Bushes | Hides bushes only. Trees and rocks stay: they are solid, so hiding them would leave invisible walls. |
| Shadows | Turns off the sun's shadows (usually the biggest saving). |
| Distance haze | Turns off the fog over the level. The misty forest stays misty (it's a place, not an effect). |

Alternatives: a single "low / high" quality switch (simpler but you can't tell which thing is
slow); saving the choices to a file (not needed yet). If one of them is slow, tell me which and
I can remove or simplify it.

## Untested (can't be checked here)

- Frame rate on your laptop (Intel HD 520, Forward+). Screenshots here use the Compatibility
  renderer in software, so colours and mist may look slightly different.
- How driving over small rocks feels (you said you'd try it).

## Hand-test checklist

1. Pull, open the project, let it import, press Play. Watch the frame rate (top line of the F3 display, or
   Godot's Debugger > Monitors).
2. Drive forward: dust behind both treads, wheels and track links moving. Spin on the spot: one
   side's tracks run backward.
3. Tab > Graphics: untick each box in turn and check what disappears, and whether the frame rate
   changes. Re-tick them.
4. Drive the low route: dust turns brown in the mud basin, white spray at the ford, sandy on the
   dunes.
5. Drive west to the lake. Go past the buoys: you should be sent back to the start.
6. Drive into the dune sea (south-west): rolling sand, slow going but passable.
7. Drive along the high road: big rocks beside the raised sections, two on top that you can pass.
8. Drive into the misty pine forest (north-east): fog thickens as you enter, clears as you leave.
   The pine trunks are solid.
9. Drive over the rubble patch (east of the spawn, south of the test area) and the scattered small
   rocks: how does it feel? Bump at a tree and a boulder: you should stop.
10. Check the driver's slit view: the new front plate shouldn't block it.

## After play-testing (2026-11-02)

Your answers: frame rate fine, small rocks fine, still tracks when stuck fine, slit view fine.
Changes you asked for:
- Graphics tick boxes removed (section 4 no longer applies); everything stays on.
- Scattered trees and bushes removed; the misty forest's pines stay.
- Pines: only the trunk is solid (it was half the canopy's width).
- Deep water: option a. More than 1.2 m of water under the tank sends it back to the start. That
  covers the lake past the buoys and the river's channel; the ford (0.4 m) and the low route
  (0.6 m at most) stay crossable. Alternatives were: back to the bank you came from (kinder, more
  work), or leave the river wadeable.
- Forest fog starts at the forest's edge and is full 20 m in (it started 10 m outside).
