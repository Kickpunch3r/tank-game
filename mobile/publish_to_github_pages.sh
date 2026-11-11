#!/bin/bash
# Publishes the mobile game to the gh-pages branch, which GitHub Pages serves as a public web
# page (needed for shake-to-fire: the claude.ai link can't read the phone's motion sensor).
# Only the game page goes there, none of the rest of the repository.
#   Run from anywhere in the repo:  bash mobile/publish_to_github_pages.sh
#   Add --build-only <folder> to just build the page into a folder (for testing).
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root"

build() {   # $1 = folder to build into
  python3 - "$root/mobile/index.html" "$1/index.html" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
# index.html has no <html>/<head>/<body> (the claude.ai page adds its own); add them here.
head, body = src.split('<canvas id="view">', 1)
page = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n' + head +
        '</head>\n<body>\n<canvas id="view">' + body + '</body>\n</html>\n')
open(sys.argv[2], "w", encoding="utf-8").write(page)
PY
  touch "$1/.nojekyll"
}

if [ "${1:-}" = "--build-only" ]; then mkdir -p "$2"; build "$2"; echo "Built $2/index.html"; exit 0; fi

source_commit=$(git rev-parse --short HEAD)
work=$(mktemp -d)
if git fetch -q origin gh-pages:refs/remotes/origin/gh-pages 2>/dev/null; then
  git worktree add -q -B gh-pages "$work" origin/gh-pages
else
  git worktree add -q --detach "$work"
  (cd "$work" && git checkout -q --orphan gh-pages && git rm -rfq .)
fi
build "$work"
cd "$work"
git add -A
if git diff --cached --quiet; then
  echo "GitHub Pages copy is already up to date."
else
  git commit -q -m "Publish mobile game from $source_commit"
  git push -q origin gh-pages
  echo "Published to the gh-pages branch."
fi
cd "$root"
git worktree remove --force "$work"
