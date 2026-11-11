#!/bin/bash
# Publishes Neon Treads to the gh-pages branch, in its own "neon" folder, so it is served at
# https://kickpunch3r.github.io/tank-game/neon/ (a public web address where shake-to-fire can
# work). Only the game's files go there, none of the rest of the repository.
#   Run from anywhere in the repo:  bash neon/publish_to_github_pages.sh
#   Add --build-only <folder> to just build the game into a folder (for testing).
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root"

build() {   # $1 = folder to build into
  mkdir -p "$1"
  cp "$root/neon/levels.js" "$root/neon/world.js" "$root/neon/game.js" "$1/"
  python3 - "$root/neon/index.html" "$1/index.html" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
# index.html has no <html>/<head>/<body> (the claude.ai page adds its own); add them here.
head, body = src.split('<canvas id="view">', 1)
page = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n' + head +
        '</head>\n<body>\n<canvas id="view">' + body + '</body>\n</html>\n')
open(sys.argv[2], "w", encoding="utf-8").write(page)
PY
}

if [ "${1:-}" = "--build-only" ]; then build "$2"; echo "Built $2/index.html"; exit 0; fi

source_commit=$(git rev-parse --short HEAD)
work=$(mktemp -d)
git fetch -q origin gh-pages:refs/remotes/origin/gh-pages
git worktree add -q -B gh-pages "$work" origin/gh-pages
build "$work/neon"
cd "$work"
git add -A
if git diff --cached --quiet; then
  echo "GitHub Pages copy of Neon Treads is already up to date."
else
  git commit -q -m "Publish Neon Treads from $source_commit"
  git push -q origin gh-pages
  echo "Published Neon Treads to the gh-pages branch (neon/ folder)."
fi
cd "$root"
git worktree remove --force "$work"
