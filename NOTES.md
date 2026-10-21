# Notes

## Godot
- Version: **4.6.3 stable** (`4.6.3.stable.official.7d41c59c4`).
- Editor: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe`
- Headless checks: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe --headless --path .`
- Renderer: Forward+ on Direct3D 12 (same as the finger-walk project, known to work on this laptop).
  Physics engine: Jolt.

## Decisions
- **Scene files written as text** (allowed in this project, see CLAUDE.md). Scenes reference files
  by path with no UIDs; Godot 4.6 loads them fine and creates `.gd.uid` files next to scripts.
  Commit those `.uid` files.
- **Graphics:** each object keeps its looks in a `Visual` child node. The tank's meshes sit under
  `Visual/Hull` so milestone 3 can tilt the hull without touching the collision body.
  Forward is **-Z** (Godot's convention); the barrel and yellow nose marker point that way.
- **Ground** is built by `scripts/course_builder.gd` when the scene starts, with a world-space
  checker shader (`art/checker_ground.gdshader`) so speed is easy to read. Because it is built at
  runtime, the ground does not show in the editor viewport, only when the game runs.
- **Chase camera** follows the tank's heading only, never its tilt, so it stays level. It updates
  in `_physics_process`. Possible later fix if it looks juddery on a high-refresh screen: turn on
  physics interpolation.

## Milestone log
1. **Skeleton** (2026-10-21): project, folders, `.gitignore`, flat ground, placeholder tank,
   chase camera. Headless run: no errors; tank settles on the ground (y = 0.001, on floor).
