# Neon Treads

A top-down tank game for phones, set in a glowing digital world. Rebuilt from the `mobile/` game.

- **Play:** the claude.ai link in `CLAUDE.md`, or https://kickpunch3r.github.io/tank-game/neon/
- **Controls:** two thumb levers (one per tread), a fire button between them, or shake the phone
  to fire (GitHub Pages copy only; iPhones ask permission when you press Play). Desktop: W/S,
  Up/Down, Space.
- **Goal of each level:** free every caged friend (gold), then drive into the exit gate. It is
  red while shut and cyan when open.

## What is in the game (2026-11-11)
- **World:** three main floors (blue low, teal middle, violet high) plus white raised spots.
  Floors are flat; straight ramps with arrow markings join them; edges are sheer. Black pits
  rimmed in red are drops into the void.
- **Tank:** 4 shield pips. Losing them all, or falling into the void, returns it to the last
  checkpoint (ring on the floor) with full shield. The laser bends onto an enemy that is nearly
  straight ahead, including up or down a floor.
- **Enemies:** turrets (stand still and shoot), drones (chase and explode), sweepers (patrol a
  line), firewall blocks (shoot twice to clear), and the Warden (boss of level 3).
- **Friends:** small gold "bits" in cages; freed ones hop along behind the tank. The Guide, a
  tall gold figure.
- **Story, no words:** in level 1 the Warden swoops down and carries off the Guide. In level 2
  the Guide is seen again and snatched again. Level 3 ends at the Warden's citadel: beat it and
  the Guide's cage breaks open and the Guide follows you out.
- **Levels:** 1 "boot" (learn floors, ramps, a pit, first enemies), 2 "bridges" (narrow bridges
  over the void, sweepers, a split high/low route), 3 "citadel" (turrets on high ground, blocks,
  the boss arena). Progress is remembered on the device. The Debug menu (top right) can skip
  levels.
- **Sound:** simple synthesised effects; toggle in the Debug menu.

## Tested
22 headless checks pass: every level's layout, an autopilot finishing all three levels and the
boss, the story scene, turret damage, laser aim help, void and checkpoint, rescue and exit rule,
touch levers, fire button, simulated shake.

## Not tested
Anything on a real phone: frame rate, difficulty, whether enemies and the boss are fair, sound,
shake. Difficulty numbers are first guesses.
