# Phone Controller - Build Plan

Add a phone controller to the tank game: the player opens a web page on their phone and drives the tank with two on-screen tread levers. Do this **after** the milestones in `TANK_PLAN.md` are complete. Work on a branch `phone-controller`, commit after each milestone, and record decisions in `NOTES.md`.

## 1. How it works

- The Godot game hosts everything itself (no Node, Python or other server software):
  - a tiny **HTTP server** that serves one HTML page (default port 8080), and
  - a **WebSocket server** the page connects to (default port 8081).
- Phone and computer are on the same local network (laptop hotspot, phone hotspot or a private router; large public networks like eduroam usually block device-to-device traffic, so do not rely on them).
- The page sends left and right tread values; a new `PhoneDriverInput` writes them into the existing `DriverStation`. The tank code does not change.

## 2. Godot side

### 2.1 Servers

- `scripts/net/controller_server.gd` (autoload or node in the main scene):
  - HTTP: a `TCPServer` that answers `GET /` with the controller page (loaded from `res://web/controller.html`) and returns 404 for anything else. Keep it minimal; it only needs to serve one file. Make sure the HTML file is included in exports (add `web/*` to the export filter or embed the page as a string resource).
  - WebSocket: `TCPServer` + `WebSocketPeer.accept_stream()` for each connection. Poll every frame.
  - Ports configurable via exported variables or a small config resource.
- Find and display the computer's local IPv4 address(es) using `IP.get_local_addresses()`, filtering out loopback and IPv6. Show the URL (e.g. `http://192.168.x.x:8080`) on screen so the player can type it into the phone.
- Optional: show a QR code for the URL **only if** it can be done without adding addons or external libraries. Otherwise skip it and note in `NOTES.md`.

### 2.2 Message protocol

Keep it simple JSON text messages:

- Phone to game:
  - `{"t":"hello","role":"driver"}` on connect
  - `{"t":"in","l":0.53,"r":-1.0}` tread values in [-1, 1], sent ~30 times per second while touching and immediately on change, plus a heartbeat at least every 200 ms when idle
- Game to phone:
  - `{"t":"welcome","role":"driver"}` or `{"t":"welcome","role":"spectator"}`
  - optional `{"t":"buzz","ms":40}` for haptic feedback (e.g. on hitting something)

Validate and clamp all incoming values. Ignore malformed messages without crashing.

### 2.3 Station assignment

- The first phone to connect becomes the driver. Further phones receive `spectator` and their input is ignored. When the driver disconnects, the role frees up for the next phone.
- Structure this as a small `StationRegistry` that maps connections to stations, so later stations (gunner, engineer) can be assigned to other phones without rewriting it.

### 2.4 Input merging and safety

- `PhoneDriverInput` writes into `DriverStation` the same way keyboard and gamepad do.
- Merging rule: if a phone driver is connected and has sent input in the last 250 ms, phone input wins; otherwise keyboard/gamepad input is used. Document this in `NOTES.md`.
- **Watchdog:** if no message arrives from the driver phone for 250 ms, set both treads to 0. A dropped Wi-Fi connection must never leave the tank driving away.

### 2.5 HUD

Extend the debug HUD (F3) with: controller URL, number of connected phones, which phone is driver, time since last message, and the latest values received.

## 3. Phone page (`web/controller.html`)

One self-contained file: HTML, CSS and JavaScript inline, no external libraries, no internet needed.

- **Layout:** landscape. Two tall vertical lever tracks, left and right, each with a thumb handle. A clear centre line on each track (zero). Big touch targets: the levers should be easy to use without looking.
- **Multi-touch:** each lever tracks its own touch independently so both thumbs work at once. Use Pointer Events or Touch Events, and disable page scrolling, zooming, text selection and pull-to-refresh (`touch-action: none`, prevent default, `user-scalable=no`).
- **Spring return:** when a thumb lifts, that lever snaps back to 0. Add a toggle in a small settings menu to switch to "stay where left" mode, so both styles can be playtested.
- **Feedback:** a short vibration (`navigator.vibrate`) when a lever crosses zero and when a `buzz` message arrives. This works on Android; iPhone browsers do not support it, so fail silently.
- **Connection:** connect to `ws://<same host as the page>:8081`. Show a clear status (connecting, driver, spectator, disconnected). Auto-reconnect every second when disconnected, and send zero values first after reconnecting.
- **Screen sleep:** try the Screen Wake Lock API. It requires a secure (HTTPS) page, so on plain local HTTP it will usually be unavailable; in that case show a small tip to raise the phone's auto-lock time. Do not set up HTTPS.
- **Visuals:** plain and high-contrast. Placeholder style is fine; the developer will restyle it later.

## 4. Milestones

1. **Servers:** HTTP serves a test page; WebSocket accepts connections; URL shown on screen. Verify with a browser on the same machine (`http://localhost:8080`).
2. **Protocol + driver input:** `PhoneDriverInput`, station registry, merging and watchdog.
3. **Controller page:** levers, multi-touch, spring return toggle, status, reconnect, vibration.
4. **HUD + docs.**

## 5. Verification

The developer will test on a real phone. Before that, make the logic testable without one:

- A headless test that starts the servers, connects a `WebSocketPeer` client from Godot, sends `hello` and `in` messages, and asserts that `DriverStation` receives the values.
- Watchdog test: stop sending, assert treads return to 0 within ~300 ms.
- Second-client test: a second connection receives `spectator`, and its input is ignored.
- Malformed-message test: garbage input does not crash and does not move the tank.
- HTTP test: `GET /` returns the page with status 200.

Add these to the existing test runner so one command runs everything.

## 6. Notes for the developer (put in README)

- Phone and computer must be on the same network. eduroam and most public Wi-Fi block device-to-device connections; use the Windows Mobile Hotspot on the laptop, a phone hotspot, or a private router.
- Windows Firewall will ask whether to allow Godot on the network the first time; allow it on private networks. If the phone cannot load the page, the firewall is the first thing to check.
- The URL to open on the phone is shown on the game screen and in the F3 HUD.

## 7. Working rules

- No new dependencies, addons or downloads.
- Do not change the tank movement code; the phone is only another input source.
- Do not delete files you did not create; do not force-push.
