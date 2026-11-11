# Neon Treads: design decisions (2026-11-11)

The developer asked for a fuller game rebuilt from the mobile tank game on a separate branch, with
wide freedom ("see what you can do"). These are the choices made without asking, with the
alternatives, so they can be pushed back on.

| Decision | Why | Alternative |
|---|---|---|
| Original neon-grid world; no names, characters or designs from the film that inspired the brief | Avoids copying someone else's work; the brief's point was the glowing digital look | A closer homage |
| Levels are text pictures of 7 x N cells, 4 units each | The developer (not a programmer) can read and edit a level; tests can check any level automatically | Hand-written height functions like the first game |
| Floors exactly 2 units apart, flat, with straight ramps; no rounded ground | The brief: clear distinct levels, not vague ups and downs | Smooth terrain |
| Floor = colour (blue, teal, violet, white); pit edges red | Height has to read at a glance from above with no shadows | Lighting and shadows (costlier, muddier) |
| No lighting or shadows; flat bright colours with outlines and glow | The neon look, and cheap to draw on a phone | Lit materials |
| Laser bends onto enemies within 16 degrees, including up/down | Aiming a tank with two treads on a phone is hard | Pure straight shots |
| Fire button added between the levers; shake kept | Shake can't work in the claude.ai link, and a game with enemies needs reliable firing | Shake only |
| Exit opens only when every friend is free | Gives each level side routes a purpose | Optional collectables |
| Death returns to the last checkpoint; destroyed enemies stay destroyed | Forgiving on a first play | Level restart |
| Story through three characters and three short scenes, no text | The brief | Text or dialogue |
| Tank can bump up small steps, slide along walls and pivot off them | Sheer-sided ramps made the tank stick | Leave as in the first game |
| Kept on the `neon-treads` branch in its own `neon/` folder | The brief asked for a separate branch; the first game stays playable | Replace `mobile/` |

## Hand-test checklist
1. Does it run smoothly? (Debug menu shows fps.)
2. Can you tell the three floors apart, and see where ramps and pits are?
3. Level 1: is the snatch scene at the start readable?
4. Are turrets, drones and sweepers fair? Too many, too few?
5. Level 2: are the one-cell bridges too narrow for thumbs?
6. Level 3: is the Warden beatable, and is the ending clear?
7. Does the fire button sit well between the levers? Is aim help too strong or too weak?
8. On the GitHub Pages copy: does shake fire?

## Known rough edges
- Thin outlines (1 pixel) on characters may look faint on some phones.
- The first game (`mobile/`) still has the "can't turn when nose is against a wall" stickiness
  fixed here.
