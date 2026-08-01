#!/usr/bin/env python3
"""Assemble dialogue_outer_frame_overlay_v05 from real hud_left_rail_plate_v03 pixels."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
RAIL = ROOT / "RainShadow Shared/Resources/Art/UI/HUD/hud_left_rail_plate_v03.png"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_outer_frame_overlay_v05.png"
GEN = ROOT / "ArtSource/Generated/UI/Dialogue"


def tile_vertical(strip: Image.Image, target_h: int) -> Image.Image:
    sw, sh = strip.size
    if sh >= target_h:
        return strip.resize((sw, target_h), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (sw, target_h), (0, 0, 0, 0))
    y = 0
    while y < target_h:
        piece = strip if y + sh <= target_h else strip.crop((0, 0, sw, target_h - y))
        out.paste(piece, (0, y), piece)
        y += sh
    return out


def tile_horizontal(strip: Image.Image, target_w: int) -> Image.Image:
    sw, sh = strip.size
    if sw >= target_w:
        return strip.resize((target_w, sh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (target_w, sh), (0, 0, 0, 0))
    x = 0
    while x < target_w:
        piece = strip if x + sw <= target_w else strip.crop((0, 0, target_w - x, sh))
        out.paste(piece, (x, 0), piece)
        x += sw
    return out


def main() -> None:
    rail = Image.open(RAIL).convert("RGBA")
    arr = np.array(rail)
    ys, xs = np.where(arr[:, :, 3] > 40)
    rail = rail.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    rw, rh = rail.size
    print(f"rail {rw}x{rh}")

    cap_h = max(40, int(rh * 0.052))
    top_cap = rail.crop((0, 0, rw, cap_h))
    bot_cap = rail.crop((0, rh - cap_h, rw, rh))

    mid_y0, mid_y1 = int(rh * 0.15), int(rh * 0.85)
    left_w = int(rw * 0.28)
    left_bevel = rail.crop((0, mid_y0, left_w, mid_y1))

    slot_band_top = int(rh * 0.095)
    slot_band_bot = int(rh * 0.905)
    slot_h = (slot_band_bot - slot_band_top) // 12
    sy0 = slot_band_top + 4 * slot_h
    slot = rail.crop((int(rw * 0.06), sy0, int(rw * 0.94), sy0 + slot_h))
    under_cap = rail.crop((0, cap_h, rw, cap_h + max(20, int(rw * 0.15))))

    dbg = GEN / "_sidebar_parts"
    dbg.mkdir(parents=True, exist_ok=True)
    top_cap.save(dbg / "top_cap.png")
    slot.save(dbg / "slot.png")
    left_bevel.save(dbg / "left_bevel.png")

    w, h = 1720, 730
    bevel_t = max(40, int(min(w, h) * 0.078))
    lip = 10
    print(f"bevel_t={bevel_t}")

    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    side_h = h - bevel_t * 2
    left_src = left_bevel.resize((bevel_t, left_bevel.height), Image.Resampling.LANCZOS)
    left = tile_vertical(left_src, side_h)
    right = tile_vertical(ImageOps.mirror(left_src), side_h)

    top_bar_src = under_cap.resize((under_cap.width, bevel_t), Image.Resampling.LANCZOS)
    top_bar = tile_horizontal(top_bar_src, w)
    bot_bar = ImageOps.flip(top_bar)

    canvas.paste(top_bar, (0, 0), top_bar)
    canvas.paste(bot_bar, (0, h - bevel_t), bot_bar)
    canvas.paste(left, (0, bevel_t), left)
    canvas.paste(right, (w - bevel_t, bevel_t), right)

    corner = rail.crop((0, cap_h, left_w, cap_h + left_w)).resize(
        (bevel_t, bevel_t), Image.Resampling.LANCZOS
    )
    canvas.paste(corner, (0, 0), corner)
    canvas.paste(ImageOps.mirror(corner), (w - bevel_t, 0), ImageOps.mirror(corner))
    canvas.paste(ImageOps.flip(corner), (0, h - bevel_t), ImageOps.flip(corner))
    canvas.paste(
        ImageOps.flip(ImageOps.mirror(corner)),
        (w - bevel_t, h - bevel_t),
        ImageOps.flip(ImageOps.mirror(corner)),
    )

    cap_w = int(w * 0.11)
    cap_hh = int(bevel_t * 1.55)
    cap_top = top_cap.resize((cap_w, cap_hh), Image.Resampling.LANCZOS)
    cap_bot = bot_cap.resize((cap_w, cap_hh), Image.Resampling.LANCZOS)
    cx = (w - cap_w) // 2
    cy_top = max(0, bevel_t // 2 - cap_hh // 2)
    cy_bot = h - bevel_t // 2 - cap_hh // 2
    canvas.alpha_composite(cap_top, (cx, cy_top))
    canvas.alpha_composite(cap_bot, (cx, cy_bot))

    # Portrait = real icon-slot rim
    slot_r = slot.resize((int(w * 0.155), int(h * 0.32)), Image.Resampling.LANCZOS)
    sa = np.array(slot_r)
    sh, sw = sa.shape[:2]
    inset = 0.16
    x0, x1 = int(sw * inset), int(sw * (1 - inset))
    y0, y1 = int(sh * inset), int(sh * (1 - inset))
    sa[y0:y1, x0:x1] = 0
    slot_rim = Image.fromarray(sa, "RGBA")
    px = bevel_t + 6
    py = bevel_t + 6
    canvas.alpha_composite(slot_rim, (px, py))

    fa = np.array(canvas)
    ppy0, ppy1 = py + y0, py + y1
    ppx0, ppx1 = px + x0, px + x1

    # Transparent content well; keep outer chrome + portrait rim
    chrome = fa[:, :, 3] > 40
    pr = np.zeros((h, w), dtype=bool)
    pr[py : py + sh, px : px + sw] = chrome[py : py + sh, px : px + sw]
    inner = np.zeros((h, w), dtype=bool)
    inner[bevel_t + 4 : h - bevel_t - 4, bevel_t + 4 : w - bevel_t - 4] = True
    fa[inner & ~pr] = 0
    fa[ppy0:ppy1, ppx0:ppx1] = 0

    img = Image.fromarray(fa, "RGBA")
    # Re-assert caps and portrait rim on top after punch
    img.alpha_composite(slot_rim, (px, py))
    fa = np.array(img)
    fa[ppy0:ppy1, ppx0:ppx1] = 0
    img = Image.fromarray(fa, "RGBA")
    img.alpha_composite(cap_top, (cx, cy_top))
    img.alpha_composite(cap_bot, (cx, cy_bot))

    img = img.filter(ImageFilter.GaussianBlur(0.3))
    fa = np.array(img)
    fa[:, :, 3] = np.where(fa[:, :, 3] > 24, 255, 0).astype(np.uint8)
    chrome = fa[:, :, 3] > 40
    pr = np.zeros((h, w), dtype=bool)
    pr[py : py + sh, px : px + sw] = chrome[py : py + sh, px : px + sw]
    fa[inner & ~pr] = 0
    fa[ppy0:ppy1, ppx0:ppx1] = 0
    img = Image.fromarray(fa, "RGBA")

    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    GEN.mkdir(parents=True, exist_ok=True)
    img.save(RUNTIME)

    chroma = Image.new("RGBA", (w, h), (0, 255, 0, 255))
    chroma.alpha_composite(img)
    chroma.save(GEN / "dialogue_outer_frame_overlay_v05_sidebar_pixels.png")
    chroma.save(GEN / "dialogue_outer_frame_overlay_v05_gen.png")

    prev = Image.new("RGBA", (w, h), (18, 18, 22, 255))
    prev.alpha_composite(img)
    prev.save(GEN / "dialogue_outer_frame_overlay_v05_preview.png")

    rail_prev = rail.resize((120, h), Image.Resampling.LANCZOS)
    compare = Image.new("RGB", (w + 140, h), (18, 18, 22))
    compare.paste(rail_prev.convert("RGB"), (0, 0))
    compare.paste(prev.convert("RGB"), (140, 0))
    compare.save(GEN / "dialogue_outer_frame_v05_vs_sidebar.png")

    print(f"wrote {RUNTIME} opaque%={(fa[:, :, 3] > 128).mean():.3f}")
    print(f"portrait at ({px},{py}) size={slot_rim.size}")


if __name__ == "__main__":
    main()
