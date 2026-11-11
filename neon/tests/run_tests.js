// Headless tests for Neon Treads. Run from this folder:
//   npm install      (once per session; fetches three.js for the test browser)
//   node run_tests.js            add --shots to also save screenshots into shots/
// Set PAGE=/some/other/index.html to test a built copy (e.g. the GitHub Pages build).
// Uses the Playwright and Chromium already installed in Claude's cloud sessions. The cloud
// can't reach the CDN the page loads three.js from, so the test hands it the npm copy.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const PAGE = process.env.PAGE ? path.resolve(process.env.PAGE) : path.resolve(__dirname, '..', 'index.html');
const THREE_JS = fs.readFileSync(path.join(__dirname, 'node_modules', 'three', 'build', 'three.min.js'), 'utf8');
const SHOTS = process.argv.includes('--shots');
let failed = 0;
function check(name, ok, detail) {
  if (!ok) failed++;
  console.log((ok ? 'PASS  ' : 'FAIL  ') + name + (detail ? '   ' + detail : ''));
}

// Runs inside the page: route-finding over the level's cells, and an autopilot.
function installHelpers() {
  const g = tankGame, OPP = { n: 's', s: 'n', e: 'w', w: 'e' };
  const STEPS = [['n', 0, 1], ['s', 0, -1], ['e', 1, 0], ['w', -1, 0]];
  function leaveHeight(t, dir) { return t.tier + (t.ramp === dir ? 1 : 0); }                 // height when driving out of a cell
  function enterHeight(t, side) { return t.tier + (t.ramp ? (t.ramp === OPP[side] ? 0 : 1) : 0); }   // height needed to drive in through `side`
  // Cells reachable from (col,row), with the cell each was reached from. Drops are one-way.
  window.explore = function (lv, col, row) {
    const key = (c, r) => c + ',' + r, from = {}; from[key(col, row)] = null;
    const queue = [[col, row]];
    while (queue.length) {
      const [c, r] = queue.shift(), a = lv.tiles[r][c];
      for (const [dir, dc, dr] of STEPS) {
        const nc = c + dc, nr = r + dr;
        if (nc < 0 || nc >= 7 || nr < 0 || nr >= lv.rows || key(nc, nr) in from) continue;
        const b = lv.tiles[nr][nc];
        if (b.isVoid || leaveHeight(a, dir) < enterHeight(b, OPP[dir])) continue;
        from[key(nc, nr)] = [c, r]; queue.push([nc, nr]);
      }
    }
    return from;
  };
  window.pathTo = function (from, col, row) {
    if (!((col + ',' + row) in from)) return null;
    const cells = []; let at = [col, row];
    while (at) { cells.unshift(at); at = from[at[0] + ',' + at[1]]; }
    return cells;
  };
  // Every friend and the exit must be reachable from the start and from every checkpoint.
  window.levelProblems = function () {
    const lv = g.level(), problems = [];
    const goals = lv.spawns.filter(s => s.kind === 'f' || s.kind === 'E');
    if (!goals.some(s => s.kind === 'E')) problems.push('no exit');
    for (const s of lv.spawns.filter(s => s.kind === 'S' || s.kind === 'C')) {
      const from = explore(lv, s.col, s.row);
      for (const goal of goals) if (!((goal.col + ',' + goal.row) in from)) problems.push(goal.kind + ' at ' + goal.col + ',' + goal.row + ' unreachable from ' + s.kind + ' at ' + s.col + ',' + s.row);
    }
    return problems;
  };
  // Plans a drive: nearest friend first, then the exit. Returns [x, z] points (cell centres).
  window.planRoute = function () {
    const lv = g.level(), start = lv.spawns.find(s => s.kind === 'S');
    const friends = lv.spawns.filter(s => s.kind === 'f'), exit = lv.spawns.find(s => s.kind === 'E');
    let at = [start.col, start.row]; const points = [];
    const go = (goal) => {
      const cells = pathTo(explore(lv, at[0], at[1]), goal.col, goal.row);
      if (!cells) throw new Error('no route to ' + goal.kind + ' at ' + goal.col + ',' + goal.row);
      cells.slice(1).forEach(c => points.push([-14 + (c[0] + 0.5) * 4, -(c[1] + 0.5) * 4]));
      at = [goal.col, goal.row];
    };
    while (friends.length) {
      const from = explore(lv, at[0], at[1]);
      friends.sort((a, b) => (pathTo(from, a.col, a.row) || { length: 1e9 }).length - (pathTo(from, b.col, b.row) || { length: 1e9 }).length);
      go(friends.shift());
    }
    go(exit);
    window.route = { points, i: 0 };
    return points.length;
  };
  // Drives the planned route for `seconds`, firing whenever the laser is ready.
  window.autoDrive = function (seconds) {
    const t = g.tank, levelAtStart = g.status().levelIndex;
    for (let s = 0; s < seconds * 60; s++) {
      const st = g.status();
      if (st.state !== 'play' || st.levelIndex !== levelAtStart) return { done: true };
      let tx, tz;
      if (route.i < route.points.length) {
        [tx, tz] = route.points[route.i];
        if (Math.hypot(tx - t.x, tz - t.z) < 1.0) { route.i++; continue; }
      } else {                                              // at the exit but it's shut: fight what's left
        const foe = g.actors().filter(a => a.alive && a.hostile).sort((a, b) => Math.hypot(a.x - t.x, a.z - t.z) - Math.hypot(b.x - t.x, b.z - t.z))[0];
        if (!foe) { g.setLevers(0, 0); g.simulate(1 / 60); continue; }
        tx = foe.x; tz = foe.z;
      }
      let err = Math.atan2(-(tx - t.x), -(tz - t.z)) - t.yaw;
      while (err > Math.PI) err -= 2 * Math.PI;
      while (err < -Math.PI) err += 2 * Math.PI;
      const waiting = route.i >= route.points.length;
      const forward = waiting ? 0 : Math.max(0, 1 - Math.abs(err) * 1.5), steer = Math.max(-1, Math.min(1, err * 2));
      g.setLevers(Math.max(-1, Math.min(1, forward - steer)), Math.max(-1, Math.min(1, forward + steer)));
      g.fire();
      g.simulate(1 / 60);
    }
    return Object.assign({ done: false, waypoint: route.i, of: route.points.length, x: +t.x.toFixed(1), z: +t.z.toFixed(1), y: +t.y.toFixed(1) }, g.status());
  };
}

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  const errors = [];
  page.on('console', m => { if (m.type() === 'error' && !/fonts\.googleapis|ERR_|Failed to load resource/.test(m.text())) errors.push(m.text()); });
  page.on('pageerror', e => errors.push(e.message));
  await page.route('**/three.min.js', r => r.fulfill({ body: THREE_JS, contentType: 'application/javascript' }));
  await page.route('**/fonts.googleapis.com/**', r => r.abort());
  await page.goto('file://' + PAGE);
  await page.waitForTimeout(1500);
  if (SHOTS) fs.mkdirSync(path.join(__dirname, 'shots'), { recursive: true });
  async function shot(name) {
    if (!SHOTS) return;
    await page.waitForTimeout(1300);      // let the camera catch up (the game itself is paused)
    await page.screenshot({ path: path.join(__dirname, 'shots', name + '.png') });
  }
  const loaded = await page.evaluate(() => typeof tankGame !== 'undefined');
  check('game loads', loaded, errors.join(' | '));
  if (!loaded) { await browser.close(); process.exit(1); }
  await page.evaluate(installHelpers);

  // --- Title screen: Play starts level 1 ---
  await shot('title');
  await page.click('#play');
  const started = await page.evaluate(() => tankGame.status());
  check('Play starts the first level', started.state === 'play' && started.levelIndex === 0 && started.health === 4);
  await page.evaluate(() => tankGame.pause(true));          // from here the test steps time by hand

  // --- Every level: sound layout, and an autopilot can finish it ---
  const levelCount = await page.evaluate(() => tankGame.levels.length);
  for (let i = 0; i < levelCount; i++) {
    const info = await page.evaluate((i) => {
      tankGame.startLevel(i); tankGame.player.god = true;
      const lv = tankGame.level();
      return { name: lv.name, problems: levelProblems(), friends: lv.spawns.filter(s => s.kind === 'f').length, points: planRoute() };
    }, i);
    check('level ' + (i + 1) + ' (' + info.name + '): friends and exit reachable from start and every checkpoint', info.problems.length === 0, info.problems.join('; '));
    await shot('level' + (i + 1) + '_start');
    let st = null, seconds = 0;
    while (seconds < 400) {
      st = await page.evaluate(() => autoDrive(10)); seconds += 10;
      if (st.done) break;
      if (SHOTS && seconds % 40 === 0) await shot('level' + (i + 1) + '_' + seconds + 's');
    }
    check('level ' + (i + 1) + ': autopilot rescues ' + info.friends + ' friends and reaches the exit', st.done, st.done ? 'in about ' + seconds + ' s' : JSON.stringify(st));
  }
  const afterAll = await page.evaluate(() => { tankGame.simulate(2); return tankGame.status(); });
  check('finishing the last level shows the ending', afterAll.state === 'ending', 'state ' + afterAll.state);
  check('progress unlocked every level', afterAll.unlocked === levelCount - 1);
  await page.waitForTimeout(1200);
  if (SHOTS) await page.screenshot({ path: path.join(__dirname, 'shots', 'ending.png') });

  // --- Story: the Warden snatches the Guide near the start of level 1 ---
  const snatch = await page.evaluate(() => {
    const g = tankGame; g.startLevel(0); g.setLevers(0, 0);
    const before = g.actors().find(a => a.kind === 'G').phase;
    g.simulate(2); const during = g.actors().find(a => a.kind === 'G').phase;
    g.simulate(4); const after = g.actors().find(a => a.kind === 'G');
    return { before, during, afterAlive: after.alive };
  });
  check('story: the Guide is snatched and carried off', snatch.before === 'wait' && snatch.during !== 'wait' && !snatch.afterAlive, JSON.stringify(snatch));

  // --- Combat: a turret hurts the tank; the laser (with aim help) destroys the turret ---
  const combat = await page.evaluate(() => {
    const g = tankGame; g.startLevel(0); g.player.god = false; g.setLevers(0, 0);
    const turret = g.level().spawns.find(s => s.kind === 't');
    g.place(turret.x - 8, turret.z + 4, 0);                 // on the low floor, in range, not facing it
    g.simulate(7);
    const healthAfter = g.status().health;
    g.player.god = true;
    g.place(turret.x - 9, turret.z, -Math.PI / 2 + 0.15);   // facing east, a little off target
    g.fire(); const first = Object.assign({}, g.cannon.lastHit); g.simulate(1); g.fire();
    const dead = !g.actors().find(a => a.kind === 't' && Math.abs(a.x - turret.x) < 0.1 && Math.abs(a.z - turret.z) < 0.1).alive;
    return { healthAfter, first, dead };
  });
  check('a turret\'s shots hurt the tank', combat.healthAfter < 4, 'shield ' + combat.healthAfter + ' of 4');
  check('laser bends onto a turret on higher ground and destroys it in 2 hits', combat.first.aimed && combat.first.what === 't' && combat.dead, JSON.stringify(combat.first));

  // --- Losing all shield, and falling into the void, both return the tank to the checkpoint ---
  const death = await page.evaluate(() => {
    const g = tankGame; g.startLevel(1); g.player.god = false; g.setLevers(0, 0);
    const start = g.level().spawns.find(s => s.kind === 'S');
    g.place(-12, -14, 0);                                    // over the void beside the first bridge
    g.simulate(0.4); const fell = g.status().dead;
    g.simulate(2); const st = g.status();
    return { fell, back: Math.hypot(g.tank.x - start.x, g.tank.z - start.z) < 0.5, health: st.health, dead: st.dead };
  });
  check('falling into the void destroys the tank', death.fell);
  check('the tank returns at the checkpoint with full shield', death.back && !death.dead && death.health === 4);

  // --- Rescue: touching a cage frees the friend, who then follows; the exit needs them all ---
  const rescue = await page.evaluate(() => {
    const g = tankGame; g.startLevel(0); g.player.god = true; g.setLevers(0, 0);
    const friends = g.level().spawns.filter(s => s.kind === 'f');
    const openBefore = g.status().exitOpen;
    g.place(friends[0].x, friends[0].z, 0); g.simulate(0.2);
    const one = g.status();
    friends.slice(1).forEach(f => { g.place(f.x, f.z, 0); g.simulate(0.2); });
    return { openBefore, afterOne: one.friends, followers: one.followers, openAfterOne: one.exitOpen, openAfterAll: g.status().exitOpen };
  });
  check('rescued friends follow the tank', rescue.afterOne === 1 && rescue.followers === 1);
  check('the exit opens only when every friend is free', !rescue.openBefore && !rescue.openAfterOne && rescue.openAfterAll);

  // --- Controls: levers by touch, the fire button, shake ---
  await page.evaluate(() => { tankGame.startLevel(0); tankGame.player.god = true; tankGame.setLevers(null); tankGame.pause(false); });
  const L = await page.locator('#leverL .slot').boundingBox(), R = await page.locator('#leverR .slot').boundingBox();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [
    { x: L.x + 30, y: L.y + 20, id: 1 }, { x: R.x + 30, y: R.y + R.height - 20, id: 2 }] });
  await page.waitForTimeout(1500);
  const held = await page.evaluate(() => ({ l: tankGame.tank.treadL, r: tankGame.tank.treadR }));
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(1000);
  const released = await page.evaluate(() => ({ l: tankGame.tank.treadL, r: tankGame.tank.treadR }));
  check('touch levers drive the treads', held.l > 1 && held.r < -1, 'left ' + held.l.toFixed(1) + ', right ' + held.r.toFixed(1));
  check('letting go stops the treads', released.l === 0 && released.r === 0);
  const firedBefore = await page.evaluate(() => { tankGame.simulate(1); return tankGame.cannon.shotsFired; });
  await page.click('#fire');
  check('the fire button fires the laser', await page.evaluate(n => tankGame.cannon.shotsFired === n + 1, firedBefore));
  const shaken = await page.evaluate(() => {
    const g = tankGame; g.simulate(2);
    const before = g.cannon.shotsFired;
    window.dispatchEvent(new DeviceMotionEvent('devicemotion', { acceleration: { x: 3, y: 2, z: 1 } }));
    const afterGentle = g.cannon.shotsFired;
    window.dispatchEvent(new DeviceMotionEvent('devicemotion', { acceleration: { x: 18, y: 6, z: 2 } }));
    return { gentle: afterGentle - before, hard: g.cannon.shotsFired - afterGentle };
  });
  check('a hard shake fires, a gentle one does not', shaken.gentle === 0 && shaken.hard === 1);

  check('no errors in the browser console', errors.length === 0, errors.join(' | '));
  await browser.close();
  console.log(failed === 0 ? '\nAll checks passed.' : '\n' + failed + ' check(s) FAILED.');
  process.exit(failed === 0 ? 0 : 1);
})();
