# Bundled icons

Drop custom application icons here; the dockerfile-gh-core build copies
the `hicolor/` tree into `/usr/share/icons/hicolor` inside the image
and runs `gtk-update-icon-cache` so the new icons are pickup-ready.

## Layout

Mirror the standard hicolor freedesktop layout:

    hicolor/
      scalable/apps/<name>.svg          ← preferred (scales)
      256x256/apps/<name>.png           ← fallback for raster
      128x128/apps/<name>.png
      64x64/apps/<name>.png
      48x48/apps/<name>.png
      32x32/apps/<name>.png
      24x24/apps/<name>.png
      22x22/apps/<name>.png
      16x16/apps/<name>.png

`<name>` is the lookup key. In any `.desktop` file under
`/usr/share/applications/` (or in a panel `launcher-N/*.desktop`):

    Icon=<name>

GTK then resolves `<name>` against the active icon theme, falling
through to hicolor if the theme doesn't define it. Don't include the
extension or path.

## Recommendations

- **Ship at least one SVG** at `scalable/apps/<name>.svg`. One file,
  scales cleanly across panel (32px) → menu (48px) → app finder (128px).
  Use a 256x256 viewBox so detail holds at large sizes. Transparent
  background. Avoid baked-in shadows.
- **Or one large PNG** at `256x256/apps/<name>.png`. GTK downscales
  gracefully but won't upscale, so don't ship only a 48x48.
- **Multiple sizes** are best when you can — different panel sizes
  pull different files.
- For **monochrome symbolic icons** (theme-recolored): suffix
  `-symbolic` and use `currentColor` in the SVG.

## Where this gets used

After `gtk-update-icon-cache` runs, any `.desktop` file referencing
`Icon=<your-name>` resolves correctly — that includes:

- Custom panel launcher items (see `src/common/install/applications/`
  for the existing `gh-applications-menu.desktop`).
- Per-image launchers like the VarSeq one (see
  `appstream-images/src/varseq/install_varseq.sh`).

For one-off icons that ship with the app itself (like VarSeq's
`/opt/VarSeq/varseq_icon.png`), you can keep them inside the app dir
and reference by absolute path in the `.desktop` (`Icon=/opt/.../foo.png`).
The hicolor path is for icons that need to be theme-aware or
referenced by multiple `.desktop` files.
