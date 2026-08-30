#!/usr/bin/env bash
# Link selfhost assets into Nuxt public/ for local `pnpm run dev` and generate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLIC="$ROOT/apps/nuxt/public"
mkdir -p "$ROOT/selfhost/files" "$ROOT/selfhost/libs"
ln -sfn ../../../selfhost/files "$PUBLIC/files"
ln -sfn ../../../selfhost/libs "$PUBLIC/libs"
chmod -R a+rX "$ROOT/selfhost/files" "$ROOT/selfhost/libs" 2>/dev/null || true
echo "Linked:"
ls -la "$PUBLIC/files" "$PUBLIC/libs"
if [[ -f "$PUBLIC/files/list/word.json" ]]; then
  echo "OK files/list/word.json"
else
  echo "WARN: missing files — run ./scripts/sync-selfhost-assets.sh first"
fi
if [[ -f "$PUBLIC/libs/Shepherd.14.5.1.mjs.js" ]]; then
  echo "OK libs/Shepherd.14.5.1.mjs.js"
else
  echo "WARN: missing libs — run ./scripts/sync-selfhost-assets.sh first"
fi
