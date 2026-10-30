# Tank crew game (Godot 4.6)

A co-operative tank crew game for a large physical installation: several players run different
stations of one tank (driver, gunner, engineer) with big custom controllers and separate screens or
vision slits. The current build covers **driving only**. (The original plans were deleted on 2026-10-22; they are in git
history. NOTES.md records what was built and why.)
Developer background: art, storytelling, design, folk games, not programming. Learning GDScript.

## How to work with me
- **Discuss design before writing code.** Lay out options with trade-offs and a recommendation, then
  wait for me to confirm before implementing.
- Explain things plainly and concisely. Don't mix "how it works now" with "how it could work".
- Work in **small, iterative changes** that can be play-tested one at a time.
- Verify facts (Godot APIs) rather than guessing; say when something is unconfirmed.
- Name things clearly and distinctly (no near-identical file names).
- Prefer readable, robust code over clever code. Rebuild displays from state rather than patching them.
- Test headlessly before handing over, and say plainly what is untested.
- Finish with clear step-by-step instructions for anything I need to do in the editor.
- After moving files, check `preload("res://...")` paths in scripts and tests (Godot doesn't update them).

## Scene and resource files (.tscn / .tres)
In this project Claude **may create and edit** `.tscn` / `.tres` files as text (decided 2026-10-21,
to build faster), with these safeguards:
1. **Git checkpoint first:** commit before writing or changing a scene/resource, so any mistake is
   one command to undo.
2. **Godot fully closed** while Claude writes them (an open editor can overwrite them with its own
   copy). Claude says when to close and reopen.
3. **Keep scene files small:** a root node, a script, and only the child nodes that are worth
   seeing or tweaking in the editor. Generated content (e.g. the ramps) is built by scripts.
4. **No hand-written UIDs:** reference files by path and let Godot add UIDs itself.
5. **Check headlessly after every write:** import the project and load/run the scene with the
   console exe; fix any errors before handing over.
6. If I've edited a scene in the editor, my version wins: Claude re-reads it before touching it.

## Independent work mode: OFF
Change OFF to ON when leaving Claude to work alone. While **ON**:
- Make design decisions without asking; record each one, with the alternatives and why, in
  `docs/<topic>_design.md` so I can push back later.
- Commit whenever it makes sense (e.g. after each milestone). Push at the end.
- Can't play-test, so finish with a short hand-test checklist in the design doc.
While **OFF**: the "How to work with me" rules apply, and commits happen at the end of a session.

## Environment
- Godot 4.6.3: `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64.exe` (editor) and
  `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe` (headless checks and tests).
- Git: portable, not on PATH: `C:\Users\Laptop\Documents\PortableGit\cmd\git.exe`. Private repo, branch
  `main`. Remote: https://github.com/Kickpunch3r/tank-game.git
- Commit messages: write the message to a file with no BOM (`[System.IO.File]::WriteAllText` in
  PowerShell) and use `git commit -F file`.
- If a push asks for sign-in, run it in a Terminal panel tab (Claude's shell can't show the prompt).
- **Windows library laptop: no admin/install rights.** Godot runs without installing.
- No addons, no downloaded assets.

## Where things are
- `README.md`: how to run, controls, how to run tests. `NOTES.md`: architecture, decisions,
  test results, known issues, hand-check list. Keep both up to date when things change.
- `docs/tuning_settings.csv`: a spreadsheet explaining every tuning setting (what it does,
  raise/lower, default, where it's saved). **Keep it up to date** whenever a setting is added,
  moved between "Feel knob" and "Advanced", renamed or its saved default changes; the tests
  check it.
- Tests (run before handing over; all must pass):
  `C:\Users\Laptop\Documents\Godot_v4.6.3-stable_win64_console.exe --headless --fixed-fps 60 --path . res://tests/test_runner.tscn`
  - While working, run only the relevant suites (add `-- --only=push,phone`; names are listed
    at the top of `tests/test_runner.gd`). The full suite (~2.5 min) runs once before committing.
- Keep the routine cheap (agreed 2026-10-22): NOTES entries of a few lines (what, why, result;
  longer only for real design decisions); commit at the end of a session; short closing
  messages that don't repeat the docs.

## Project facts
- 3D, GDScript with static typing.
- The tank never reads `Input` directly: input sources write into a `DriverStation`, the tank reads
  only from that. Future stations and hardware plug in the same way.
- The game's tank is the **physics tank** (`RigidBody3D` on 8 spring probes, tuned as "Heavy" in
  `tuning/physics_tank_tuning.tres`), chosen 2026-10-30. The older kinematic `CharacterBody3D`
  tank (`TankTuning`) is kept as a debug option in the Tab panel, marked "(old)".
- Graphics: primitive meshes for now, always inside a separate `Visual` child node so art
  (low-poly models or Doom-style sprites) can be swapped without touching logic.
