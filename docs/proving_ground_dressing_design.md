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

