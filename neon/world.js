// Neon Treads: turns a level's text (levels.js) into floor heights and the glowing 3D scenery.
"use strict";
(function () {
  const N = window.NEON = {};
  const TILE = 4;            // one cell of the level text is 4 x 4 units of ground
  const COLS = 7;            // cells across: 7 x 4 = 28 units, the width of the screen
  const TIER = 2;            // each floor is 2 units higher than the one below
  const HALF_WIDTH = COLS * TILE / 2;
  const PIT_DRAW_DEPTH = -14;   // how far down walls are drawn into the void
  N.TILE = TILE; N.COLS = COLS; N.TIER = TIER; N.HALF_WIDTH = HALF_WIDTH;
  N.VOID_Y = -20;            // "ground height" over the void (far below, so the tank falls)
  N.BLOCK_HEIGHT = 2.6;      // a firewall block stands this high on its cell

  // Edge-glow colour of each floor (0 low, 1 middle, 2 high, 3 raised spot)
  N.TIER_COLORS = [0x2f6bff, 0x1fe3ff, 0xb574ff, 0xf2f6ff];
  // Colour of each floor's top surface (red, green, blue from 0 to 1)
  const TOP_TINT = [[0.07, 0.11, 0.27], [0.04, 0.23, 0.29], [0.20, 0.12, 0.36], [0.33, 0.35, 0.44]];
  const HAZARD = [1.0, 0.2, 0.25];
  const RAMP_LETTER = { "^": "n", "v": "s", ">": "e", "<": "w" };

  N.tileX = function (col) { return -HALF_WIDTH + (col + 0.5) * TILE; };
  N.tileZ = function (row) { return -(row + 0.5) * TILE; };
  function clamp01(v) { return Math.min(1, Math.max(0, v)); }

  // How far up a ramp cell a point is (0 at its low edge, 1 at its high edge).
  // fx: 0 at the cell's west edge to 1 at its east edge; fn: 0 at its south edge to 1 at its north.
  function rampFraction(ramp, fx, fn) {
    return ramp === "n" ? fn : ramp === "s" ? 1 - fn : ramp === "e" ? fx : 1 - fx;
  }

  // ------------------------------------------------------------------
  // Reading a level
  // ------------------------------------------------------------------
  N.parseLevel = function (def) {
    const rows = def.rows.length;
    const level = { name: def.name, rows: rows, length: rows * TILE, tiles: [], spawns: [] };
    for (let r = 0; r < rows; r++) {
      const cells = def.rows[rows - 1 - r].trim().split(/\s+/);     // row 0 is the south end
      if (cells.length !== COLS) throw new Error("Level '" + def.name + "': a line has " + cells.length + " cells, needs " + COLS);
      const line = [];
      for (let c = 0; c < COLS; c++) {
        const cell = cells[c], isVoid = cell[0] === "x";
        if (cell.length !== 2 || (!isVoid && "0123".indexOf(cell[0]) < 0)) throw new Error("Level '" + def.name + "': bad cell '" + cell + "'");
        const tile = { col: c, row: r, isVoid: isVoid, tier: isVoid ? 0 : Number(cell[0]), ramp: RAMP_LETTER[cell[1]] || null, block: null };
        if (!isVoid && !tile.ramp && cell[1] !== ".") {
          level.spawns.push({ kind: cell[1], col: c, row: r, x: N.tileX(c), z: N.tileZ(r), tile: tile });
        }
        line.push(tile);
      }
      level.tiles.push(line);
    }
    level.tileAtXZ = function (x, z) {
      const col = Math.min(COLS - 1, Math.max(0, Math.floor((x + HALF_WIDTH) / TILE)));
      const row = Math.min(rows - 1, Math.max(0, Math.floor(-z / TILE)));
      return level.tiles[row][col];
    };
    // Floor height at any point. Exact: floors are flat, ramps are straight, edges are sheer.
    level.heightAt = function (x, z) {
      const gx = (x + HALF_WIDTH) / TILE, gn = -z / TILE;
      const col = Math.min(COLS - 1, Math.max(0, Math.floor(gx)));
      const row = Math.min(rows - 1, Math.max(0, Math.floor(gn)));
      const t = level.tiles[row][col];
      if (t.isVoid) return N.VOID_Y;
      const base = t.tier * TIER;
      if (t.block && t.block.alive) return base + N.BLOCK_HEIGHT;
      if (!t.ramp) return base;
      return base + TIER * rampFraction(t.ramp, clamp01(gx - col), clamp01(gn - row));
    };
    return level;
  };

  // ------------------------------------------------------------------
  // Drawing a level
  // ------------------------------------------------------------------
  // Height of a cell's surface at its four corners (sw, se, ne, nw)
  function corners(t) {
    if (t.isVoid) return [PIT_DRAW_DEPTH, PIT_DRAW_DEPTH, PIT_DRAW_DEPTH, PIT_DRAW_DEPTH];
    const b = t.tier * TIER;
    if (!t.ramp) return [b, b, b, b];
    return [b + TIER * rampFraction(t.ramp, 0, 0), b + TIER * rampFraction(t.ramp, 1, 0),
            b + TIER * rampFraction(t.ramp, 1, 1), b + TIER * rampFraction(t.ramp, 0, 1)];
  }

  // Collects flat four-sided pieces and turns them into one mesh (one mesh draws fast).
  function Batch() { this.pos = []; this.col = []; this.uv = []; }
  Batch.prototype.quad = function (p, colors, uvs) {
    const order = [0, 1, 2, 0, 2, 3];
    for (let k = 0; k < 6; k++) {
      const i = order[k], c = Array.isArray(colors[0]) ? colors[i] : colors, u = uvs ? uvs[i] : [0, 0];
      this.pos.push(p[i][0], p[i][1], p[i][2]);
      this.col.push(c[0], c[1], c[2]);
      this.uv.push(u[0], u[1]);
    }
  };
  Batch.prototype.mesh = function (material) {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.Float32BufferAttribute(this.pos, 3));
    geo.setAttribute("color", new THREE.Float32BufferAttribute(this.col, 3));
    geo.setAttribute("uv", new THREE.Float32BufferAttribute(this.uv, 2));
    return new THREE.Mesh(geo, material);
  };

  function canvasTexture(size, draw) {
    const cv = document.createElement("canvas");
    cv.width = cv.height = size;
    draw(cv.getContext("2d"), size);
    const tex = new THREE.CanvasTexture(cv);
    tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
    tex.anisotropy = 4;
    return tex;
  }
  let gridTexture = null, chevronTexture = null;
  function makeTextures() {
    gridTexture = canvasTexture(128, function (g, s) {         // floor: a bright frame and a faint 4 x 4 grid
      g.fillStyle = "rgb(120,120,120)"; g.fillRect(0, 0, s, s);
      g.strokeStyle = "rgb(190,190,190)"; g.lineWidth = 2;
      for (let i = 1; i < 4; i++) {
        g.beginPath(); g.moveTo(i * s / 4, 0); g.lineTo(i * s / 4, s); g.moveTo(0, i * s / 4); g.lineTo(s, i * s / 4); g.stroke();
      }
      g.strokeStyle = "rgb(255,255,255)"; g.lineWidth = 5; g.strokeRect(0, 0, s, s);
    });
    chevronTexture = canvasTexture(128, function (g, s) {      // ramp: arrows pointing up the slope
      g.fillStyle = "rgb(95,95,95)"; g.fillRect(0, 0, s, s);
      g.strokeStyle = "rgb(255,255,255)"; g.lineWidth = 9; g.lineJoin = "miter";
      for (let i = 0; i < 4; i++) {
        const y = s - i * s / 4 - 6;          // canvas y runs downward; the texture's "up" is canvas "up"
        g.beginPath(); g.moveTo(s * 0.2, y); g.lineTo(s * 0.5, y - s * 0.16); g.lineTo(s * 0.8, y); g.stroke();
      }
    });
  }

  function hexToRgb(hex) { return [((hex >> 16) & 255) / 255, ((hex >> 8) & 255) / 255, (hex & 255) / 255]; }
  function scaled(c, k) { return [c[0] * k, c[1] * k, c[2] * k]; }
  // A repeatable "random" number from 0 to 1 for a cell, so scenery is the same every time
  function hash(a, b) { const s = Math.sin(a * 127.1 + b * 311.7) * 43758.5453; return s - Math.floor(s); }

  N.buildLevelScenery = function (level) {
    if (!gridTexture) makeTextures();
    const tops = new Batch(), ramps = new Batch(), walls = new Batch(), edges = new Batch(), halos = new Batch();

    function tileOrNull(col, row) {
      return (col < 0 || col >= COLS || row < 0 || row >= level.rows) ? null : level.tiles[row][col];
    }
    // Surface height of cell t at a point given as fractions across the cell
    function surface(t, fx, fn) {
      if (t.isVoid) return PIT_DRAW_DEPTH;
      return t.tier * TIER + (t.ramp ? TIER * rampFraction(t.ramp, fx, fn) : 0);
    }

    for (let r = 0; r < level.rows; r++) {
      for (let c = 0; c < COLS; c++) {
        const t = level.tiles[r][c];
        if (t.isVoid) continue;
        const x0 = -HALF_WIDTH + c * TILE, x1 = x0 + TILE, z0 = -r * TILE, z1 = z0 - TILE;   // z0 south, z1 north
        const h = corners(t);
        const P = [[x0, h[0], z0], [x1, h[1], z0], [x1, h[2], z1], [x0, h[3], z1]];           // sw, se, ne, nw
        const glowTier = Math.min(3, t.tier + (t.ramp ? 1 : 0));
        const tint = TOP_TINT[glowTier], glow = hexToRgb(N.TIER_COLORS[glowTier]);

        // Top surface
        if (!t.ramp) {
          tops.quad(P, tint, [[0, 0], [1, 0], [1, 1], [0, 1]]);
        } else {
          const uv = { n: [[0, 0], [1, 0], [1, 1], [0, 1]], s: [[0, 1], [1, 1], [1, 0], [0, 0]],
                       e: [[0, 0], [0, 1], [1, 1], [1, 0]], w: [[0, 1], [0, 0], [1, 0], [1, 1]] }[t.ramp];
          ramps.quad(P, scaled(glow, 0.55), uv);
        }

        // Four sides: a wall wherever this cell stands higher than its neighbour, and a glowing
        // strip along the top of that edge.
        const sides = [
          { a: 0, b: 1, n: tileOrNull(c, r - 1), na: 3, nb: 2, inX: 0, inZ: -1 },   // south side
          { a: 1, b: 2, n: tileOrNull(c + 1, r), na: 0, nb: 3, inX: -1, inZ: 0 },   // east side
          { a: 2, b: 3, n: tileOrNull(c, r + 1), na: 1, nb: 0, inX: 0, inZ: 1 },    // north side
          { a: 3, b: 0, n: tileOrNull(c - 1, r), na: 2, nb: 1, inX: 1, inZ: 0 }     // west side
        ];
        for (let s = 0; s < 4; s++) {
          const sd = sides[s];
          if (!sd.n) continue;                              // level's outer edge: hidden by the towers
          const nh = corners(sd.n);
          const dropA = h[sd.a] - nh[sd.na], dropB = h[sd.b] - nh[sd.nb];
          if (dropA < 0.01 && dropB < 0.01) continue;
          const A = P[sd.a], B = P[sd.b];
          const lowA = Math.min(A[1], nh[sd.na]), lowB = Math.min(B[1], nh[sd.nb]);
          const intoVoid = sd.n.isVoid;
          const wallTop = scaled(tint, intoVoid ? 0.4 : 0.9), wallLow = intoVoid ? [0, 0, 0] : scaled(tint, 0.25);
          walls.quad([A, B, [B[0], lowB, B[2]], [A[0], lowA, A[2]]], [wallTop, wallTop, wallLow, wallLow], null);
          // glowing strips lie on the top surface, just inside the edge
          const strip = function (batch, width, lift, color) {
            const ax = A[0] + sd.inX * width, az = A[2] + sd.inZ * width, bx = B[0] + sd.inX * width, bz = B[2] + sd.inZ * width;
            const ay = surface(t, (ax - x0) / TILE, (z0 - az) / TILE), by = surface(t, (bx - x0) / TILE, (z0 - bz) / TILE);
            batch.quad([[A[0], A[1] + lift, A[2]], [B[0], B[1] + lift, B[2]], [bx, by + lift, bz], [ax, ay + lift, az]], color, null);
          };
          // an edge over the void glows red (danger); other edges glow in their floor's colour
          strip(edges, intoVoid ? 0.22 : 0.16, 0.04, intoVoid ? HAZARD : glow);
          strip(halos, 0.8, 0.03, intoVoid ? HAZARD : glow);
        }
      }
    }

    // Dim towers beyond the level's edges, so the screen is always full and no edge shows
    const towerTint = [0.035, 0.05, 0.11];
    for (let r = -10; r < level.rows + 12; r++) {
      for (let c = -4; c < COLS + 4; c++) {
        if (c >= 0 && c < COLS && r >= 0 && r < level.rows) continue;
        // South of the level the scenery is sunken, not tall: the camera looks from the south,
        // so anything tall there would hide the tank.
        const top = r < 0 ? -0.6 - Math.floor(hash(c, r) * 3) * 0.7 : 7 + Math.floor(hash(c, r) * 4) * 2;
        const x0 = -HALF_WIDTH + c * TILE, x1 = x0 + TILE, z0 = -r * TILE, z1 = z0 - TILE;
        const P = [[x0, top, z0], [x1, top, z0], [x1, top, z1], [x0, top, z1]];
        tops.quad(P, towerTint, [[0, 0], [1, 0], [1, 1], [0, 1]]);
        for (let s = 0; s < 4; s++) {
          const A = P[s], B = P[(s + 1) % 4], hi = scaled(towerTint, 1.6), lo = scaled(towerTint, 0.3);
          walls.quad([A, B, [B[0], PIT_DRAW_DEPTH, B[2]], [A[0], PIT_DRAW_DEPTH, A[2]]], [hi, hi, lo, lo], null);
        }
      }
    }

    const group = new THREE.Group();
    const side = THREE.DoubleSide;
    group.add(tops.mesh(new THREE.MeshBasicMaterial({ map: gridTexture, vertexColors: true, side: side })));
    group.add(ramps.mesh(new THREE.MeshBasicMaterial({ map: chevronTexture, vertexColors: true, side: side })));
    group.add(walls.mesh(new THREE.MeshBasicMaterial({ vertexColors: true, side: side })));
    group.add(edges.mesh(new THREE.MeshBasicMaterial({ vertexColors: true, side: side })));
    group.add(halos.mesh(new THREE.MeshBasicMaterial({ vertexColors: true, side: side, transparent: true, opacity: 0.22,
      blending: THREE.AdditiveBlending, depthWrite: false })));
    return group;
  };

  N.disposeScenery = function (group) {
    group.traverse(function (o) { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); });
  };
})();
