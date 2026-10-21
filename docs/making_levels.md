# Making levels

A level is a folder in `levels/` with a height image you paint and a scene that turns it into
ground. The starter level (`levels/starter/`) is a working example to copy.

## The height image (`height.png`)
- **Greyscale PNG.** Black = lowest ground, white = the level's **Max Height** (30 m by default).
- **Size:** 1 pixel = 1 m by default, so a **256 × 256** image makes a 256 m square level. Up to
  about 512 × 512 is fine on this laptop.
- **Top of the image = north**, the far side as you look from the default start.
- **Edges:** there are no walls. Paint mountains around the edge to keep the tank in. If it does
  escape and falls off the world, it is sent back to its reset point.
- **8-bit is fine.** Godot 4.6 reads 16-bit PNGs as 8-bit anyway, so there are 256 heights: about
  12 cm apart at 30 m Max Height. The **Smoothing** setting softens the steps.

### Photoshop tips
- Image > Mode > **Grayscale**, 8 bits/channel. Save as **PNG**.
- Soft brushes and gradients make slopes. How steep a slope is depends on how fast the grey
  changes: at 30 m Max Height and 1 m per pixel, a change of one grey level (out of 255) per pixel
  is about a 7° slope; 4 levels per pixel is about 25°; 6 is about 35°.
- Hard edges make cliffs. Smoothing rounds them a little.
- Save over the same file: Godot notices within a second and rebuilds the ground in the editor.

## The level scene
The easiest start: duplicate the `levels/starter/` folder, rename it, open the scene, and point
its `LevelTerrain` at your image. Or build one from scratch:

1. **Scene > New Scene**, root node **Node3D**, named after the level. Attach
   `scripts/level_root.gd` to it.
2. Add a **WorldEnvironment** (Environment with a sky) and a **DirectionalLight3D** (sun, shadows
   on), or copy them from the starter level.
3. Add a **Node3D** named `LevelTerrain`, attach `scripts/level_terrain.gd`, and set
   **Height Image Path** to your `height.png`.
4. Add a **Marker3D** named `LevelStart`, attach `scripts/level_start.gd`, and move it to where
   the tank should start. The yellow arrow shows which way it will face. Its height doesn't
   matter: the tank is placed on the ground.
5. Save the scene in the level's folder (e.g. `levels/quarry/quarry.tscn`).
6. Press **F6** (Run Current Scene) to drive it. The tank, cameras, debug display and Tab panel
   are added automatically.

## Settings (on the LevelTerrain node, and in the Tab panel under "Level ground")
| Setting | What it does |
|---|---|
| Height Image Path | The PNG to build from. |
| Metres Per Pixel | Size of one pixel on the ground. 2 = a 256 px image is 512 m across, with slopes half as steep. |
| Max Height | Height of pure white, in metres. Doubling it doubles every hill and slope. |
| Smoothing | Softening passes. 0 = exactly as painted; 1 to 3 hides 8-bit steps; more rounds everything off. |
| Rebuild | Rebuilds now (normally automatic when the image is saved). |

Changes in the Tab panel only last until you quit: use **Copy values** and type them into the
LevelTerrain node's Inspector to keep them.

## Coming next
- `terrain.png`: paint mud, sand, road, ice and water in flat colours.
- A kit of pieces to drag in (ramps, walls, rocks, bunkers).
- Choosing a level from a menu.
