#!/usr/bin/env bash
# Rebuild assets/walkthrough.gif from the slide-*.html source in this folder.
#
# Usage:  bash assets/walkthrough/build.sh
# Requires: node + the `playwright` npm package (with the chromium browser
#           installed via `npx playwright install chromium`), and `ffmpeg`.
#
# To refresh the walkthrough: edit the slide-*.html files, run this script,
# then commit the regenerated ../walkthrough.gif.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_GIF="${SCRIPT_DIR}/../walkthrough.gif"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SECONDS_PER_SLIDE=4   # each slide holds ~4s (matches the original ~29s deck)
FPS=10

# --- 1. Render each slide HTML to a PNG via headless Chromium (Playwright) ---
cat > "${TMP}/render.mjs" <<'NODE'
import { chromium } from 'playwright';
const dir = process.argv[2], out = process.argv[3];
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
for (let n = 1; n <= 7; n++) {
  // file URL is derived from the passed-in dir at runtime -- no hardcoded paths.
  const url = 'file://' + dir.replace(/\\/g, '/') + '/slide-' + n + '.html';
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(250);
  await page.screenshot({ path: out + '/frame-' + n + '.png' });
}
await browser.close();
NODE

node "${TMP}/render.mjs" "$SCRIPT_DIR" "$TMP"

# --- 2. Expand the 7 stills into a held-frame sequence, then assemble the GIF ---
# Each slide repeats for (SECONDS_PER_SLIDE * FPS) frames so it holds on screen.
i=0
for n in $(seq 1 7); do
  for _ in $(seq 1 $((SECONDS_PER_SLIDE * FPS))); do
    cp "${TMP}/frame-${n}.png" "$(printf '%s/seq-%04d.png' "$TMP" "$i")"
    i=$((i + 1))
  done
done

# Two-pass palette for a clean, small GIF; scale 1280x720 -> 800x450 (original dims).
ffmpeg -y -framerate "$FPS" -i "${TMP}/seq-%04d.png" \
  -vf "scale=800:450:flags=lanczos,palettegen=max_colors=128" "${TMP}/palette.png"
ffmpeg -y -framerate "$FPS" -i "${TMP}/seq-%04d.png" -i "${TMP}/palette.png" \
  -lavfi "scale=800:450:flags=lanczos[x];[x][1:v]paletteuse" "$OUT_GIF"

echo "Wrote ${OUT_GIF}"
