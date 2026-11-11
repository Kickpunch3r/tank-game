// Neon Treads: the game itself. Reads levels (levels.js) through world.js.
// Sections, top to bottom: settings, scene, effects, sound, tank, laser, characters,
// level loading, progress and HUD, controls, camera, main loop, test hooks.
"use strict";
(function () {
  const N = window.NEON;
  if (!window.THREE || !N || !window.NEON_LEVELS) { document.getElementById("fail").hidden = false; return; }
  const LEVELS = window.NEON_LEVELS;

  // ------------------------------------------------------------------
  // Settings (the numbers worth tweaking)
  // ------------------------------------------------------------------
  const SET = {
    // driving
    maxSpeed: 5.5, treadAccel: 10, turnScale: 0.36, trackWidth: 1.6,
    maxClimbDeg: 42,        // ramps are 27 degrees; the tank stalls on anything this steep
    downhillBoost: 0.25, wallDeg: 50, gravity: 22,
    stepUp: 0.4,            // the tank can bump up a step this small (e.g. the low end of a ramp's side)
    teeterZone: 0.7, teeterLean: 0.14, tiltSpring: 120, tiltDamping: 9,
    // player
    maxHealth: 4, hurtSafeSeconds: 1.2, respawnSeconds: 0.9,
    // laser
    laserRange: 30, laserSeconds: 0.4, reloadSeconds: 0.8, recoilKick: 1.6,
    aimAssistDeg: 16,       // the beam bends onto an enemy this close to straight ahead
    shakeThreshold: 14,
    // enemies
    turretRange: 17, turretReload: 2.4, boltSpeed: 9,
    droneRange: 14, droneSpeed: 3.4,
    sweeperSpeed: 2.6,
    wardenHealth: 10, wardenReload: 2.0,
    // camera
    viewWidth: 28
  };
  const CYAN = 0x4ff0ff, RED = 0xff3350, ORANGE = 0xff8a3c, GOLD = 0xffc94a, WHITE = 0xffffff;

  // ------------------------------------------------------------------
  // Scene
  // ------------------------------------------------------------------
  const canvas = document.getElementById("view");
  const renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true });
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x03050b);
  const camera = new THREE.PerspectiveCamera(35, 1, 5, 800);

  // A solid shape with bright outlines: the look of everything that moves.
  function neon(geometry, fillHex, edgeHex) {
    const g = new THREE.Group();
    const fill = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color: fillHex }));
    const lines = new THREE.LineSegments(new THREE.EdgesGeometry(geometry), new THREE.LineBasicMaterial({ color: edgeHex }));
    g.add(fill); g.add(lines);
    g.userData.fill = fill.material; g.userData.baseFill = fillHex;
    return g;
  }
  function solid(geometry, hex, opacity) {
    const opts = { color: hex };
    if (opacity !== undefined) { opts.transparent = true; opts.opacity = opacity; opts.depthWrite = false; opts.side = THREE.DoubleSide; }
    return new THREE.Mesh(geometry, new THREE.MeshBasicMaterial(opts));
  }
  // A soft pool of light on the floor under a character, so it stands out from above.
  const poolGeo = new THREE.CircleGeometry(1, 24);
  function floorGlow(radius, hex, opacity) {
    const m = new THREE.Mesh(poolGeo, new THREE.MeshBasicMaterial({ color: hex, transparent: true, opacity: opacity || 0.3,
      blending: THREE.AdditiveBlending, depthWrite: false }));
    m.rotation.x = -Math.PI / 2; m.position.y = 0.08; m.scale.setScalar(radius);
    return m;
  }
  function disposeTree(obj) {
    obj.traverse(function (o) { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); });
  }

  // ------------------------------------------------------------------
  // Effects: sparks, glow balls, the laser beam
  // ------------------------------------------------------------------
  const SPARK_COUNT = 220;
  const sparkMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshBasicMaterial({ color: 0xffffff }), SPARK_COUNT);
  sparkMesh.frustumCulled = false;
  const sparks = [], sparkDummy = new THREE.Object3D(), sparkColor = new THREE.Color();
  for (let i = 0; i < SPARK_COUNT; i++) {
    sparks.push({ pos: new THREE.Vector3(), vel: new THREE.Vector3(), age: 1, life: 1, size: 0, hot: new THREE.Color(), cool: new THREE.Color() });
    sparkDummy.scale.setScalar(0); sparkDummy.updateMatrix();
    sparkMesh.setMatrixAt(i, sparkDummy.matrix);
    sparkMesh.setColorAt(i, sparkColor.set(0xffffff));
  }
  scene.add(sparkMesh);
  let nextSpark = 0;
  // Throws `count` sparks from `pos`, mostly along `dir`; spread 0 = tight jet, 1 = all directions.
  function burst(pos, dir, count, speed, spread, seconds, hotHex, coolHex) {
    for (let n = 0; n < count; n++) {
      const sp = sparks[nextSpark]; nextSpark = (nextSpark + 1) % SPARK_COUNT;
      sp.pos.copy(pos);
      sp.vel.set(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).normalize().multiplyScalar(spread)
        .add(dir).normalize().multiplyScalar(speed * (0.35 + 0.65 * Math.random()));
      sp.age = 0; sp.life = seconds * (0.5 + 0.5 * Math.random()); sp.size = 0.18 + 0.24 * Math.random();
      sp.hot.set(hotHex); sp.cool.set(coolHex);
    }
  }
  const UP = new THREE.Vector3(0, 1, 0);

  const glowGeo = new THREE.SphereGeometry(1, 12, 8);
  const glows = [];
  function addGlow(pos, size, seconds, hex) {
    const mesh = new THREE.Mesh(glowGeo, new THREE.MeshBasicMaterial({ color: hex, transparent: true, opacity: 0.85,
      blending: THREE.AdditiveBlending, depthWrite: false }));
    mesh.position.copy(pos);
    scene.add(mesh);
    glows.push({ mesh: mesh, age: 0, life: seconds, size: size });
  }

  const beamGeo = new THREE.CylinderGeometry(1, 1, 1, 10, 1, true);
  const BEAM_LAYERS = [
    { radius: 0.85, color: 0x1890ff, opacity: 0.25 },
    { radius: 0.42, color: 0x5fe8ff, opacity: 0.6 },
    { radius: 0.16, color: 0xffffff, opacity: 1.0 }
  ];
  const beam = { group: new THREE.Group(), age: Infinity, length: 1, meshes: [] };
  BEAM_LAYERS.forEach(function (layer) {
    const mesh = new THREE.Mesh(beamGeo, new THREE.MeshBasicMaterial({ color: layer.color, transparent: true, opacity: layer.opacity,
      blending: THREE.AdditiveBlending, depthWrite: false }));
    beam.group.add(mesh); beam.meshes.push(mesh);
  });
  beam.group.visible = false;
  scene.add(beam.group);

  function stepEffects(dt) {
    if (beam.group.visible) {
      beam.age += dt;
      const t = beam.age / SET.laserSeconds;
      if (t >= 1) beam.group.visible = false;
      else {
        const width = t < 0.12 ? 1 + 0.8 * (t / 0.12) : 1.8 * (1 - (t - 0.12) / 0.88);
        for (let i = 0; i < beam.meshes.length; i++) {
          beam.meshes[i].scale.set(BEAM_LAYERS[i].radius * width, beam.length, BEAM_LAYERS[i].radius * width);
          beam.meshes[i].material.opacity = BEAM_LAYERS[i].opacity * (1 - t * t);
        }
      }
    }
    for (let i = glows.length - 1; i >= 0; i--) {
      const gl = glows[i];
      gl.age += dt;
      const t = gl.age / gl.life;
      if (t >= 1) { scene.remove(gl.mesh); gl.mesh.material.dispose(); glows.splice(i, 1); continue; }
      gl.mesh.scale.setScalar(gl.size * (0.4 + 0.6 * t));
      gl.mesh.material.opacity = 0.85 * (1 - t);
    }
    for (let i = 0; i < SPARK_COUNT; i++) {
      const sp = sparks[i];
      if (sp.age >= sp.life) continue;
      sp.age += dt;
      const t = Math.min(1, sp.age / sp.life);
      sp.vel.multiplyScalar(Math.exp(-dt * 4)); sp.vel.y -= 9 * dt;
      sp.pos.addScaledVector(sp.vel, dt);
      sparkDummy.position.copy(sp.pos);
      sparkDummy.scale.setScalar(sp.size * (1 - t));
      sparkDummy.rotation.set(sp.age * 9, sp.age * 7, 0);
      sparkDummy.updateMatrix();
      sparkMesh.setMatrixAt(i, sparkDummy.matrix);
      sparkMesh.setColorAt(i, sparkColor.copy(sp.hot).lerp(sp.cool, t));
    }
    sparkMesh.instanceMatrix.needsUpdate = true;
    sparkMesh.instanceColor.needsUpdate = true;
  }

  // ------------------------------------------------------------------
  // Sound: tiny synthesised bleeps, no audio files. Starts after the first tap.
  // ------------------------------------------------------------------
  const sound = { ctx: null, on: true };
  function soundStart() {
    if (sound.ctx) return;
    try { sound.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { sound.ctx = null; }
  }
  // One note that slides from `from` to `to` hertz.
  function tone(from, to, seconds, shape, volume, delay) {
    if (!sound.ctx || !sound.on) return;
    try {
      const t0 = sound.ctx.currentTime + (delay || 0);
      const osc = sound.ctx.createOscillator(), gain = sound.ctx.createGain();
      osc.type = shape;
      osc.frequency.setValueAtTime(from, t0);
      osc.frequency.exponentialRampToValueAtTime(Math.max(20, to), t0 + seconds);
      gain.gain.setValueAtTime(volume, t0);
      gain.gain.exponentialRampToValueAtTime(0.001, t0 + seconds);
      osc.connect(gain); gain.connect(sound.ctx.destination);
      osc.start(t0); osc.stop(t0 + seconds + 0.02);
    } catch (e) { /* sound is optional */ }
  }
  const sfx = {
    laser: function () { tone(1400, 220, 0.22, "sawtooth", 0.12); },
    enemyShot: function () { tone(520, 300, 0.12, "square", 0.05); },
    hit: function () { tone(300, 120, 0.12, "square", 0.09); },
    boom: function () { tone(180, 40, 0.35, "sawtooth", 0.16); tone(90, 30, 0.4, "square", 0.1); },
    hurt: function () { tone(220, 60, 0.3, "sawtooth", 0.15); },
    rescue: function () { tone(660, 660, 0.1, "sine", 0.12); tone(880, 880, 0.1, "sine", 0.12, 0.09); tone(1320, 1320, 0.18, "sine", 0.12, 0.18); },
    checkpoint: function () { tone(440, 880, 0.2, "triangle", 0.1); },
    gateOpen: function () { tone(300, 1200, 0.5, "triangle", 0.1); },
    levelDone: function () { tone(523, 523, 0.12, "sine", 0.13); tone(659, 659, 0.12, "sine", 0.13, 0.12); tone(784, 784, 0.12, "sine", 0.13, 0.24); tone(1047, 1047, 0.3, "sine", 0.13, 0.36); },
    snatch: function () { tone(900, 90, 0.7, "sawtooth", 0.12); }
  };

  // ------------------------------------------------------------------
  // The tank: kinematic. It rests on the floor like a stiff plank, so it tilts on ramps,
  // leans when its middle nears an edge, tips over and falls.
  // ------------------------------------------------------------------
  let level = null;                       // the level being played (from N.parseLevel)
  function groundHeight(x, z) { return level.heightAt(x, z); }

  const TANK_LEN = 2.4, TANK_WIDTH = 1.5;
  function buildTankModel() {
    const g = new THREE.Group();
    function part(w, h, d, fill, x, y, z) {
      const p = neon(new THREE.BoxGeometry(w, h, d), fill, CYAN);
      p.position.set(x, y, z); g.add(p); return p;
    }
    part(0.36, 0.5, TANK_LEN, 0x0b4a5c, -0.57, 0.25, 0);     // left tread
    part(0.36, 0.5, TANK_LEN, 0x0b4a5c, 0.57, 0.25, 0);      // right tread
    part(0.9, 0.42, 2.1, 0x1aa3c2, 0, 0.45, 0);              // hull
    part(0.74, 0.34, 0.9, 0x5fe4f7, 0, 0.83, 0.15);          // turret
    part(0.14, 0.14, 1.3, 0xbffaff, 0, 0.85, -0.9);          // barrel (forward is -Z)
    const stripe = solid(new THREE.BoxGeometry(0.16, 0.04, 0.8), 0xbffaff);
    stripe.position.set(0, 1.02, 0.15); g.add(stripe);
    g.add(floorGlow(2.0, CYAN, 0.28));
    return g;
  }
  const tankModel = buildTankModel();
  tankModel.rotation.order = "YXZ";
  scene.add(tankModel);

  const ALONG = [], ACROSS = [-TANK_WIDTH / 2, 0, TANK_WIDTH / 2];
  for (let i = -6; i <= 6; i++) ALONG.push(i * (TANK_LEN / 12));
  const tank = { x: 0, z: 0, yaw: 0, y: 0, vy: 0, pitch: 0, roll: 0, pitchVel: 0, rollVel: 0,
                 treadL: 0, treadR: 0, speed: 0, grounded: true };
  const levers = { left: 0, right: 0 };

  function sampleFootprint(x, z, yaw, out) {
    const fx = -Math.sin(yaw), fz = -Math.cos(yaw), rx = Math.cos(yaw), rz = -Math.sin(yaw);
    let n = 0;
    for (let i = 0; i < ALONG.length; i++) {
      for (let j = 0; j < ACROSS.length; j++) {
        const px = x + fx * ALONG[i] + rx * ACROSS[j], pz = z + fz * ALONG[i] + rz * ACROSS[j];
        out.px[n] = px; out.pz[n] = pz; out.h[n] = groundHeight(px, pz); n++;
      }
    }
    return out;
  }
  function newFootprint() {
    const n = ALONG.length * ACROSS.length;
    return { px: new Float32Array(n), pz: new Float32Array(n), h: new Float32Array(n) };
  }
  const fpNow = newFootprint(), fpTry = newFootprint();
  const profAlong = new Float32Array(ALONG.length), profAcross = new Float32Array(ACROSS.length);

  // Where a stiff plank rests on a row of floor heights, measured at its middle: height, slope,
  // and a "lean" when the middle is close to an unsupported end (the teeter before tipping).
  function restOnProfile(offs, prof, res) {
    const c = (offs.length - 1) / 2;
    let best = -Infinity, slope = 0;
    for (let i = 0; i < c; i++) {
      for (let k = c + 1; k < offs.length; k++) {
        const s = (prof[k] - prof[i]) / (offs[k] - offs[i]);
        const hMid = prof[i] - s * offs[i];
        if (hMid > best + 1e-5) { best = hMid; slope = s; }
      }
    }
    if (prof[c] > best + 1e-3) { best = prof[c]; slope = 0; }
    let gapFront = Infinity, gapBack = Infinity;
    for (let k = c + 1; k < offs.length; k++) { if (prof[k] < best + slope * offs[k] - 0.35) { gapFront = offs[k]; break; } }
    for (let i = c - 1; i >= 0; i--) { if (prof[i] < best + slope * offs[i] - 0.35) { gapBack = -offs[i]; break; } }
    let lean = 0;
    if (gapFront < SET.teeterZone) lean += 1 - gapFront / SET.teeterZone;
    if (gapBack < SET.teeterZone) lean -= 1 - gapBack / SET.teeterZone;
    res.height = best; res.slope = slope; res.lean = lean * SET.teeterLean;
    return res;
  }
  const restAlong = { height: 0, slope: 0, lean: 0 }, restAcross = { height: 0, slope: 0, lean: 0 };
  function solveRest(fp) {
    const na = ALONG.length, nc = ACROSS.length;
    for (let i = 0; i < na; i++) { let m = -Infinity; for (let j = 0; j < nc; j++) m = Math.max(m, fp.h[i * nc + j]); profAlong[i] = m; }
    for (let j = 0; j < nc; j++) { let m = -Infinity; for (let i = 0; i < na; i++) m = Math.max(m, fp.h[i * nc + j]); profAcross[j] = m; }
    restOnProfile(ALONG, profAlong, restAlong);
    restOnProfile(ACROSS, profAcross, restAcross);
  }
  // Would this move push part of the tank into a wall (floor rising too steeply)?
  function hitsWall(a, b) {
    const wallSlope = Math.tan(SET.wallDeg * Math.PI / 180);
    for (let n = 0; n < a.h.length; n++) {
      const d = Math.hypot(b.px[n] - a.px[n], b.pz[n] - a.pz[n]);
      if (d < 1e-4) continue;
      const rise = b.h[n] - a.h[n];
      if (rise > SET.stepUp && b.h[n] > tank.y + 0.05 && rise / d > wallSlope) return true;
    }
    return false;
  }
  function placeTank(x, z, yaw) {
    tank.x = x; tank.z = z; tank.yaw = yaw;
    tank.vy = 0; tank.pitch = 0; tank.roll = 0; tank.pitchVel = 0; tank.rollVel = 0;
    tank.treadL = 0; tank.treadR = 0; tank.speed = 0;
    sampleFootprint(x, z, yaw, fpNow); solveRest(fpNow);
    tank.y = Math.min(restAlong.height, restAcross.height); tank.grounded = true;
  }
  function approach(v, target, maxStep) { return v < target ? Math.min(target, v + maxStep) : Math.max(target, v - maxStep); }

  const TANK_MARGIN = 1.4;
  function stepTank(dt) {
    sampleFootprint(tank.x, tank.z, tank.yaw, fpNow); solveRest(fpNow);
    let yawRate = 0;
    if (tank.grounded) {
      tank.treadL = approach(tank.treadL, levers.left * SET.maxSpeed, SET.treadAccel * dt);
      tank.treadR = approach(tank.treadR, levers.right * SET.maxSpeed, SET.treadAccel * dt);
      let v = (tank.treadL + tank.treadR) / 2;
      const grade = restAlong.slope * Math.sign(v), stall = Math.tan(SET.maxClimbDeg * Math.PI / 180);
      if (grade > 0) v *= Math.max(0, 1 - Math.pow(grade / stall, 1.5));
      else v *= 1 + Math.min(SET.downhillBoost, -grade * 0.5);
      tank.speed = v;
      yawRate = (tank.treadR - tank.treadL) / SET.trackWidth * SET.turnScale;
    }
    const fx = -Math.sin(tank.yaw), fz = -Math.cos(tank.yaw);
    // invisible walls: the screen's side edges and the level's two ends
    const nz = Math.min(-TANK_MARGIN, Math.max(-level.length + TANK_MARGIN, tank.z + fz * tank.speed * dt));
    const sideLimit = (N.HALF_WIDTH - TANK_MARGIN) * visibleWidthFactor(nz);
    const nx = Math.min(sideLimit, Math.max(-sideLimit, tank.x + fx * tank.speed * dt));
    const nyaw = tank.yaw + yawRate * dt;
    if (!hitsWall(fpNow, sampleFootprint(nx, nz, nyaw, fpTry))) {
      tank.x = nx; tank.z = nz; tank.yaw = nyaw;                      // the whole move is clear
    } else {
      // Something is in the way. Do whatever part of the move is possible.
      let moved = false, turned = yawRate === 0;
      // drive on without turning; failing that, slide along the wall (east-west only, or
      // north-south only)
      const tries = tank.speed !== 0 ? [[nx, nz], [nx, tank.z], [tank.x, nz]] : [];
      for (let k = 0; k < tries.length && !moved; k++) {
        if (!hitsWall(fpNow, sampleFootprint(tries[k][0], tries[k][1], tank.yaw, fpTry))) {
          tank.x = tries[k][0]; tank.z = tries[k][1]; moved = true;
          sampleFootprint(tank.x, tank.z, tank.yaw, fpNow);
        }
      }
      if (!moved) tank.speed = 0;
      if (!turned && !hitsWall(fpNow, sampleFootprint(tank.x, tank.z, nyaw, fpTry))) { tank.yaw = nyaw; turned = true; }
      // Against a wall and trying to turn: shuffle a little away from it while turning, so the
      // tank can always pivot free instead of sticking.
      const rx = Math.cos(tank.yaw), rz = -Math.sin(tank.yaw);
      const shuffles = [[-fx, -fz], [fx, fz], [rx, rz], [-rx, -rz]];
      for (let k = 0; k < shuffles.length && !turned; k++) {
        const sx = tank.x + shuffles[k][0] * 0.07, sz = tank.z + shuffles[k][1] * 0.07;
        if (Math.abs(sx) <= sideLimit && !hitsWall(fpNow, sampleFootprint(sx, sz, nyaw, fpTry))) { tank.x = sx; tank.z = sz; tank.yaw = nyaw; turned = true; }
      }
      if (!moved && (!turned || yawRate === 0)) { tank.treadL *= 0.5; tank.treadR *= 0.5; }
    }

    sampleFootprint(tank.x, tank.z, tank.yaw, fpNow); solveRest(fpNow);
    const support = Math.min(restAlong.height, restAcross.height);
    tank.vy -= SET.gravity * dt;
    tank.y += tank.vy * dt;
    if (tank.y <= support) { tank.y = support; tank.vy = 0; }
    tank.grounded = tank.y - support < 0.15;

    const k = tank.grounded ? SET.tiltSpring : SET.tiltSpring * 0.2, c = tank.grounded ? SET.tiltDamping : SET.tiltDamping * 0.45;
    const pitchTarget = Math.max(-1.25, Math.min(1.25, Math.atan(restAlong.slope) - restAlong.lean));
    const rollTarget = Math.max(-1.25, Math.min(1.25, Math.atan(restAcross.slope) - restAcross.lean));
    tank.pitchVel += ((pitchTarget - tank.pitch) * k - tank.pitchVel * c) * dt;
    tank.rollVel += ((rollTarget - tank.roll) * k - tank.rollVel * c) * dt;
    tank.pitch += tank.pitchVel * dt;
    tank.roll += tank.rollVel * dt;
  }

  // ------------------------------------------------------------------
  // Player state and the laser
  // ------------------------------------------------------------------
  const player = { health: SET.maxHealth, safe: 0, dead: false, respawnIn: 0, checkpoint: { x: 0, z: 0 }, god: false };
  const cannon = { reload: 0, recoil: 0, shotsFired: 0, lastHit: null };
  const tankQuat = new THREE.Quaternion(), tankEuler = new THREE.Euler(0, 0, 0, "YXZ");
  const tmpV = new THREE.Vector3();

  function hurtPlayer() {
    if (player.dead || player.safe > 0 || player.god || state !== "play") return;
    player.health--;
    player.safe = SET.hurtSafeSeconds;
    burst(tmpV.set(tank.x, tank.y + 0.7, tank.z), UP, 16, 8, 1, 0.5, WHITE, CYAN);
    sfx.hurt();
    if (player.health <= 0) killPlayer();
    drawHud();
  }
  function killPlayer() {
    if (player.dead) return;
    player.dead = true; player.respawnIn = SET.respawnSeconds;
    tankModel.visible = false;
    tmpV.set(tank.x, Math.max(tank.y, -3) + 0.7, tank.z);
    burst(tmpV, UP, 60, 13, 1, 0.9, WHITE, CYAN);
    addGlow(tmpV, 2.6, 0.5, CYAN);
    sfx.boom();
  }
  function respawnPlayer() {
    player.dead = false; player.health = SET.maxHealth; player.safe = SET.hurtSafeSeconds;
    placeTank(player.checkpoint.x, player.checkpoint.z, 0);
    tankModel.visible = true;
    trail.length = 0;
    drawHud();
  }

  // Returns true if the laser fired (false while reloading or not playing).
  function fireLaser() {
    if (state !== "play" || player.dead || cannon.reload > 0) return false;
    tankEuler.set(tank.pitch, tank.yaw, tank.roll);
    tankQuat.setFromEuler(tankEuler);
    const dir = new THREE.Vector3(0, 0, -1).applyQuaternion(tankQuat);
    const muzzle = new THREE.Vector3(0, 0.85, -1.6).applyQuaternion(tankQuat);
    muzzle.x += tank.x; muzzle.y += tank.y; muzzle.z += tank.z;

    // Aim help: if an enemy is nearly straight ahead, the beam bends onto it (up or down too).
    const fx = -Math.sin(tank.yaw), fz = -Math.cos(tank.yaw);
    let target = null, bestAngle = SET.aimAssistDeg * Math.PI / 180;
    for (let i = 0; i < actors.length; i++) {
      const a = actors[i];
      if (!a.alive || !a.hostile) continue;
      const dx = a.x - tank.x, dz = a.z - tank.z, d = Math.hypot(dx, dz);
      if (d < 1 || d > SET.laserRange) continue;
      const angle = Math.acos(Math.max(-1, Math.min(1, (dx * fx + dz * fz) / d)));
      if (angle < bestAngle) { bestAngle = angle; target = a; }
    }
    if (target) dir.set(target.x - muzzle.x, target.cy - muzzle.y, target.z - muzzle.z).normalize();

    // Walk along the beam until it meets an enemy, a block, the floor, or runs out of range.
    const end = muzzle.clone();
    let reach = 0, hitWhat = "nothing";
    walk:
    while (reach < SET.laserRange) {
      reach += 0.25;
      end.copy(dir).multiplyScalar(reach).add(muzzle);
      for (let i = 0; i < actors.length; i++) {
        const a = actors[i];
        if (!a.alive || !a.hostile) continue;
        if (Math.hypot(a.x - end.x, a.cy - end.y, a.z - end.z) < a.radius) { damageActor(a, 1); hitWhat = a.kind; break walk; }
      }
      if (end.y <= groundHeight(end.x, end.z)) {
        const t = level.tileAtXZ(end.x, end.z);
        if (t.block && t.block.alive) { damageActor(t.block, 1); hitWhat = "block"; } else hitWhat = "floor";
        break;
      }
    }
    cannon.lastHit = { what: hitWhat, reach: reach, x: end.x, y: end.y, z: end.z, aimed: !!target };

    beam.length = reach; beam.age = 0;
    beam.group.position.copy(muzzle).add(end).multiplyScalar(0.5);
    beam.group.quaternion.setFromUnitVectors(UP, dir);
    beam.group.visible = true;
    addGlow(muzzle, 1.4, 0.22, 0xbffaff);
    burst(muzzle, dir, 30, 17, 0.45, 0.4, WHITE, CYAN);                          // muzzle flash
    if (hitWhat !== "nothing") {
      addGlow(end, 2.0, 0.4, CYAN);
      burst(end, tmpV.set(-dir.x * 0.5, 1, -dir.z * 0.5).normalize(), 24, 10, 0.8, 0.6, WHITE, CYAN);
    }
    cannon.reload = SET.reloadSeconds; cannon.recoil = 0.3; cannon.shotsFired++;
    tank.pitchVel += SET.recoilKick;
    sfx.laser();
    return true;
  }

  // ------------------------------------------------------------------
  // Characters and things in the level. Each is an "actor":
  //   hostile ones (turret, drone, sweeper, warden) can be shot and can hurt the tank;
  //   friendly ones (bit, guide) are rescued; the rest are checkpoints, the exit and blocks.
  // ------------------------------------------------------------------
  let actors = [], bolts = [], followers = [], trail = [];
  let levelGroup = null, sceneryGroup = null;
  let bitsTotal = 0, bitsFreed = 0, exitActor = null, warden = null, exitWasOpen = false;

  function wardenModel() {
    const g = new THREE.Group();
    const body = neon(new THREE.IcosahedronGeometry(1.7, 0), 0x3a0612, RED);
    const ring = solid(new THREE.TorusGeometry(2.5, 0.09, 6, 28), ORANGE);
    ring.rotation.x = Math.PI / 2;
    const eye = solid(new THREE.SphereGeometry(0.55, 12, 8), 0xffd0a0);
    eye.position.set(0, 0, -1.45);
    g.add(body); g.add(ring); g.add(eye);
    g.userData.fill = body.userData.fill; g.userData.baseFill = body.userData.baseFill; g.userData.ring = ring;
    return g;
  }
  function guideModel() {
    const g = new THREE.Group();
    const body = neon(new THREE.OctahedronGeometry(0.6, 0), 0xfff0c0, WHITE);
    body.scale.set(1, 2.2, 1); body.position.y = 1.7;
    const halo = solid(new THREE.TorusGeometry(0.95, 0.05, 6, 24), GOLD);
    halo.rotation.x = Math.PI / 2; halo.position.y = 1.7;
    g.add(body); g.add(halo);
    g.userData.halo = halo;
    return g;
  }
  function bitModel() { return neon(new THREE.BoxGeometry(0.55, 0.55, 0.55), GOLD, 0xfff6c8); }
  function cageModel(size, height) {
    return new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(size, height, size)), new THREE.LineBasicMaterial({ color: RED }));
  }

  function makeActor(spawn) {
    const kind = spawn.kind, x = spawn.x, z = spawn.z, floor = spawn.tile.tier * N.TIER;
    const a = { kind: kind, x: x, y: floor, z: z, cy: floor + 0.8, alive: true, hostile: false, hp: 1, radius: 1, flash: 0, t: Math.random() * 6, group: new THREE.Group(), spawn: spawn };
    a.group.position.set(x, floor, z);
    if (kind === "t") {                                   // turret
      a.hostile = true; a.hp = 2; a.radius = 1.3; a.cy = floor + 1.5; a.reload = 1 + Math.random();
      const base = neon(new THREE.CylinderGeometry(0.7, 1.15, 1.3, 8), 0x2a0808, RED); base.position.y = 0.65;
      a.head = new THREE.Group(); a.head.position.y = 1.6;
      const box = neon(new THREE.BoxGeometry(0.85, 0.5, 0.85), 0x5a1010, RED);
      const barrel = solid(new THREE.BoxGeometry(0.2, 0.2, 1.1), ORANGE); barrel.position.z = -0.8;
      a.head.add(box); a.head.add(barrel);
      a.group.add(base); a.group.add(a.head); a.group.add(floorGlow(1.9, RED));
      a.fills = [base.userData.fill, box.userData.fill];
    } else if (kind === "d") {                            // drone
      a.hostile = true; a.hp = 1; a.radius = 1.1; a.awake = false;
      a.body = neon(new THREE.OctahedronGeometry(0.75, 0), 0x4a0c0c, ORANGE);
      a.body.position.y = 1.3; a.group.add(a.body); a.y = floor + 1.3; a.cy = a.y;
      a.fills = [a.body.userData.fill];
    } else if (kind === "h" || kind === "p") {            // sweeper
      a.hostile = true; a.hp = 3; a.radius = 1.4; a.cy = floor + 0.5;
      a.dirX = kind === "h" ? 1 : 0; a.dirZ = kind === "p" ? 1 : 0; a.home = floor;
      a.body = neon(new THREE.CylinderGeometry(1.2, 1.2, 0.45, 6), 0x4a0a1c, RED); a.body.position.y = 0.45;
      const core = solid(new THREE.SphereGeometry(0.42, 10, 8), ORANGE); core.position.y = 0.6;
      const arm = solid(new THREE.BoxGeometry(3.0, 0.14, 0.2), ORANGE); arm.position.y = 0.45; a.body.add(arm);
      a.group.add(a.body); a.group.add(core); a.group.add(floorGlow(2.0, RED));
      a.fills = [a.body.userData.fill];
    } else if (kind === "W") {                            // the Warden (boss)
      a.hostile = true; a.hp = SET.wardenHealth; a.radius = 2.3; a.reload = 2; a.awake = false; a.homeX = x; a.spawnedAt = {};
      a.model = wardenModel(); a.model.position.y = 2.6; a.group.add(a.model);
      a.cy = floor + 2.6; a.fills = [a.model.userData.fill]; a.group.add(floorGlow(3.4, RED, 0.35));
      a.pips = new THREE.Group(); a.pips.position.y = 5.2; a.group.add(a.pips);
      warden = a;
    } else if (kind === "f") {                            // caged friend
      a.bit = bitModel(); a.bit.position.y = 0.8;
      a.cage = cageModel(1.6, 1.6); a.cage.position.y = 0.8;
      a.group.add(a.bit); a.group.add(a.cage); a.group.add(floorGlow(1.6, GOLD, 0.35));
      bitsTotal++;
    } else if (kind === "G") {                            // the Guide, about to be snatched
      a.guide = guideModel(); a.group.add(a.guide); a.guide.add(floorGlow(1.8, GOLD, 0.35));
      a.puppet = wardenModel(); a.puppet.scale.setScalar(0.8); a.puppet.visible = false; a.group.add(a.puppet);
      a.phase = "wait"; a.clock = 0;
    } else if (kind === "g") {                            // the Guide, caged behind the Warden
      a.guide = guideModel(); a.cage = cageModel(2.2, 3.4); a.cage.position.y = 1.7;
      a.group.add(a.guide); a.group.add(a.cage); a.guide.add(floorGlow(1.8, GOLD, 0.35)); a.freed = false;
    } else if (kind === "C" || kind === "S") {            // checkpoint pad (the start is one too)
      a.ring = solid(new THREE.RingGeometry(1.15, 1.45, 28), 0x13566a, 0.9);
      a.ring.rotation.x = -Math.PI / 2; a.ring.position.y = 0.06; a.group.add(a.ring);
      a.active = false;
    } else if (kind === "E") {                            // exit gate
      a.ring = solid(new THREE.TorusGeometry(1.75, 0.14, 8, 28), RED); a.ring.position.y = 2.0;
      a.disc = solid(new THREE.CircleGeometry(1.65, 28), RED, 0.25); a.disc.position.y = 2.0;
      a.group.add(a.ring); a.group.add(a.disc);
      exitActor = a;
    } else if (kind === "B") {                            // firewall block
      a.hp = 2; a.tile = spawn.tile; spawn.tile.block = a;
      a.body = neon(new THREE.BoxGeometry(N.TILE - 0.3, N.BLOCK_HEIGHT, N.TILE - 0.3), 0x7a3200, 0xffb060);
      a.body.userData.fill.transparent = true; a.body.userData.fill.opacity = 0.55;
      a.body.position.y = N.BLOCK_HEIGHT / 2; a.group.add(a.body);
      a.cy = floor + 1.3; a.fills = [a.body.userData.fill];
    }
    levelGroup.add(a.group);
    return a;
  }

  function damageActor(a, amount) {
    if (!a.alive) return;
    a.hp -= amount; a.flash = 0.12;
    if (a.kind === "W") a.awake = true;
    if (a.hp > 0) { sfx.hit(); return; }
    a.alive = false; a.group.visible = false;
    tmpV.set(a.x, a.cy, a.z);
    const big = a.kind === "W";
    burst(tmpV, UP, big ? 120 : 40, big ? 16 : 11, 1, big ? 1.4 : 0.8, WHITE, a.kind === "B" ? ORANGE : RED);
    addGlow(tmpV, big ? 6 : 2.4, big ? 0.9 : 0.45, ORANGE);
    sfx.boom();
    if (big) onWardenBeaten();
  }

  function fireBolt(x, y, z, tx, ty, tz) {
    const d = Math.hypot(tx - x, ty - y, tz - z) || 1;
    const mesh = new THREE.Group();
    mesh.add(solid(new THREE.SphereGeometry(0.26, 10, 8), 0xffe0b0));
    const halo = new THREE.Mesh(glowGeo, new THREE.MeshBasicMaterial({ color: RED, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false }));
    halo.scale.setScalar(0.6); mesh.add(halo);
    mesh.position.set(x, y, z);
    levelGroup.add(mesh);
    bolts.push({ mesh: mesh, vx: (tx - x) / d * SET.boltSpeed, vy: (ty - y) / d * SET.boltSpeed, vz: (tz - z) / d * SET.boltSpeed, life: 3.5 });
    sfx.enemyShot();
  }
  function stepBolts(dt) {
    for (let i = bolts.length - 1; i >= 0; i--) {
      const b = bolts[i], p = b.mesh.position;
      p.x += b.vx * dt; p.y += b.vy * dt; p.z += b.vz * dt; b.life -= dt;
      let gone = b.life <= 0 || p.y <= groundHeight(p.x, p.z);
      if (!gone && !player.dead && Math.hypot(p.x - tank.x, p.y - (tank.y + 0.6), p.z - tank.z) < 1.15) { hurtPlayer(); gone = true; }
      if (gone) {
        burst(p, UP, 6, 5, 1, 0.3, 0xffe0b0, RED);
        levelGroup.remove(b.mesh); disposeTree(b.mesh); bolts.splice(i, 1);
      }
    }
  }

  function spawnDrone(x, z) {
    const tile = level.tileAtXZ(x, z);
    const a = makeActor({ kind: "d", x: x, z: z, tile: tile.isVoid ? { tier: 2 } : tile });
    a.awake = true;
    actors.push(a);
    addGlow(tmpV.set(x, a.y, z), 1.8, 0.4, RED);
  }

  function setFlash(a, dt) {
    if (!a.fills) return;
    if (a.flash > 0) { a.flash -= dt; for (let i = 0; i < a.fills.length; i++) a.fills[i].color.set(WHITE); if (a.flash <= 0) a.restore = true; }
    else if (a.restore) { a.restore = false; a.group.traverse(function (o) { if (o.userData && o.userData.fill) o.userData.fill.color.set(o.userData.baseFill); }); }
  }

  function stepActors(dt) {
    const px = tank.x, py = tank.y + 0.6, pz = tank.z, playerUp = !player.dead;
    for (let i = 0; i < actors.length; i++) {
      const a = actors[i];
      if (!a.alive) continue;
      a.t += dt;
      setFlash(a, dt);
      const dx = px - a.x, dz = pz - a.z, dist = Math.hypot(dx, dz);

      if (a.kind === "t") {
        if (playerUp && dist < SET.turretRange) {
          a.head.rotation.y = Math.atan2(-dx, -dz);
          a.reload -= dt;
          const charge = Math.max(0, 1 - a.reload / 0.6);            // swells just before it fires
          a.head.scale.setScalar(1 + 0.25 * charge);
          if (a.reload <= 0) { a.reload = SET.turretReload; fireBolt(a.x, a.y + 1.6, a.z, px, py, pz); }
        } else { a.head.rotation.y += dt * 0.8; a.head.scale.setScalar(1); }

      } else if (a.kind === "d") {
        a.body.rotation.y += dt * 3; a.body.rotation.x += dt * 1.3;
        if (playerUp && dist < SET.droneRange) a.awake = true;
        if (a.awake && playerUp && dist > 0.01) {
          a.x += dx / dist * SET.droneSpeed * dt; a.z += dz / dist * SET.droneSpeed * dt;
        }
        const hover = Math.max(groundHeight(a.x, a.z), tank.y - 1) + 1.3 + 0.15 * Math.sin(a.t * 4);
        a.y += (hover - a.y) * Math.min(1, dt * 4); a.cy = a.y;
        a.group.position.set(a.x, 0, a.z); a.body.position.y = a.y;
        if (playerUp && Math.hypot(dx, a.cy - py, dz) < 1.4) { damageActor(a, 99); hurtPlayer(); }

      } else if (a.kind === "h" || a.kind === "p") {
        a.body.rotation.y += dt * 5;
        const nx = a.x + a.dirX * SET.sweeperSpeed * dt, nz = a.z - a.dirZ * SET.sweeperSpeed * dt;
        const probeX = nx + a.dirX * 1.3, probeZ = nz - a.dirZ * 1.3;
        const blocked = Math.abs(groundHeight(probeX, probeZ) - a.home) > 0.1 || Math.abs(probeX) > N.HALF_WIDTH - 0.2 ||
                        probeZ > -0.2 || probeZ < -level.length + 0.2;
        if (blocked) { a.dirX = -a.dirX; a.dirZ = -a.dirZ; } else { a.x = nx; a.z = nz; }
        a.group.position.set(a.x, a.home, a.z);
        if (playerUp && dist < 1.7 && Math.abs(tank.y - a.home) < 1.5) hurtPlayer();

      } else if (a.kind === "W") {
        if (playerUp && Math.abs(dz) < 22) a.awake = true;
        a.model.userData.ring.rotation.z += dt * 2;
        a.model.rotation.y = Math.atan2(-dx, -dz);
        if (a.awake) {
          a.x = a.homeX + Math.sin(a.t * 0.7) * 8;
          a.group.position.x = a.x;
          a.model.position.y = 2.6 + 0.3 * Math.sin(a.t * 2);
          a.reload -= dt;
          if (playerUp && a.reload <= 0) {
            a.reload = a.hp <= 4 ? SET.wardenReload * 0.7 : SET.wardenReload;
            const oy = a.cy, base = Math.atan2(dx, dz);
            for (let k = -1; k <= 1; k++) {
              const ang = base + k * 0.26, range = Math.max(4, dist);
              fireBolt(a.x, oy, a.z, a.x + Math.sin(ang) * range, py, a.z + Math.cos(ang) * range);
            }
          }
          // calls in drones as it weakens
          [6, 3].forEach(function (mark) {
            if (a.hp <= mark && !a.spawnedAt[mark]) { a.spawnedAt[mark] = true; spawnDrone(a.x - 5, a.z + 2); spawnDrone(a.x + 5, a.z + 2); }
          });
          if (playerUp && Math.hypot(dx, a.cy - py, dz) < a.radius + 0.6) hurtPlayer();
        }
        drawWardenPips(a);

      } else if (a.kind === "f") {
        a.bit.rotation.y += dt * 2; a.bit.position.y = 0.8 + 0.1 * Math.sin(a.t * 3);
        if (playerUp && dist < 1.9 && Math.abs(tank.y - a.y) < 1.5) {          // rescued: joins the tank's tail
          a.alive = false; a.group.remove(a.cage); a.group.remove(a.bit);
          followers.push({ mesh: a.bit, x: a.x, y: a.y + 0.8, z: a.z, t: Math.random() * 6, lift: 0.55 });
          levelGroup.add(a.bit);
          bitsFreed++;
          burst(tmpV.set(a.x, a.y + 0.8, a.z), UP, 26, 8, 1, 0.7, WHITE, GOLD);
          addGlow(tmpV, 1.8, 0.4, GOLD);
          sfx.rescue(); drawHud();
        }

      } else if (a.kind === "C" || a.kind === "S") {
        if (!a.active && playerUp && tank.grounded && dist < 2.2 && Math.abs(tank.y - a.y) < 1) {
          for (let k = 0; k < actors.length; k++) if (actors[k].ring && (actors[k].kind === "C" || actors[k].kind === "S")) { actors[k].active = false; actors[k].ring.material.color.set(0x13566a); }
          a.active = true; a.ring.material.color.set(0x8ffcff);
          player.checkpoint.x = a.x; player.checkpoint.z = a.z;
          if (a.kind === "C") { addGlow(tmpV.set(a.x, a.y + 0.3, a.z), 2.2, 0.5, CYAN); sfx.checkpoint(); }
        }
        a.ring.scale.setScalar(a.active ? 1 + 0.06 * Math.sin(a.t * 4) : 1);

      } else if (a.kind === "E") {
        const open = exitIsOpen();
        a.ring.rotation.z += dt * (open ? 1.6 : 0.2);
        a.ring.material.color.set(open ? 0x8ffcff : RED);
        a.disc.material.color.set(open ? CYAN : RED);
        a.disc.material.opacity = open ? 0.35 + 0.15 * Math.sin(a.t * 5) : 0.2;
        if (open && !exitWasOpen) { exitWasOpen = true; addGlow(tmpV.set(a.x, a.y + 2, a.z), 4, 0.7, CYAN); sfx.gateOpen(); }
        if (open && playerUp && dist < 1.7 && Math.abs(tank.y - a.y) < 1.5) finishLevel();

      } else if (a.kind === "G") {
        stepSnatchScene(a, dt, dist);

      } else if (a.kind === "g") {
        a.guide.userData.halo.rotation.z += dt * 1.5;
        a.guide.position.y = 0.15 * Math.sin(a.t * 2);
      }
    }
  }

  // Story, no words: the Warden swoops down, seizes the Guide and carries it off north.
  function stepSnatchScene(a, dt, dist) {
    a.guide.userData.halo.rotation.z += dt * 1.5;
    a.clock += dt;
    if (a.phase === "wait") {
      a.guide.position.y = 0.15 * Math.sin(a.t * 2);
      if (dist < 13 && levelTime > 1.2) { a.phase = "swoop"; a.clock = 0; a.puppet.visible = true; sfx.snatch(); }
    } else if (a.phase === "swoop") {                       // drops in from high in the north
      const k = Math.min(1, a.clock / 1.0), e = k * k * (3 - 2 * k);
      a.puppet.position.set(0, 16 - 12.6 * e, -14 + 14 * e);
      a.puppet.userData.ring.rotation.z += dt * 6;
      if (k >= 1) { a.phase = "grab"; a.clock = 0; burst(tmpV.set(a.x, a.y + 2, a.z), UP, 24, 8, 1, 0.6, WHITE, RED); }
    } else if (a.phase === "grab") {
      a.guide.position.x = 0.12 * Math.sin(a.clock * 60);    // the Guide shudders
      if (a.clock > 0.35) { a.phase = "flee"; a.clock = 0; }
    } else if (a.phase === "flee") {                        // both rise and race away north
      const k = a.clock / 2.4, lift = 1.2 + k * 9, north = -k * k * 60;
      a.puppet.position.set(0, 3.4 + lift, north);
      a.guide.position.set(0, lift, north);
      a.puppet.userData.ring.rotation.z += dt * 6;
      if (k >= 1) { a.phase = "gone"; a.alive = false; a.group.visible = false; }
    }
  }

  function drawWardenPips(a) {
    if (a.pipsShown === a.hp) return;
    a.pipsShown = a.hp;
    while (a.pips.children.length) { const c = a.pips.children[0]; a.pips.remove(c); disposeTree(c); }
    for (let i = 0; i < a.hp; i++) {
      const pip = solid(new THREE.BoxGeometry(0.32, 0.32, 0.1), ORANGE);
      pip.position.x = (i - (a.hp - 1) / 2) * 0.45; a.pips.add(pip);
    }
  }

  function onWardenBeaten() {
    for (let i = 0; i < actors.length; i++) {
      const a = actors[i];
      if (a.alive && a.kind === "d") damageActor(a, 99);            // its drones fall with it
      if (a.kind === "g" && !a.freed) {                              // the Guide's cage breaks open
        a.freed = true; a.alive = false;
        a.group.remove(a.cage); a.group.remove(a.guide);
        a.guide.position.set(0, 0, 0);
        followers.unshift({ mesh: a.guide, x: a.x, y: a.y, z: a.z, t: 0, lift: 0, isGuide: true });
        levelGroup.add(a.guide);
        burst(tmpV.set(a.x, a.y + 1.7, a.z), UP, 60, 10, 1, 1.2, WHITE, GOLD);
        addGlow(tmpV, 5, 0.9, GOLD);
        sfx.rescue();
      }
    }
    for (let i = bolts.length - 1; i >= 0; i--) { levelGroup.remove(bolts[i].mesh); disposeTree(bolts[i].mesh); }
    bolts.length = 0;
  }

  // Rescued friends trail behind the tank in a line, hopping along.
  function stepFollowers(dt) {
    const last = trail[trail.length - 1];
    if (!player.dead && (!last || Math.hypot(tank.x - last.x, tank.z - last.z) > 0.25)) {
      trail.push({ x: tank.x, z: tank.z });
      if (trail.length > 400) trail.shift();
    }
    for (let i = 0; i < followers.length; i++) {
      const f = followers[i];
      f.t += dt;
      const spot = trail[trail.length - 1 - (i + 1) * 7] || trail[0];
      if (spot) { const k = Math.min(1, dt * 6); f.x += (spot.x - f.x) * k; f.z += (spot.z - f.z) * k; }
      const floor = Math.max(groundHeight(f.x, f.z), tank.y - 2);
      const hop = f.isGuide ? 0.15 * Math.sin(f.t * 2) : 0.25 * Math.abs(Math.sin(f.t * 5 + i));
      f.y += (floor + f.lift + hop - f.y) * Math.min(1, dt * 8);
      f.mesh.position.set(f.x, f.y, f.z);
      if (f.isGuide) f.mesh.userData.halo.rotation.z += dt * 1.5; else f.mesh.rotation.y += dt * 2;
    }
  }

  // ------------------------------------------------------------------
  // Levels: loading, finishing, the game's overall state
  // ------------------------------------------------------------------
  let state = "title";            // "title", "play", "between" (fading to the next level), "ending"
  let levelIndex = 0, levelTime = 0, betweenTimer = 0;
  let unlocked = 0;
  try { unlocked = Math.min(LEVELS.length - 1, Math.max(0, Number(localStorage.getItem("neonTreadsUnlocked")) || 0)); } catch (e) { unlocked = 0; }

  function exitIsOpen() { return bitsFreed >= bitsTotal && (!warden || !warden.alive); }

  function loadLevel(index) {
    if (levelGroup) { scene.remove(levelGroup); disposeTree(levelGroup); }
    if (sceneryGroup) { scene.remove(sceneryGroup); N.disposeScenery(sceneryGroup); }
    levelIndex = index; levelTime = 0;
    level = N.parseLevel(LEVELS[index]);
    sceneryGroup = N.buildLevelScenery(level); scene.add(sceneryGroup);
    levelGroup = new THREE.Group(); scene.add(levelGroup);
    actors = []; bolts = []; followers = []; trail = [];
    bitsTotal = 0; bitsFreed = 0; exitActor = null; warden = null; exitWasOpen = false;
    let start = null;
    for (let i = 0; i < level.spawns.length; i++) {
      const a = makeActor(level.spawns[i]);
      actors.push(a);
      if (a.kind === "S") start = a;
    }
    if (!start) throw new Error("Level '" + level.name + "' has no start (S)");
    player.checkpoint.x = start.x; player.checkpoint.z = start.z;
    player.health = SET.maxHealth; player.safe = 0; player.dead = false;
    cannon.reload = 0; beam.group.visible = false;
    placeTank(start.x, start.z, 0);
    tankModel.visible = true;
    updateView(0, true);
    drawHud();
  }
  function startLevel(index) {
    document.getElementById("flash").classList.remove("on");
    loadLevel(index);
    state = "play";
    showScreens();
  }
  function finishLevel() {
    if (state !== "play") return;
    state = "between"; betweenTimer = 1.1;
    sfx.levelDone();
    tmpV.set(tank.x, tank.y + 1, tank.z);
    burst(tmpV, UP, 70, 12, 1, 1.0, WHITE, CYAN);
    document.getElementById("flash").classList.add("on");
    if (levelIndex + 1 < LEVELS.length && levelIndex + 1 > unlocked) {
      unlocked = levelIndex + 1;
      try { localStorage.setItem("neonTreadsUnlocked", String(unlocked)); } catch (e) { /* progress just isn't kept */ }
    }
  }
  function afterBetween() {
    document.getElementById("flash").classList.remove("on");
    if (levelIndex + 1 < LEVELS.length) startLevel(levelIndex + 1);
    else { state = "ending"; showScreens(); }
  }

  // ------------------------------------------------------------------
  // HUD and screens (pictures only: no words tell the story)
  // ------------------------------------------------------------------
  const el = function (id) { return document.getElementById(id); };
  // Rebuilds the health and friends displays from the game's state.
  function drawHud() {
    let html = "";
    for (let i = 0; i < SET.maxHealth; i++) html += '<span class="pip health' + (i < player.health ? " on" : "") + '"></span>';
    el("health").innerHTML = html;
    html = "";
    for (let i = 0; i < bitsTotal; i++) html += '<span class="pip friend' + (i < bitsFreed ? " on" : "") + '"></span>';
    el("friends").innerHTML = html;
    html = "";
    for (let i = 0; i < LEVELS.length; i++) html += '<span class="dot' + (i === levelIndex ? " on" : "") + '"></span>';
    el("levelDots").innerHTML = html;
  }
  function showScreens() {
    el("title").hidden = state !== "title";
    el("ending").hidden = state !== "ending";
    el("hud").hidden = state === "title" || state === "ending";
    if (state === "title") {
      let html = "";
      for (let i = 0; i < LEVELS.length; i++) {
        html += '<button type="button" class="pick' + (i === titlePick ? " on" : "") + '" data-level="' + i + '"' + (i > unlocked ? " disabled" : "") +
                ' aria-label="Level ' + (i + 1) + '">' + (i + 1) + "</button>";
      }
      el("levelPick").innerHTML = html;
    }
  }
  let titlePick = unlocked;
  el("levelPick").addEventListener("click", function (e) {
    const b = e.target.closest("button");
    if (!b || b.disabled) return;
    titlePick = Number(b.dataset.level); showScreens();
  });
  el("play").addEventListener("click", function () {
    soundStart(); askShakePermission();
    startLevel(titlePick);
  });
  el("again").addEventListener("click", function () { state = "title"; titlePick = 0; showScreens(); });
  el("toCheckpoint").addEventListener("click", function () { if (state === "play" && !player.dead) killPlayer(); });
  el("debugToggle").addEventListener("click", function () { el("debugMenu").hidden = !el("debugMenu").hidden; });
  el("dbgRestart").addEventListener("click", function () { if (state === "play") startLevel(levelIndex); });
  el("dbgNext").addEventListener("click", function () { if (state === "play") startLevel((levelIndex + 1) % LEVELS.length); });
  el("dbgSound").addEventListener("click", function () { sound.on = !sound.on; el("dbgSound").textContent = "Sound: " + (sound.on ? "on" : "off"); });
  el("dbgShake").addEventListener("click", askShakePermission);

  // ------------------------------------------------------------------
  // Controls: two thumb levers, a fire button, shake to fire; keys for desktop
  // ------------------------------------------------------------------
  const keys = {};
  function makeLever(root) {
    const slot = root.querySelector(".slot"), grip = root.querySelector(".grip");
    const lever = { pointerId: null, value: 0 };
    function travel() { return slot.clientHeight / 2 - grip.offsetHeight / 2 - 4; }
    function show() { grip.style.transform = "translateY(" + (-lever.value * travel()) + "px)"; }
    function read(e) {
      const r = slot.getBoundingClientRect();
      let v = (r.top + r.height / 2 - e.clientY) / travel();
      v = Math.max(-1, Math.min(1, v));
      lever.value = Math.abs(v) < 0.08 ? 0 : v;
      show();
    }
    root.addEventListener("pointerdown", function (e) {
      if (lever.pointerId !== null) return;
      lever.pointerId = e.pointerId;
      try { root.setPointerCapture(e.pointerId); } catch (err) { /* fine without capture */ }
      read(e); e.preventDefault();
    });
    root.addEventListener("pointermove", function (e) { if (e.pointerId === lever.pointerId) read(e); });
    function release(e) { if (e.pointerId !== lever.pointerId) return; lever.pointerId = null; lever.value = 0; show(); }
    root.addEventListener("pointerup", release);
    root.addEventListener("pointercancel", release);
    lever.show = show;
    return lever;
  }
  const leverL = makeLever(el("leverL")), leverR = makeLever(el("leverR"));
  window.addEventListener("keydown", function (e) { keys[e.code] = true; if (e.code === "Space") { fireLaser(); e.preventDefault(); } });
  window.addEventListener("keyup", function (e) { keys[e.code] = false; });
  window.addEventListener("contextmenu", function (e) { e.preventDefault(); });
  el("fire").addEventListener("pointerdown", function (e) { fireLaser(); e.preventDefault(); });

  let scripted = null;            // tests can take over the levers
  function readLevers() {
    if (scripted) { levers.left = scripted.left; levers.right = scripted.right; return; }
    const kl = (keys.KeyW ? 1 : 0) - (keys.KeyS ? 1 : 0), kr = (keys.ArrowUp ? 1 : 0) - (keys.ArrowDown ? 1 : 0);
    levers.left = leverL.pointerId !== null ? leverL.value : kl;
    levers.right = leverR.pointerId !== null ? leverR.value : kr;
  }

  // Shake to fire. Needs the phone's motion sensor: the claude.ai link can't read it, and
  // iPhones only give it after a tap (the Play button asks).
  const shake = { status: "no motion data yet", gravity: null };
  function onMotion(e) {
    let a = e.acceleration, mag = 0;
    if (a && a.x !== null && a.x !== undefined) mag = Math.hypot(a.x, a.y, a.z);
    else {
      a = e.accelerationIncludingGravity;
      if (!a || a.x === null || a.x === undefined) return;
      if (!shake.gravity) shake.gravity = { x: a.x, y: a.y, z: a.z };
      const g = shake.gravity;
      g.x += (a.x - g.x) * 0.1; g.y += (a.y - g.y) * 0.1; g.z += (a.z - g.z) * 0.1;
      mag = Math.hypot(a.x - g.x, a.y - g.y, a.z - g.z);
    }
    shake.status = "on";
    if (mag > SET.shakeThreshold) fireLaser();
  }
  const hasMotion = typeof DeviceMotionEvent !== "undefined";
  if (hasMotion) window.addEventListener("devicemotion", onMotion); else shake.status = "this browser has no motion sensor";
  function askShakePermission() {
    if (!hasMotion || typeof DeviceMotionEvent.requestPermission !== "function") return;
    try {
      DeviceMotionEvent.requestPermission().then(function (answer) {
        if (answer !== "granted") shake.status = "blocked (not allowed)";
        else if (shake.status !== "on") shake.status = "allowed, no motion data yet";
      }).catch(function () { shake.status = "blocked by this page's host"; });
    } catch (e) { shake.status = "blocked by this page's host"; }
  }

  // ------------------------------------------------------------------
  // Camera: looks down from the south, north is up the screen. It never moves sideways: the
  // level's width fills the screen's width, and the camera follows the tank north.
  // ------------------------------------------------------------------
  const camTarget = new THREE.Vector3();
  const CAM_TILT = 62 * Math.PI / 180;
  let camDist = 100, viewSouth = 30, viewNorth = 40;
  function cameraZFor(tankZ) {
    const southLimit = -viewSouth, northLimit = Math.min(southLimit, -level.length + viewNorth);
    return Math.max(northLimit, Math.min(southLimit, tankZ));
  }
  // The slanted camera sees less width lower down the screen; 1 = the full level width.
  function visibleWidthFactor(z) {
    return Math.min(1, 1 - (z - cameraZFor(z)) * Math.cos(CAM_TILT) / camDist);
  }
  function resize() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(w, h, false);
    camera.aspect = w / h; camera.updateProjectionMatrix();
    const halfV = camera.fov * Math.PI / 360, tanV = Math.tan(halfV);
    camDist = SET.viewWidth / 2 / (tanV * Math.min(camera.aspect, 0.8));
    const camHeight = camDist * Math.sin(CAM_TILT), camBack = camDist * Math.cos(CAM_TILT);
    viewSouth = camBack - camHeight / Math.tan(CAM_TILT + halfV);
    viewNorth = camHeight / Math.tan(CAM_TILT - halfV) - camBack;
    leverL.show(); leverR.show();
  }
  window.addEventListener("resize", resize);
  function updateView(dt, snap) {
    const wantZ = cameraZFor(tank.z), wantY = Math.max(tank.y, 0);
    camTarget.x = 0;
    camTarget.z = snap ? wantZ : camTarget.z + (wantZ - camTarget.z) * (1 - Math.exp(-dt * 5));
    camTarget.y = snap ? wantY : camTarget.y + (wantY - camTarget.y) * (1 - Math.exp(-dt * 2.5));
    camera.position.set(0, camTarget.y + camDist * Math.sin(CAM_TILT), camTarget.z + camDist * Math.cos(CAM_TILT));
    camera.lookAt(camTarget);
    tankModel.position.set(tank.x + Math.sin(tank.yaw) * cannon.recoil, tank.y, tank.z + Math.cos(tank.yaw) * cannon.recoil);
    tankModel.rotation.set(tank.pitch, tank.yaw, tank.roll);
    if (!player.dead) tankModel.visible = player.safe <= 0 || Math.floor(player.safe * 12) % 2 === 0;   // blinks while safe
  }

  // ------------------------------------------------------------------
  // Main loop: fixed 60 steps a second so the game runs the same on every phone
  // ------------------------------------------------------------------
  function stepGame(dt) {
    stepEffects(dt);
    if (state === "between") { betweenTimer -= dt; if (betweenTimer <= 0) afterBetween(); return; }
    if (state !== "play") return;
    levelTime += dt;
    cannon.reload = Math.max(0, cannon.reload - dt);
    cannon.recoil *= Math.exp(-dt * 9);
    readLevers();
    if (player.dead) {
      player.respawnIn -= dt;
      if (player.respawnIn <= 0) respawnPlayer();
    } else {
      player.safe = Math.max(0, player.safe - dt);
      stepTank(dt);
      if (tank.y < -5) killPlayer();                       // fell into the void
    }
    stepActors(dt);
    stepBolts(dt);
    stepFollowers(dt);
  }

  const STEP = 1 / 60;
  let paused = false, last = 0, carry = 0, frames = 0, fpsTime = 0;
  function frame(now) {
    requestAnimationFrame(frame);
    const dt = Math.min(0.1, (now - last) / 1000 || 0); last = now;
    carry = paused ? 0 : carry + dt;
    while (carry >= STEP) { stepGame(STEP); carry -= STEP; }
    if (level) updateView(dt, false);
    renderer.render(scene, camera);
    el("fire").style.setProperty("--ready", String(1 - cannon.reload / SET.reloadSeconds));
    frames++; fpsTime += dt;
    if (fpsTime >= 0.5) {
      el("dbgInfo").textContent = Math.round(frames / fpsTime) + " fps\nshake: " + shake.status;
      frames = 0; fpsTime = 0;
    }
  }

  function boot() {
    loadLevel(titlePick);          // the level sits behind the title screen
    resize(); updateView(0, true);
    showScreens();
    requestAnimationFrame(frame);
  }

  // For automated tests: drive without touch and step time by hand.
  window.tankGame = {
    tank: tank, player: player, cannon: cannon, settings: SET, shake: shake, levels: LEVELS,
    startLevel: startLevel, fire: fireLaser,
    place: function (x, z, yaw) { placeTank(x, z, yaw || 0); trail.length = 0; },
    pause: function (on) { paused = on; },
    setLevers: function (l, r) { scripted = (l === null) ? null : { left: l, right: r }; },
    simulate: function (seconds) { for (let t = 0; t < seconds; t += STEP) stepGame(STEP); },
    level: function () {
      return { name: level.name, rows: level.rows, length: level.length,
        tiles: level.tiles.map(function (line) { return line.map(function (t) { return { isVoid: t.isVoid, tier: t.tier, ramp: t.ramp, block: !!(t.block && t.block.alive) }; }); }),
        spawns: level.spawns.map(function (s) { return { kind: s.kind, col: s.col, row: s.row, x: s.x, z: s.z }; }) };
    },
    actors: function () { return actors.map(function (a) { return { kind: a.kind, x: a.x, z: a.z, y: a.cy, alive: a.alive, hp: a.hp, hostile: a.hostile, phase: a.phase }; }); },
    status: function () {
      return { state: state, levelIndex: levelIndex, health: player.health, dead: player.dead, friends: bitsFreed, friendsTotal: bitsTotal,
               exitOpen: exitIsOpen(), followers: followers.length, bolts: bolts.length, unlocked: unlocked };
    }
  };

  boot();
})();
