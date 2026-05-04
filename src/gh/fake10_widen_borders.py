#!/usr/bin/env python3
"""
Widen Fake10 xfwm4 side borders so every window has a usable
resize-grab zone, and recolor them to match the theme's title bar.

xfwm4 uses the border image dimensions as the resize hot zone *and* the
visible chrome thickness, so the default 1px borders give you a single
pixel to grab — and a 1px-thick visible chrome that still gets ignored
by GTK CSD apps anyway.

We rewrite each side XPM to be RESIZE_PX (4) thick with all pixels
opaque, and recolor the opaque pixel to BORDER_COLOR (white) so the
border blends with the title bar (Fake10 Light / Fake10 use #FFFFFF as
the title-bar background) and the window has a single uniform chrome.

Top is intentionally skipped: top resize is only at the corners (the
top edge itself is the title bar drag zone, governed by frame_border_top
in themerc, not by an image).
"""
import os
import re

RESIZE_PX = 4
BORDER_COLOR = "#FFFFFF"
SIDES = ("left", "right", "bottom")
VARIANTS = (
    "Fake10",
    "Fake10 Light",
    "Fake10 Accent Color",
    "Fake10 Light Accent Color",
)
THEMES_ROOT = "/usr/share/themes"


def widen(path: str, side: str) -> bool:
    txt = open(path).read()
    header = re.search(r'"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"', txt)
    if not header:
        return False
    w, h, ncolors, chars = (int(x) for x in header.groups())

    color_lines = re.findall(r'"[^"]*?c[^"]*?"', txt)[:ncolors]

    opaque_char = None
    opaque_idx = None
    for idx, cl in enumerate(color_lines):
        m = re.match(r'"(.{%d})\s+c\s+(\S+?)(?:\s|"|$)' % chars, cl)
        if m and m.group(2).lower() != "none":
            opaque_char = m.group(1)
            opaque_idx = idx
            break
    if opaque_char is None:
        return False

    # Override the opaque color with the theme-matching white. Drop any
    # `s symbol` suffix (the accent-color variants attach `s active_color_1`
    # etc; we want a fixed white border, not the user's accent color).
    color_lines = list(color_lines)
    color_lines[opaque_idx] = f'"{opaque_char}{" " * chars}c {BORDER_COLOR}"'

    # Per side, the outermost pixel (the one furthest from the window
    # content) is transparent so the visible chrome aligns with the
    # title bar's outer edge — without it, the body looks 1px wider
    # than the title bar. The transparent pixel is still part of the
    # image footprint, so xfwm4 keeps the full RESIZE_PX hot zone.
    transparent_char = " " * chars
    if side == "left":
        # rendered to the LEFT of window; image's leftmost col is outermost
        row = transparent_char + opaque_char * (RESIZE_PX - 1)
        rows = [row] * h
        new_w, new_h = RESIZE_PX, h
    elif side == "right":
        # rendered to the RIGHT of window; image's rightmost col is outermost
        row = opaque_char * (RESIZE_PX - 1) + transparent_char
        rows = [row] * h
        new_w, new_h = RESIZE_PX, h
    else:  # bottom — rendered BELOW window; image's bottom row is outermost
        rows = [opaque_char * w] * (RESIZE_PX - 1) + [transparent_char * w]
        new_w, new_h = w, RESIZE_PX

    varname = re.search(r'static char \* (\w+)\[\]', txt)
    varname = varname.group(1) if varname else "xpm"
    out = ["/* XPM */", f"static char * {varname}[] = {{"]
    out.append(f'"{new_w} {new_h} {ncolors} {chars}",')
    out.extend(c + "," for c in color_lines)
    for i, r in enumerate(rows):
        suffix = "," if i < len(rows) - 1 else ""
        out.append(f'"{r}"{suffix}')
    out.append("};")

    open(path, "w").write("\n".join(out) + "\n")
    return True


CORNERS = {
    # corner_name -> (outer_x_index_resolver, outer_y_index_resolver)
    # Each resolver maps image dims (w, h) to the outermost corner coord.
    # We chip a 2x2 stairstep at that corner: the outer-most pixel and
    # the two pixels orthogonally adjacent to it become transparent.
    "top-left":     lambda w, h: (0, 0),
    "top-right":    lambda w, h: (w - 1, 0),
    "bottom-left":  lambda w, h: (0, h - 1),
    "bottom-right": lambda w, h: (w - 1, h - 1),
}


def round_corner(path: str, corner: str, fill: bool = False) -> bool:
    """
    Modify a corner XPM. With fill=False (the default, used for top
    corners), preserves the original pixel pattern and just chips the
    outer-corner pixel + 2 adjacent ones to give a 2px-radius rounded
    look. With fill=True (used for bottom corners), discards the
    original pixel pattern and fills the entire image with the
    BORDER_COLOR opaque char so the corner becomes one solid block —
    xfwm4 4.20 hit-tests resize zones based on opaque pixels, so this
    gives the user a full-corner click target instead of just the
    1px L-strip the original Fake10 had.

    The 2px chip is applied last in both modes so the very outer
    corner pixel stays transparent for a slight rounded silhouette.
    """
    txt = open(path).read()
    header = re.search(r'"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"', txt)
    if not header:
        return False
    w, h, ncolors, chars = (int(x) for x in header.groups())

    quoted = re.findall(r'"([^"]*)"', txt)
    if len(quoted) < 1 + ncolors + h:
        return False
    color_lines_full = [f'"{q}"' for q in quoted[1:1 + ncolors]]
    pixel_rows = quoted[1 + ncolors:1 + ncolors + h]

    # Locate transparent + opaque entries. (`fill` mode needs a single
    # opaque char to paint with; chipping needs the transparent char.)
    transparent_char = None
    opaque_indices = []
    for idx, cl in enumerate(quoted[1:1 + ncolors]):
        m = re.match(r'(.{%d})\s+c\s+(\S+?)(?:\s|$)' % chars, cl)
        if not m:
            continue
        if m.group(2).lower() == "none":
            transparent_char = m.group(1)
        else:
            opaque_indices.append(idx)
    if transparent_char is None:
        used = {cl[:chars] for cl in quoted[1:1 + ncolors]}
        for c in " .#+@*":
            if c * chars not in used:
                transparent_char = c * chars
                break
        if transparent_char is None:
            return False
        color_lines_full.append(f'"{transparent_char}\tc None"')
        ncolors += 1

    if fill:
        # Bottom corners come in gray-only; the top corners have a
        # gray accent line + white fill that we want to preserve, so
        # only single-opaque corners get the white recolor + full fill.
        if len(opaque_indices) != 1:
            return False
        idx = opaque_indices[0]
        opaque_char = quoted[1 + idx][:chars]
        color_lines_full[idx] = f'"{opaque_char}{" " * chars}c {BORDER_COLOR}"'
        rows_cells = [[opaque_char] * w for _ in range(h)]
    else:
        # Single opaque color → still recolor to white (used to blend
        # bottom corners, but harmless here since we won't be fill=True
        # in this branch — keeping for symmetry).
        if len(opaque_indices) == 1:
            idx = opaque_indices[0]
            opaque_char = quoted[1 + idx][:chars]
            color_lines_full[idx] = f'"{opaque_char}{" " * chars}c {BORDER_COLOR}"'
        rows_cells = [[r[i:i + chars] for i in range(0, len(r), chars)]
                      for r in pixel_rows]

    cx, cy = CORNERS[corner](w, h)
    dx = 1 if cx == 0 else -1
    dy = 1 if cy == 0 else -1
    chip = [(cx, cy), (cx + dx, cy), (cx, cy + dy)]
    for x, y in chip:
        if 0 <= x < w and 0 <= y < h:
            rows_cells[y][x] = transparent_char
    new_rows = ["".join(cells) for cells in rows_cells]

    varname = re.search(r'static char \* (\w+)\[\]', txt)
    varname = varname.group(1) if varname else "xpm"
    out = ["/* XPM */", f"static char * {varname}[] = {{"]
    out.append(f'"{w} {h} {ncolors} {chars}",')
    out.extend(c + "," for c in color_lines_full)
    for i, r in enumerate(new_rows):
        suffix = "," if i < len(new_rows) - 1 else ""
        out.append(f'"{r}"{suffix}')
    out.append("};")
    open(path, "w").write("\n".join(out) + "\n")
    return True


def main() -> None:
    for variant in VARIANTS:
        base = os.path.join(THEMES_ROOT, variant, "xfwm4")
        if not os.path.isdir(base):
            continue
        for state in ("active", "inactive"):
            for side in SIDES:
                path = os.path.join(base, f"{side}-{state}.xpm")
                if os.path.isfile(path) and widen(path, side):
                    print(f"widened {path}")
            for corner in CORNERS:
                path = os.path.join(base, f"{corner}-{state}.xpm")
                if not os.path.isfile(path):
                    continue
                # Bottom corners are filled solid white so the click
                # target spans the whole 16x16 corner area; top corners
                # preserve their gray-line/title-fill pattern.
                fill = corner.startswith("bottom")
                if round_corner(path, corner, fill=fill):
                    print(f"{'filled' if fill else 'rounded'} {path}")


if __name__ == "__main__":
    main()
