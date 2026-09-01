#!/usr/bin/env bash
# Shows turbo skipping an untracked file when hashing a package, because
# another file in the same folder has a name ending in ".gitignore".
#
#   ./repro.sh              uses npx turbo@latest (reproduces the bug)
#   ./repro.sh /path/turbo  uses a given binary (a build of #13916 should pass)
set -u
cd "$(dirname "$0")"
TURBO=${1:-}
turbo() { if [ -n "$TURBO" ]; then "$TURBO" "$@"; else npx --yes turbo@latest "$@"; fi; }
inputs() { turbo run build --filter=pkg --dry=json 2>/dev/null \
  | python3 -c "import json,sys; print(sorted(json.load(sys.stdin)['tasks'][0].get('inputs',{}).keys()))"; }
cache() { turbo run build --filter=pkg 2>&1 | grep -oE "cache (miss|hit)[^,]*, [a-z ]*[0-9a-f]{16}"; }

rm -rf packages/pkg/dist .turbo packages/pkg/Node.gitignore
printf 'v1\n' > packages/pkg/config.log

echo "config.log is untracked and git does not ignore it:"
echo "  untracked: $(git ls-files --others --exclude-standard | tr '\n' ' ')"
git check-ignore -q packages/pkg/config.log && echo "  (ignored?!)" || echo "  check-ignore: not ignored"
echo
echo "hashed inputs without a stray gitignore:"
echo "  $(inputs)"

printf '*.log\n' > packages/pkg/Node.gitignore
echo
echo "now with an untracked packages/pkg/Node.gitignore containing '*.log'"
echo "  untracked: $(git ls-files --others --exclude-standard | tr '\n' ' ')"
echo "hashed inputs:"
echo "  $(inputs)"
echo "  ^ config.log should still be there. if it is missing, that is the bug."

echo
echo "cache behaviour:"
echo "  run 1:  $(cache)"
printf 'v2-CHANGED\n' > packages/pkg/config.log; sleep 1
echo "  edit packages/pkg/config.log"
echo "  run 2:  $(cache)"
echo "  source on disk:   $(cat packages/pkg/config.log)"
echo "  restored output:  $(cat packages/pkg/dist/out.txt)"
echo "  ^ run 2 should be a miss and the two lines should match."
