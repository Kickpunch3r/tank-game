// Headless tests for the mobile game. Run from this folder:
//   npm install      (once per session; fetches three.js for the test browser)
//   node run_tests.js            add --shots to also save screenshots into shots/
// Uses the Playwright and Chromium that are already installed in Claude's cloud sessions.
// The page normally loads three.js from a CDN; the cloud can't reach it, so the test
// hands the page the npm copy instead.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Set PAGE=/some/other/index.html to test a built copy (e.g. the GitHub Pages build).
const PAGE = process.env.PAGE ? path.resolve(process.env.PAGE) : path.resolve(__dirname, '..', 'index.html');
const THREE_JS = fs.readFileSync(path.join(__dirname, 'node_modules', 'three', 'build', 'three.min.js'), 'utf8');
const SHOTS = process.argv.includes('--shots');
let failed = 0;
function check(name, ok, detail) {
  if (!ok) failed++;
  console.log((ok ? 'PASS  ' : 'FAIL  ') + name + (detail ? '   ' + detail : ''));
}

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(e.message));
  await page.route('**/three.min.js', r => r.fulfill({ body: THREE_JS, contentType: 'application/javascript' }));
  await page.goto('file://' + PAGE);
  await page.waitForTimeout(1500);
  if (SHOTS) fs.mkdirSync(path.join(__dirname, 'shots'), { recursive: true });
  async function shot(name) {
    if (!SHOTS) return;
    await page.evaluate(() => tankGame.setLevers(0, 0));   // the page keeps running while we wait: stop the tank
    await page.waitForTimeout(1500);      // let the camera catch up
    await page.screenshot({ path: path.join(__dirname, 'shots', name + '.png') });
  }
  await shot('start');

  // --- Turning: left tread only turns the tank right (yaw goes down) ---
  const turn = await page.evaluate(() => { const g = tankGame; g.restart(); g.setLevers(1, 0); g.simulate(1); return g.tank.yaw; });
  check('left lever alone turns right', turn < -0.3, 'yaw ' + turn.toFixed(2));

  // --- Autopilot: the level can be driven from start to flag ---
  await page.evaluate(() => {
    const g = tankGame, L = g.level;
    const wp = [[0, 12], [1, 30], [-11.5, 50], [-11.5, 63]];        // [x, distance north]
    for (let k = 0; k < L.legs; k++) {
      const side = k % 2 === 0 ? 11.5 : -11.5, mid = L.mountainStart + 5 + L.legDepth * k;
      wp.push([side, mid]); wp.push([side, mid + L.legDepth]);
    }
    wp.push([0, L.pathStart - 4]);
    for (let n = L.pathStart + 1; n <= L.pathEnd + 1; n += 3) wp.push([g.pathCentre(n), n]);
    wp.push([0, L.flagN]);
    let i = 0;
    g.restart();
    window.autoDrive = function (seconds) {
      const t = g.tank;
      for (let s = 0; s < seconds * 60; s++) {
        if (i >= wp.length) { g.setLevers(0, 0); g.simulate(1 / 60); continue; }
        const dx = wp[i][0] - t.x, dz = -wp[i][1] - t.z;
        if (Math.hypot(dx, dz) < 1.2) { i++; continue; }
        let err = Math.atan2(-dx, -dz) - t.yaw;
        while (err > Math.PI) err -= 2 * Math.PI;
        while (err < -Math.PI) err += 2 * Math.PI;
        const forward = Math.max(0, 1 - Math.abs(err) * 1.5), steer = Math.max(-1, Math.min(1, err * 2));
        g.setLevers(Math.max(-1, Math.min(1, forward - steer)), Math.max(-1, Math.min(1, forward + steer)));
        g.simulate(1 / 60);
      }
      return Object.assign({ n: -t.z, y: t.y }, g.progress());
    };
  });
  const shotsAt = { 20: 'plain', 45: 'mountain_road', 80: 'mountain_top', 95: 'cliff_path' };
  let state = null, seconds = 0;
  while (seconds < 240) {
    state = await page.evaluate(() => autoDrive(5)); seconds += 5;
    if (shotsAt[seconds]) await shot(shotsAt[seconds]);
    if (state.won) break;
  }
  check('autopilot reaches the flag', state.won, 'after ' + seconds + ' s, at ' + state.n.toFixed(0) + ' north, height ' + state.y.toFixed(1));
  check('all checkpoints were passed', state.checkpoint === 3, 'checkpoint ' + state.checkpoint);
  await shot('flag');

  // --- Chasm: driving off the ridge falls, then returns to the last checkpoint ---
  const chasm = await page.evaluate(() => {
    const g = tankGame, L = g.level;
    g.reset({ x: g.pathCentre(180), z: -180, yaw: -Math.PI / 2 }); g.setLevers(1, 1); g.simulate(1.2);
    const fallingY = g.tank.y;
    g.setLevers(0, 0); g.simulate(3);
    return { fallingY, top: L.top, n: -g.tank.z, y: g.tank.y, cpN: g.checkpoints[3].n };
  });
  check('tank falls off the ridge', chasm.fallingY < chasm.top - 1, 'height ' + chasm.fallingY.toFixed(1));
  check('falling into the chasm returns to the checkpoint', Math.abs(chasm.n - chasm.cpN) < 0.5 && chasm.y > chasm.top - 1, 'at ' + chasm.n.toFixed(1) + ' north');

  // --- Mountain road: can fall off a shelf, can't climb the bank between shelves ---
  const shelf = await page.evaluate(() => { const g = tankGame; g.reset({ x: 6, z: -83, yaw: Math.PI }); g.setLevers(1, 1); const y0 = g.tank.y; g.simulate(3); return { y0, y1: g.tank.y }; });
  check('tank falls off a road shelf to the one below', shelf.y1 < shelf.y0 - 2, shelf.y0.toFixed(1) + ' -> ' + shelf.y1.toFixed(1));
  const bank = await page.evaluate(() => { const g = tankGame; g.reset({ x: 6, z: -73, yaw: 0 }); g.setLevers(1, 1); const y0 = g.tank.y; g.simulate(4); return { y0, y1: g.tank.y }; });
  check('bank between shelves blocks the tank', Math.abs(bank.y1 - bank.y0) < 0.5, bank.y0.toFixed(1) + ' -> ' + bank.y1.toFixed(1));

  // --- Invisible side wall: the tank can't leave the screen sideways ---
  const side = await page.evaluate(() => { const g = tankGame; g.reset({ x: -8, z: -12, yaw: Math.PI / 2 }); g.setLevers(1, 1); g.simulate(4); return { x: g.tank.x, half: g.level.halfWidth }; });
  check('invisible wall keeps the tank on screen', side.x > -side.half && side.x < -side.half + 3.5, 'stopped at x ' + side.x.toFixed(1));
  await shot('side_wall');

  // --- Laser: an instant straight beam with sparks; reloading blocks a second shot ---
  const shot1 = await page.evaluate(() => {
    const g = tankGame; g.restart(); g.setLevers(0, 0); g.simulate(0.5);
    const first = g.fire(), second = g.fire(), beamOn = g.beamVisible(), sparks = g.liveSparks();
    const impact = Object.assign({}, g.cannon.lastImpact), tankX = g.tank.x, tankZ = g.tank.z;
    g.simulate(1.4);
    const beamGone = !g.beamVisible(), stillReloading = g.fire();
    g.simulate(0.3);
    const afterReload = g.fire();
    return { first, second, beamOn, sparks, impact, tankX, tankZ, beamGone, stillReloading, afterReload };
  });
  const ahead = shot1.tankZ - shot1.impact.z;
  check('laser fires: beam and muzzle sparks appear', shot1.first && shot1.beamOn && shot1.sparks >= 30, shot1.sparks + ' sparks');
  check('beam goes straight ahead of the tank', ahead > 3 && ahead <= 47 && Math.abs(shot1.impact.x - shot1.tankX) < 0.5, 'reached ' + ahead.toFixed(1) + ' units ahead');
  check('beam fades away', shot1.beamGone);
  check('reload blocks firing for 1.5 s', !shot1.second && !shot1.stillReloading && shot1.afterReload);
  const wallShot = await page.evaluate(() => {
    const g = tankGame; g.reset({ x: 6, z: -73, yaw: 0 }); g.simulate(2); g.fire();
    return g.cannon.lastImpact;
  });
  check('beam stops at a rock bank', wallShot.hit && wallShot.reach < 8, 'stopped after ' + wallShot.reach.toFixed(1) + ' units');
  if (SHOTS) {
    await page.evaluate(() => { tankGame.restart(); tankGame.simulate(2); });
    await page.waitForTimeout(1500);
    await page.evaluate(() => { tankGame.pause(true); tankGame.fire(); tankGame.simulate(0.08); });
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(__dirname, 'shots', 'laser.png') });
    await page.evaluate(() => { tankGame.reset({ x: 6, z: -73, yaw: 0.5 }); tankGame.simulate(2.5); });
    await page.evaluate(() => tankGame.pause(false)); await page.waitForTimeout(1500);
    await page.evaluate(() => { tankGame.pause(true); tankGame.fire(); tankGame.simulate(0.12); });
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(__dirname, 'shots', 'laser_hit.png') });
    await page.evaluate(() => tankGame.pause(false));
  }
  await page.evaluate(() => { tankGame.setLevers(null); tankGame.simulate(2); });
  await page.click('#debugToggle');
  const firedBefore = await page.evaluate(() => tankGame.cannon.shotsFired);
  await page.click('#fire');
  check('Fire button in the debug menu fires', await page.evaluate(n => tankGame.cannon.shotsFired === n + 1, firedBefore));

  // --- Shake: a hard jolt from the motion sensor fires; a gentle one doesn't ---
  const shaken = await page.evaluate(() => {
    const g = tankGame; g.simulate(3);
    const before = g.cannon.shotsFired;
    window.dispatchEvent(new DeviceMotionEvent('devicemotion', { acceleration: { x: 3, y: 2, z: 1 } }));
    const afterGentle = g.cannon.shotsFired;
    window.dispatchEvent(new DeviceMotionEvent('devicemotion', { acceleration: { x: 18, y: 6, z: 2 } }));
    return { gentle: afterGentle - before, hard: g.cannon.shotsFired - afterGentle, status: g.shake.status };
  });
  check('a hard shake fires, a gentle one does not', shaken.gentle === 0 && shaken.hard === 1, 'status: ' + shaken.status);
  await page.click('#debugToggle');

  // --- Touch: two fingers on the two levers (left forward, right back) spins the tank ---
  await page.evaluate(() => { tankGame.restart(); tankGame.setLevers(null); });
  const L = await page.locator('#leverL .slot').boundingBox(), R = await page.locator('#leverR .slot').boundingBox();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [
    { x: L.x + 30, y: L.y + 20, id: 1 }, { x: R.x + 30, y: R.y + R.height - 20, id: 2 }] });
  await page.waitForTimeout(1500);
  const held = await page.evaluate(() => ({ l: tankGame.tank.treadL, r: tankGame.tank.treadR }));
  await shot('levers_held');
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(1000);
  const released = await page.evaluate(() => ({ l: tankGame.tank.treadL, r: tankGame.tank.treadR }));
  check('touch levers drive the treads', held.l > 1 && held.r < -1, 'left ' + held.l.toFixed(1) + ', right ' + held.r.toFixed(1));
  check('letting go stops the treads', released.l === 0 && released.r === 0);

  check('no errors in the browser console', errors.length === 0, errors.join(' | '));
  await browser.close();
  console.log(failed === 0 ? '\nAll checks passed.' : '\n' + failed + ' check(s) FAILED.');
  process.exit(failed === 0 ? 0 : 1);
})();
