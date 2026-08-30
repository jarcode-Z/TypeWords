#!/usr/bin/env bash
# Sync official CDN assets into selfhost/ for independent deploy.
# Run on a machine with good network (not the small ECS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILES_DIR="$ROOT/selfhost/files"
LIBS_DIR="$ROOT/selfhost/libs"
FILES_BASE="${FILES_BASE:-https://files.typewords.cc}"
LIBS_BASE="${LIBS_BASE:-https://libs.typewords.cc}"
FULL="${FULL:-0}"

mkdir -p "$FILES_DIR" "$LIBS_DIR"

download() {
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"
  if [[ -f "$out" && "${FORCE:-0}" != "1" ]]; then
    echo "skip  $out"
    return 0
  fi
  echo "get   $url"
  curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"
}

echo "==> libs ($LIBS_BASE)"
download "$LIBS_BASE/jszip.min.js" "$LIBS_DIR/jszip.min.js"
download "$LIBS_BASE/xlsx.full.min.js" "$LIBS_DIR/xlsx.full.min.js"
download "$LIBS_BASE/Shepherd.14.5.1.mjs.js" "$LIBS_DIR/Shepherd.14.5.1.mjs.js"
download "$LIBS_BASE/snapdom.min.js" "$LIBS_DIR/snapdom.min.js"

echo "==> list ($FILES_BASE)"
for f in word.json recommend_word.json article.json recommend_article.json; do
  download "$FILES_BASE/list/$f" "$FILES_DIR/list/$f"
done

echo "==> sound (keyboard / effects)"
# Common paths used by packages/core/src/hooks/sound.ts
SOUND_PATHS=(
  sound/beep.wav
  sound/correct.wav
  sound/key-sounds/机械键盘.mp3
  sound/key-sounds/机械键盘1.mp3
  sound/key-sounds/机械键盘2.mp3
  sound/key-sounds/老式机械键盘.mp3
  sound/key-sounds/笔记本键盘.mp3
  sound/key-sounds/jixie/机械0.mp3
  sound/key-sounds/jixie/机械1.mp3
  sound/key-sounds/jixie/机械2.mp3
  sound/key-sounds/jixie/机械3.mp3
)
for p in "${SOUND_PATHS[@]}"; do
  download "$FILES_BASE/$p" "$FILES_DIR/$p" || echo "warn  missing $p (optional)"
done

echo "==> dicts (from list JSON urls)"
# Extract relative dict paths from list JSON (best-effort).
python3 - "$FILES_DIR" "$FILES_BASE" <<'PY' || true
import json, os, sys
files_dir = sys.argv[1]
seen = set()
for name in ("word.json", "recommend_word.json", "article.json", "recommend_article.json"):
    path = os.path.join(files_dir, "list", name)
    if not os.path.isfile(path):
        continue
    try:
        data = json.load(open(path, encoding="utf-8"))
    except Exception as e:
        print("warn parse", name, e)
        continue
    items = data if isinstance(data, list) else data.get("list") or data.get("data") or []
    if isinstance(data, dict) and not items:
        for v in data.values():
            if isinstance(v, list):
                items = v
                break
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict):
            continue
        url = item.get("url") or item.get("path") or ""
        lang = item.get("language") or item.get("lang") or "en"
        kind = item.get("type") or ("article" if "article" in name else "word")
        if kind not in ("word", "article"):
            kind = "article" if "article" in name else "word"
        if not url:
            continue
        # Official layout: dicts/{language}/{word|article}/{url}
        rel = f"dicts/{lang}/{kind}/{url}".replace("//", "/")
        seen.add(rel)
out = os.path.join(files_dir, ".dict-paths.txt")
open(out, "w", encoding="utf-8").write("\n".join(sorted(seen)) + ("\n" if seen else ""))
print(f"dict paths: {len(seen)} -> {out}")
PY

DICT_LIST_FILE="$FILES_DIR/.dict-paths.txt"
if [[ -f "$DICT_LIST_FILE" ]]; then
  while IFS= read -r rel || [[ -n "$rel" ]]; do
    [[ -z "$rel" ]] && continue
    download "$FILES_BASE/$rel" "$FILES_DIR/$rel" || echo "warn  missing dict $rel"
  done < "$DICT_LIST_FILE"
fi

if [[ "$FULL" == "1" ]]; then
  echo "==> FULL=1: recursive mirror of dicts/ (may be large)"
  if command -v wget >/dev/null 2>&1; then
    wget -r -np -nH --cut-dirs=0 -R "index.html*" -P "$FILES_DIR" "$FILES_BASE/dicts/" || true
  else
    echo "wget not found; skip full dicts mirror"
  fi
fi

echo ""
echo "Done."
echo "  files -> $FILES_DIR"
echo "  libs  -> $LIBS_DIR"
# Ensure world-readable for nginx inside Docker (macOS sync often creates 700 dirs)
chmod -R a+rX "$FILES_DIR" "$LIBS_DIR" 2>/dev/null || true
echo "Next: pnpm run docker-build && docker build -f Dockerfile.static -t typewords:local ."
echo "Tip: FULL=1 FORCE=1 $0  # re-download + optional full dicts tree"
