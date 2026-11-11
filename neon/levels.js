// Neon Treads: the levels.
//
// Each level is a picture made of text. The TOP line is the far (north) end of the level, the
// BOTTOM line is where the player starts, so the text reads the same way up as the screen.
// Every line has 7 cells; each cell is 2 characters: HEIGHT then WHAT IS THERE.
//
// HEIGHT   0, 1, 2 = the three main floors (low, middle, high)   3 = a raised spot
//          xx      = no floor at all (a drop into the void; falling in costs a life)
//
// WHAT     .  plain floor
//          ^ v < >  a ramp that climbs one floor in the arrow's direction
//                   (written with the LOWER floor's number: "0^" climbs from floor 0 to floor 1)
//          S  player start            C  checkpoint            E  exit gate
//          f  a caged friend (a "bit") to rescue; the exit opens when all are free
//          t  turret (stands still, shoots)      d  drone (chases, explodes)
//          h  sweeper patrolling east-west       p  sweeper patrolling north-south
//          B  firewall block (shoot it twice to clear the way)
//          G  the Guide, who is snatched by the Warden when the player comes near (story)
//          W  the Warden (boss)       g  the Guide in a cage, freed when the Warden is beaten
//
// The tests check every level: all friends and the exit can be reached from the start and from
// every checkpoint, and an autopilot drives each level from start to exit.
window.NEON_LEVELS = [
  {
    name: "boot",          // learn the floors, ramps, a pit, the first enemies
    rows: [
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 2. 2. 2E 2. 2. 2.",
      "2. 2d 2. 2. 2. 2. 2.",
      "2. 2. 2. 2. 2. 3. 3.",
      "2. 2. 2. 2. 2> 3. 3f",
      "2. 2. 2. 2. 2. 3. 3.",
      "2. 2t 2. 2C 2. 2. 2.",
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 2. 2. 1^ 2. 2. 2.",
      "1. 1. 1. 1. 1. 1. 1f",
      "1. 1. xx xx xx 1. 1.",
      "1. 1. xx xx xx 1. 1.",
      "1. 1d 1. 1. 1. 1. 1.",
      "1. 1. 1. 1. 1. 1. 1.",
      "1. 1. 1. 1. 0^ 1. 1.",
      "1. 1. 1. 0C 0. 0. 0.",
      "1. 1. 1. 0. 0. 0. 0.",
      "1. 1. 1. 0. 0. 1t 1.",
      "1f 1. 0^ 0. 0. 1. 1.",
      "1. 1. 0. 0. 0. 1. 1.",
      "1. 1. 0. 0. 0. 1. 1.",
      "0. 0. 0. 0. 0. 0. 0.",
      "0. 0. 0. 0G 0. 0. 0.",
      "0. 0. 0. 0. 0. 0. 0.",
      "0. 0. 0. 0S 0. 0. 0."
    ]
  },
  {
    name: "bridges",       // narrow bridges over the void, sweepers, a split high/low route
    rows: [
      "xx 1. 1. 1. 1. 1. xx",
      "xx 1t 1. 1E 1. 1t xx",
      "xx 1. 1. 1. 1. 1. xx",
      "xx xx xx 1. xx xx xx",
      "xx xx xx 1B xx xx xx",
      "xx xx 1. 1. 1. xx xx",
      "1. 1d 1. 1C 1. 1d 1.",
      "1. 1. 1. 1. 1. 1. 1.",
      "2. 2. 2. 1. 0^ 0. 0.",
      "2. 2. 2. xx 0. 0. 0.",
      "2. 2. 2. xx 0. 0. 0f",
      "2. 2f 2. xx 0. 0h 0.",
      "2. 2. 2. xx 0. 0. 0.",
      "xx 1^ xx xx xx 0v xx",
      "1. 1. 1. 1C 1. 1. 1.",
      "1. 1t 1. 1G 1. 1. 1.",
      "1. 1. 1. 1. 1. 1. 1.",
      "xx 1. xx xx xx 1d xx",
      "xx 1. xx xx xx 1. xx",
      "xx 1p xx xx xx 1. xx",
      "xx 1. xx xx xx 1. xx",
      "1. 1. 1. 1. 1. 1. 1C",
      "1f 1. 1. 1h 1. 1. 1.",
      "1. 1. 1. 1. 1. 1. 1.",
      "xx xx xx 1. xx xx xx",
      "xx xx xx 1. xx xx xx",
      "xx xx xx 1. xx xx xx",
      "xx xx 1. 1. 1. xx xx",
      "1. 1. 1. 1. 1. 1. 1.",
      "1. 1. 1. 1S 1. 1. 1."
    ]
  },
  {
    name: "citadel",       // climb all three floors past turrets on high ground, then the Warden
    rows: [
      "3. 3. 3. 3. 3. 3. 3.",
      "3. 3. 3. 2E 3. 3. 3.",
      "3. 3. 3. 2g 3. 3. 3.",
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 3. 2. 2W 2. 3. 2.",
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 3. 2. 2. 2. 3. 2.",
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 2. 2. 2. 2. 2. 2.",
      "3. 2B 3. 3. 3. 2B 3.",
      "2. 2. 2. 2C 2. 2. 2f",
      "2. 2. 3. 3. 3. 2. 2.",
      "2p 2. 3. 3t 3. 2. 2.",
      "2. 2. 2. 2. 2. 2. 2.",
      "2. 2. 2. 2. 2. 1^ 2.",
      "1. 1. 1. 1. 1. 1. 1.",
      "1. 1. xx 1f xx 1. 1.",
      "1. 1. xx xx xx 1d 1.",
      "1. 1. 1. 1. 1. 1. 1.",
      "1. 0^ 1. 1. 1. 1. 1.",
      "0. 0. 0. 0C 0. 0. 0.",
      "0f 0. 0h 0. 0. 0. 0.",
      "0. 0. 0. 0. 0. 0. 0.",
      "1. 1. 1. 0B 1. 1. 1.",
      "0. 0. 0. 0. 0. 0. 0.",
      "0. 1. 1. 0. 1. 1. 0.",
      "0. 1. 1t 0. 1t 1. 0.",
      "0. 1. 1. 0. 1. 1. 0.",
      "0. 0. 0. 0. 0. 0. 0.",
      "0. 0. 0. 0S 0. 0. 0."
    ]
  }
];
