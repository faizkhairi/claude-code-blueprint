# Walkthrough deck (source for `../walkthrough.gif`)

The README hero animation (`assets/walkthrough.gif`) is generated from the seven
`slide-*.html` files in this folder. Keeping the source here means the GIF can be
refreshed without re-recording it from scratch.

## To refresh the GIF

1. Edit the relevant `slide-*.html` (each is a self-contained 1280×720 page).
2. Run the build script from the repo root:

   ```bash
   bash assets/walkthrough/build.sh
   ```

3. Commit the regenerated `assets/walkthrough.gif`.

## Requirements

- **Node** with the `playwright` package and its Chromium browser
  (`npm i playwright && npx playwright install chromium`) — renders each slide to a PNG.
- **ffmpeg** — assembles the PNG frames into the GIF (two-pass palette, scaled to 800×450).

The script holds each slide ~4 seconds at 10 fps and writes straight to `../walkthrough.gif`.
It derives its own location at runtime, so it works from any clone without editing paths.
