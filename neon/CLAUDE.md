# Neon Treads (this folder)

A fuller rebuild of the mobile tank game (`mobile/`) in a glowing digital world: three levels,
enemies, friends to rescue, a boss, and a story told without words. A web page, not Godot.
Lives on the `neon-treads` branch until the developer decides to merge it. `README.md` here says
what is built; `docs/neon_treads_design.md` records the design decisions and why.

## Rules
- Root `CLAUDE.md` "How to work with me" applies. Its Godot/Windows/`.tscn` rules do not.
- Developed in a Claude cloud session: commit and push or the work is lost.
- **Push to the `neon-treads` branch, not `main`** (the standing "push to main" permission is for
  `mobile/` only).
- The look is an original neon-grid world. Do not copy the names, characters or designs of any
  existing film or game.

## Files
- `levels.js`: the levels, as text pictures. **Start here to change or add a level**; the legend
  is at the top of the file.
- `world.js`: reads a level's text into floor heights (`heightAt`) and builds the scenery.
- `game.js`: everything else, in labelled sections (settings `SET`, effects, sound, tank, laser,
  characters, levels, HUD, controls, camera, main loop, test hooks `window.tankGame`).
- `index.html`: markup and styles. No `<html>`/`<head>`/`<body>` tags on purpose.

## Testing (before handing over)
```
cd neon/tests
npm install            # once per session
node run_tests.js      # add --shots for screenshots in neon/tests/shots/
```
The tests check every level in `levels.js` automatically: friends and exit reachable from the
start and every checkpoint, and an autopilot drives each level to its exit (invulnerable, so it
proves the route, not the difficulty). Look at the screenshots after visual changes.

## Publishing
- claude.ai link: **https://claude.ai/artifact/69UzVp47F7rQ2ZgSeSWUjX**. Publish `neon/index.html`
  with the Artifact tool, that address as `url` (read it first), and
  `files: {"levels.js": "neon/levels.js", "world.js": "neon/world.js", "game.js": "neon/game.js"}`.
- GitHub Pages copy (shake-to-fire only works there): `bash neon/publish_to_github_pages.sh`,
  served at https://kickpunch3r.github.io/tank-game/neon/
