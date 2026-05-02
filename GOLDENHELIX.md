# Golden Helix Fork of `kasmtech/workspaces-core-images`

This repo builds **`ghdesktop-core`** — the base XFCE desktop image
that everything else (office-web, varseq, etc.) layers on top of. It's
a Debian 13 (Trixie) base + KasmVNC + XFCE 4.20 + a stack of
goldenhelix UI defaults and small tweaks.

## What this repo IS

A fork of `kasmtech/workspaces-core-images` (originally Ubuntu-based)
that we've adapted to:

1. Use **Debian 13 trixie-slim** as the base (`debian:trixie-slim`).
   Trixie's XFCE is 4.20, glibc / Qt6 stack is current, distro size
   is reasonable.
2. Pull a **bring-your-own `kasmvncserver.deb`** from
   `src/trixie/kasmvncserver.deb` (built from our `KasmVNC` fork via
   `./build_deb.sh debian trixie`) instead of the stock Kasm builds.
3. Apply our XFCE defaults: VarSeq branding, `Fake10 Light` GTK theme,
   `elementary-xfce` icon theme, custom panel layout, Thunar
   preferences, etc.
4. Wire our three Unix-relay features (openurl, download, upload) into
   the session startup.

## Branch and pinning

- Long-lived branch: **`goldenhelix-master-20260430`** in
  `goldenhelix/workspaces-core-images` (after fork).
- Forked from `kasmtech/workspaces-core-images` `develop` (the only
  branch with a 24.04+ base; commit `ca4eedc` "KASM-7900 Update OS
  Versions"). We don't track that branch anymore — we follow Debian
  Trixie via `BASE_IMAGE` build arg.

## Repo structure

```
dockerfile-gh-core            ← the build, parameterized by BASE_IMAGE + KASMVNC_DEB
build-trixie.sh               ← convenience wrapper for the trixie build
src/
  trixie/kasmvncserver.deb    ← staged by ../KasmVNC/build_deb.sh
  themes/Fake10-v6.tar.gz     ← bundled GTK + xfwm4 theme
  common/install/icons/       ← drop custom hicolor icons here, rebuilt cache
  gh/                         ← all our overrides (see below)
  ubuntu/install/             ← upstream Kasm install scripts (kept verbatim
                                except for sed-patches in dockerfile)
  common/                     ← upstream Kasm common scripts
```

The `src/gh/` tree is everything goldenhelix-specific:

```
src/gh/
  vnc_startup.sh                   ← entrypoint replacing upstream's
  fullscreen_window.sh             ← used by app images for fullscreen mode
  .config/xfce4/
    xfconf/xfce-perchannel-xml/
      xfce4-panel.xml              ← panel layout (size, plugins, slots)
      xfwm4.xml                    ← window manager (theme, snap, fonts)
      xsettings.xml                ← GTK theme, icon theme, cursor
      xfce4-desktop.xml            ← background, root menu
      xfce4-keyboard-shortcuts.xml
      xfce4-session.xml
      thunar.xml                   ← file manager preferences
      displays.xml
    panel/launcher-5/              ← panel app shortcuts
      17306765011.desktop          ← chromium (visible icon)
      17306804393.desktop          ← onlyoffice (popup)
      17306804534.desktop          ← terminal (popup)
      17306804705.desktop          ← reserved for varseq (popup; filled by app images)
      17306804756.desktop          ← vscode (popup)
      17777337971.desktop          ← Application Finder (popup)
```

## What we override vs upstream

### Defaults (`src/gh/.config/xfce4/xfconf/xfce-perchannel-xml/`)

All of these are tweaks the user verified by hand in a running
container:

| File | Setting | Value | Why |
|------|---------|-------|-----|
| `xfwm4.xml` | `theme` | `"Fake10 Light"` | Matches the Fake10 GTK theme. |
| `xfwm4.xml` | `box_move`, `box_resize` | `false` | Show full window contents during move/resize (4.20 default is `true` = outline only). |
| `xfwm4.xml` | `snap_to_border` | `true` | Snap windows to screen edges when dragging. |
| `xfwm4.xml` | `title_horizontal_offset` | `0` (xfconf) — themerc patched to `4` | Adds breathing room before the title text; Fake10 themerc shipped with `-10` which pushed it against the corner. |
| `xfwm4.xml` | `title_font` | `"Sans 10"` | No bold; less crowded. |
| `xfce4-panel.xml` | `dark-mode` | `false` | Light panel on light theme. |
| `xfce4-panel.xml` | `autohide-behavior` | `0` (never) | Always visible. |
| `xfce4-panel.xml` | `length` / `length-adjust` | `10` / `true` | Auto-grow from corner up to 10% of edge. |
| `xfce4-panel.xml` | `position-locked` | `false` | User can drag the panel. |
| `xfce4-panel.xml` | `enable-struts` | `false` | Don't reserve screen space (we have a small panel). |
| `xfce4-panel.xml` | `leave-opacity` | `78` | Slightly translucent when not hovered. |
| `xfce4-panel.xml` plugin-2 (tasklist) | `show-labels`, `flat-buttons`, `grouping=false`, `max-button-length=40`, `sort-order=1` | per the table | Each window gets its own button with a label, narrow buttons, sorted by app/title (XFCE 4.20 changed defaults to wider buttons + always-group). |
| `xfce4-panel.xml` plugin-ids | `[16, 4, 5, 2]` | (no applicationsmenu) | We dropped the system applications menu plugin in favor of an "Application Finder" launcher entry. |
| `xfce4-panel.xml` plugin-5 items | adds `17777337971.desktop` (Application Finder) | last in list (popup) | Reachable from the launcher dropdown. |
| `xsettings.xml` | `Net/ThemeName` | `"Fake10 Light"` | The default GTK theme. |
| `xsettings.xml` | `Net/IconThemeName` | `"elementary-xfce"` | Default icon theme. |
| `xsettings.xml` | `Gtk/CursorThemeName` | `"bridge"` | Cursor theme. |
| `xsettings.xml` | `Gtk/DecorationLayout` | `":maximize,close"` | Window button layout. |
| `thunar.xml` | `last-location-bar` | `"ThunarLocationButtons"` | Breadcrumb-style location bar (default is editable text path). |

### Dockerfile additions (on top of upstream `dockerfile-kasm-core`)

- **Bumps base to `debian:trixie-slim`** via `BASE_IMAGE` build arg.
- **Patches install_tools.sh in flight** to drop `software-properties-common` (gone in trixie).
- **Renames `cups-pdf` → `printer-driver-cups-pdf`** (cups-pdf gone in trixie; transitional on bookworm).
- **Adds Qt6 xcb plugin runtime libs**: `libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0`. Without these, VarSeq fails with "could not load the Qt platform plugin xcb".
- **Installs `kasmvncserver.deb`** from `src/trixie/` (built externally, see `../KasmVNC/`).
- **Bundles `Fake10` GTK theme** from `src/themes/Fake10-v6.tar.gz`. Patches the xfwm4 themerc to fix `title_horizontal_offset=-10` → `4`.
- **Installs `elementary-xfce-icon-theme`** + runs `gtk-update-icon-cache`.
- **Bundles custom hicolor icons** from `src/common/install/icons/hicolor/` and rebuilds the cache. (Empty by default; drop SVGs/PNGs in there per the README.)
- **Doesn't install `xdg-open` shim by default** — the kasmvnc deb provides `/usr/bin/kasmvnc-xdg-open` and `/usr/bin/kasmvnc-open-url`, but we deliberately don't symlink them into `/usr/local/bin/xdg-open`. Apps explicitly call `kasmvnc-open-url` when they want a link to open in the user's native browser; everything else (e.g. VS Code's `xdg-open http://127.0.0.1:8080`) stays in-container.
- **Sets `~/.local/share/applications/mimeapps.list`** with `text/plain=mousepad.desktop` (no other defaults).
- **Sets `~/.config/Thunar/uca.xml`** seeded from `/usr/share/kasmvnc/thunar-uca.xml` (the right-click Download action) — only if the user doesn't already have a uca.xml.
- **Pre-creates `$HOME/Workspace/Documents/$USERNAME`** in vnc_startup.sh, plus XDG_DOCUMENTS_DIR pointer.

### `vnc_startup.sh`

Replaces the upstream entrypoint. Key things it does:
1. Creates the SSL cert.
2. Adds the VNC user.
3. **Starts Xvnc with three UnixRelay flags**: `openurl`, `download`,
   `upload` — see KasmVNC repo `unix/{openurl,download,upload}/` for
   the per-feature design.
4. Seeds Thunar UCA with our Download right-click entry.
5. **Starts `kasmvnc-upload-daemon`** in the background as ghuser
   (with DEBUG logging to `~/.vnc/upload-daemon.log`).
6. Launches `startxfce4 --replace`.
7. **Backgrounded loop after xfce4-session is up**: marks all
   `~/Desktop/*.desktop` and `~/.config/xfce4/panel/launcher-*/*.desktop`
   as trusted via `gio set metadata::xfce-exe-checksum` + `chmod +x`,
   so XFCE 4.18+ doesn't pop the "Untrusted application launcher"
   dialog. Has to run *after* xfce4-session because gvfsd-metadata is
   started by the xfce session bus.

## How to build

Stage the deb first (from `../KasmVNC/`):
```sh
cd ../KasmVNC
./build_deb.sh debian trixie
```

Then:
```sh
./build-trixie.sh
```

Builds `registry.goldenhelix.com/public/ghdesktop-core-trixie:latest` (and a dated tag).

## Variants we used to maintain (and dropped)

- `dockerfile-gh-core` (with `BASE_IMAGE=debian:bookworm-slim`) — the
  original, smaller base but stuck on XFCE 4.18.
- `dockerfile-gh-core` (with `BASE_IMAGE=ubuntu:24.04`, "noble") —
  worked but had input-event glitches and Ubuntu 24.04's added bloat
  (`ubuntu-pro-client`, snap leftovers).
- `dockerfile-gh-core` (with `BASE_IMAGE=ubuntu:22.04`, "jammy") —
  worked, similar size to bookworm.

These targets and the corresponding `build*.sh` scripts may still be
present in the tree; safe to delete in a future cleanup pass. **Trixie
is the only one we test against now.**
