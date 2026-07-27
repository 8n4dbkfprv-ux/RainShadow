"""Ship Image Generator door leaves with baked H. VOSS glass lettering.

Sources (prefer V10.2 upright chroma masters):
  office_door_leaf_ig_v102_chroma.png (fallback v10.1 / v10)
  office_internal_door_leaf_solo_chroma_v101.png (fallback v10)
  office_door_frame_ig_v101_voss_reference_chroma.png (fallback v10 / v04)

Does NOT blank frosted glass — lettering is intentional.
Fits leaves into the partition/exterior opening without non-uniform stretch.
Frame is sized so its INNER aperture matches the exterior leaf canvas.
The exterior knob is normalized to a handle height derived from the shipped Voss.
Default invocation ships props only; pass --rebuild-walls to also rewrite plates
(prefer process_office_door_aperture_v10.py to keep wall crowns locked).
"""

from __future__ import annotations

import json
import shutil
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from generate_office_hover_assets import bake as bake_hover
import process_office_partition_plate_v01 as part
import process_office_suite_plate_v01 as suite
import office_room_plan as rp
from process_office_personal_corner_v01 import opaque_content_height
from process_office_window_door_v04 import chroma_key, trim_alpha

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
GEN = ROOT / "ArtSource/Generated/Office/Props"
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"

# Exterior leaf canvas — V10.1 detective-relative opening aspect (~2.2 H/W).
EXTERIOR_LEAF_H = 640
EXTERIOR_LEAF_W = int(round(EXTERIOR_LEAF_H / 2.2))


def _first_existing(*paths: Path) -> Path:
    for path in paths:
        if path.exists():
            return path
    raise SystemExit(f"missing any of {[str(p) for p in paths]}")


def _copy_if_distinct(src: Path, dst: Path) -> None:
    """Archive a source without failing when the project-local fallback wins."""
    if src.resolve() != dst.resolve():
        shutil.copy(src, dst)


def fit_cover(im: Image.Image, door_w: int, door_h: int) -> Image.Image:
    """Scale uniformly to cover the opening canvas (may crop edges slightly)."""
    body = trim_alpha(im)
    if body.width < 2 or body.height < 2:
        return Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
    scale = max(door_w / body.width, door_h / body.height)
    nw = max(1, int(round(body.width * scale)))
    nh = max(1, int(round(body.height * scale)))
    resized = body.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
    x = (door_w - nw) // 2
    y = (door_h - nh) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def fit_complete_leaf(im: Image.Image, door_w: int, door_h: int) -> Image.Image:
    """Fit the complete generated leaf to the approved aperture.

    V10.4 was regenerated close to the 2.2:1 opening aspect. A small exact
    normalization is preferable to cover-cropping because every outer rail is
    construction-critical and must survive the wall projection intact.
    """
    body = trim_alpha(im)
    if body.width < 2 or body.height < 2:
        return Image.new("RGBA", (door_w, door_h), (0, 0, 0, 0))
    return body.resize((door_w, door_h), Image.Resampling.LANCZOS)


def _harden_door_matte(im: Image.Image, thr: int = 48) -> Image.Image:
    """Kill soft chroma fringes so leaves read as cut props, not cropped cards."""
    arr = np.asarray(im.convert("RGBA"), np.float32).copy()
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    g, r, b = rgb[:, :, 1], rgb[:, :, 0], rgb[:, :, 2]
    greenish = (g > r + 12) & (g > b + 12) & (g > 30)
    alpha = np.where(greenish, 0, alpha)
    alpha = np.where(alpha < thr, 0, 255)
    # Mild despill on kept edge pixels.
    keep = alpha > 0
    spill = np.clip((g - np.maximum(r, b)) / 40.0, 0, 1)
    lum = rgb.mean(axis=2)
    rgb = rgb * (1.0 - spill[..., None] * 0.7) + lum[..., None] * (spill[..., None] * 0.7)
    rgb = np.where(keep[..., None], rgb, 0)
    return Image.fromarray(
        np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8), "RGBA"
    )


def _bevel_door_edges(im: Image.Image, hinge_right: bool = False) -> Image.Image:
    """Add a thin dark contact edge so the leaf seats against the jamb."""
    arr = np.asarray(im.convert("RGBA"), np.float32).copy()
    a = arr[:, :, 3]
    opaque = a > 40
    if not opaque.any():
        return im
    # 2-px morphological erosion without scipy.
    eroded = opaque.copy()
    for _ in range(2):
        nxt = eroded.copy()
        nxt[:, 1:] &= eroded[:, :-1]
        nxt[:, :-1] &= eroded[:, 1:]
        nxt[1:, :] &= eroded[:-1, :]
        nxt[:-1, :] &= eroded[1:, :]
        eroded = nxt
    rim = opaque & ~eroded
    arr[rim, :3] *= 0.55
    w = a.shape[1]
    if hinge_right:
        stile = opaque & (np.arange(w)[None, :] >= w - 3)
    else:
        stile = opaque & (np.arange(w)[None, :] <= 2)
    arr[stile, :3] *= 0.72
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _build_door_thickness(im: Image.Image, offset: tuple[int, int] = (9, 9)) -> Image.Image:
    """Dark lower/right extrusion revealed while the leaf tips toward the floor."""
    rgba = np.asarray(im.convert("RGBA"), np.uint8)
    alpha = rgba[:, :, 3]
    shifted = np.zeros_like(alpha)
    dx, dy = offset
    shifted[dy:, dx:] = alpha[: alpha.shape[0] - dy, : alpha.shape[1] - dx]
    edge = np.clip(shifted.astype(np.int16) - alpha.astype(np.int16), 0, 255).astype(np.uint8)
    edge = np.asarray(
        Image.fromarray(edge, "L").filter(ImageFilter.GaussianBlur(0.45)),
        np.uint8,
    )
    out = np.zeros_like(rgba)
    # Near-black walnut edge with a restrained warm lower rim.
    out[:, :, 0] = 30
    out[:, :, 1] = 18
    out[:, :, 2] = 11
    out[:, :, 3] = edge
    return Image.fromarray(out, "RGBA")


def _rectify_internal_leaf(
    im: Image.Image,
    door_w: int,
    door_h: int,
) -> Image.Image:
    """Rectify the generated front leaf into the shell's elevation rectangle.

    The Image Generator source is a perspective prop render: its hinge and
    latch stiles end at different image rows, and a sliver of the rear jamb is
    visible behind it. The runtime applies the office's isometric shear later,
    so retaining that source perspective makes the visible hinge about 50 plate
    pixels short of the partition shell. Sampling the front-leaf quadrilateral
    into the exact opening rectangle removes only that source-camera projection.
    """
    keyed = im.convert("RGBA")
    w, h = keyed.size
    # Normalized corners of the *front leaf* in the approved V05 generator
    # source, inset a few pixels so every output edge remains opaque. Keeping
    # these normalized also preserves the deterministic fallback resize path.
    quad = (
        0.254 * w,
        0.130 * h,  # upper-left
        0.254 * w,
        0.911 * h,  # lower-left
        0.771 * w,
        0.815 * h,  # lower-right
        0.771 * w,
        0.098 * h,  # upper-right
    )
    return keyed.transform(
        (door_w, door_h),
        Image.Transform.QUAD,
        quad,
        resample=Image.Resampling.BICUBIC,
    )


def _vertical_shear(im: Image.Image, slope: float) -> Image.Image:
    """Project an upright RGBA prop onto a wall whose base rises/falls by x*slope.

    Interpolation happens in premultiplied colour so transparent padding cannot
    introduce a dark fringe around the generated wood/glass edges.
    """
    src = np.asarray(im.convert("RGBA"), np.float32)
    h, w = src.shape[:2]
    rise = int(np.ceil(abs(slope) * max(0, w - 1)))
    out_h = h + rise
    out_a = np.zeros((out_h, w), np.float32)
    out_pm = np.zeros((out_h, w, 3), np.float32)
    src_a = src[:, :, 3] / 255.0
    src_pm = src[:, :, :3] * src_a[:, :, None]
    dst_y = np.arange(out_h, dtype=np.float32)
    offset = rise if slope < 0 else 0
    for x in range(w):
        src_y = dst_y - (offset + slope * x)
        out_a[:, x] = np.interp(
            src_y,
            np.arange(h, dtype=np.float32),
            src_a[:, x],
            left=0.0,
            right=0.0,
        )
        for channel in range(3):
            out_pm[:, x, channel] = np.interp(
                src_y,
                np.arange(h, dtype=np.float32),
                src_pm[:, x, channel],
                left=0.0,
                right=0.0,
            )
    out_rgb = np.divide(
        out_pm,
        np.maximum(out_a[:, :, None], 1e-6),
        out=np.zeros_like(out_pm),
        where=out_a[:, :, None] > 1e-6,
    )
    return Image.fromarray(
        np.dstack(
            [
                np.clip(out_rgb, 0, 255),
                np.clip(out_a * 255.0, 0, 255),
            ]
        ).astype(np.uint8),
        "RGBA",
    )


def _relocate_exterior_handle(leaf: Image.Image) -> Image.Image:
    """Move the brass knob to the detective-relative hardware height.

    The generated lettering and leaf remain stable. Only a small knob region on
    the image-left latch stile moves; neighboring stile grain fills its old
    location. The target center is 0.575 visible Voss heights above threshold.
    """
    im = leaf.convert("RGBA")
    arr = np.asarray(im).copy()
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    rgb = arr[:, :, :3].astype(np.int16)

    # Keep segmentation off the gold glass lettering.
    roi = (xx < int(w * 0.30)) & (yy > int(h * 0.42)) & (yy < int(h * 0.72))
    brass = (
        roi
        & (arr[:, :, 3] > 32)
        & (rgb[:, :, 0] > 58)
        & (rgb[:, :, 0] > rgb[:, :, 1] * 1.10)
        & (rgb[:, :, 1] > rgb[:, :, 2] * 1.12)
    )
    ys, xs = np.where(brass)
    if len(xs) < 30:
        return im

    # Find the densest brass neighborhood (knob and rose), then carry its dark
    # rim and tiny local shadow in a soft elliptical matte.
    hits = np.zeros((h, w), np.uint8)
    hits[ys, xs] = 255
    density = Image.fromarray(hits, "L").filter(
        ImageFilter.BoxBlur(max(3, int(round(h * 0.012))))
    )
    cy, cx = np.unravel_index(int(np.asarray(density).argmax()), (h, w))
    radius = max(24, int(round(h * 0.060)))
    x0, x1 = max(0, cx - radius), min(w, cx + radius + 1)
    y0, y1 = max(0, cy - radius), min(h, cy + radius + 1)
    knob = im.crop((x0, y0, x1, y1))

    kh, kw = y1 - y0, x1 - x0
    ky, kx = np.mgrid[0:kh, 0:kw]
    ellipse = ((kx - (cx - x0)) / max(1.0, radius * 0.92)) ** 2 + (
        (ky - (cy - y0)) / max(1.0, radius)
    ) ** 2
    kmask = Image.fromarray(np.where(ellipse <= 1.0, 255, 0).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(1.8)
    )
    knob.putalpha(Image.composite(knob.getchannel("A"), Image.new("L", knob.size), kmask))

    # Replace the old knob with an adjacent stretch of the same vertical grain.
    sy0 = min(max(0, h - kh), y1 + max(4, int(round(h * 0.015))))
    sy1 = min(h, sy0 + kh)
    fill = im.crop((x0, sy0, x1, sy1))
    if fill.size != (kw, kh):
        fill = fill.resize((kw, kh), Image.Resampling.LANCZOS)
    cleaned = im.copy()
    cleaned.paste(fill, (x0, y0), kmask)

    target_above_bottom = (
        rp.DOOR_HANDLE_HEIGHT / max(rp.BAKED_DOORWAY_H, 1.0) * EXTERIOR_LEAF_H
    )
    target_cy = int(round(h - target_above_bottom))
    target_cx = int(
        round(rp.DOOR_HANDLE_LATCH_INSET / max(rp.BAKED_DOORWAY_W, 1.0) * EXTERIOR_LEAF_W)
    )
    # Normalize the visible knob/rose diameter as well as its center.
    patch_size = max(
        28,
        int(
            round(
                rp.DOOR_HANDLE_DIAMETER
                / max(rp.BAKED_DOORWAY_H, 1.0)
                * EXTERIOR_LEAF_H
                * 1.65
            )
        ),
    )
    knob = knob.resize((patch_size, patch_size), Image.Resampling.LANCZOS)
    cleaned.alpha_composite(knob, (target_cx - patch_size // 2, target_cy - patch_size // 2))
    return cleaned


def _flood_inner(alpha: np.ndarray, thr: int = 16) -> np.ndarray:
    h, w = alpha.shape
    vis = np.zeros((h, w), dtype=bool)
    cy, cx = h // 2, w // 2
    q: deque[tuple[int, int]] = deque()
    if alpha[cy, cx] < thr:
        q.append((cy, cx))
        vis[cy, cx] = True
    else:
        found = False
        for radius in range(1, max(h, w) // 2):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    y, x = cy + dy, cx + dx
                    if 0 <= y < h and 0 <= x < w and alpha[y, x] < thr:
                        q.append((y, x))
                        vis[y, x] = True
                        found = True
                        break
                if found:
                    break
            if found:
                break
    while q:
        y, x = q.popleft()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not vis[ny, nx] and alpha[ny, nx] < thr:
                vis[ny, nx] = True
                q.append((ny, nx))
    return vis


def _mid_gap(alpha: np.ndarray, thr: int = 16) -> int | None:
    h, w = alpha.shape
    op = np.where(alpha[h // 2] > thr)[0]
    if len(op) < 2:
        return None
    left = op[op < w // 2]
    right = op[op > w // 2]
    if len(left) == 0 or len(right) == 0:
        return None
    return int(right.min() - left.max() - 1)


def _center_opaque_height(im: Image.Image, thr: int = 16) -> int:
    alpha = np.asarray(im.convert("RGBA"))[:, :, 3]
    ys = np.where(alpha[:, alpha.shape[1] // 2] > thr)[0]
    return int(ys.max() - ys.min() + 1) if len(ys) else 0


def ship_exterior() -> None:
    src = _first_existing(
        GEN / "office_door_leaf_ig_v104_chroma.png",
        ASSETS / "office_door_leaf_ig_v104_chroma.png",
        GEN / "office_door_leaf_ig_v102_chroma.png",
        ASSETS / "office_door_leaf_ig_v102_chroma.png",
        GEN / "office_door_leaf_ig_v101_chroma.png",
        ASSETS / "office_door_leaf_ig_v101_chroma.png",
        GEN / "office_door_leaf_ig_v10_chroma.png",
        ASSETS / "office_door_leaf_ig_v10_chroma.png",
        GEN / "office_door_leaf_ig_v07_wide.png",
        ASSETS / "office_door_leaf_ig_v07_wide.png",
        GEN / "office_door_leaf_ig_v06.png",
        ASSETS / "office_door_leaf_ig_v06.png",
    )
    GEN.mkdir(parents=True, exist_ok=True)
    _copy_if_distinct(src, GEN / src.name)
    keyed = chroma_key(Image.open(src))
    leaf = (
        fit_complete_leaf(keyed, EXTERIOR_LEAF_W, EXTERIOR_LEAF_H)
        if "v104" in src.name
        else fit_cover(keyed, EXTERIOR_LEAF_W, EXTERIOR_LEAF_H)
    )
    leaf = _harden_door_matte(leaf)
    # V10 IG knobs are already near the detective handle band; relocating them
    # left a circular wood bite in the stile, so skip the move for v10+ sources.
    if "v10" not in src.name and "v101" not in src.name:
        leaf = _relocate_exterior_handle(leaf)
    leaf = _bevel_door_edges(leaf, hinge_right=True)
    leaf = _vertical_shear(leaf, rp.AXIS_NE[1] / rp.AXIS_NE[0])
    leaf = _harden_door_matte(leaf, thr=32)
    leaf.save(RUNTIME / "office_door_leaf.png")
    leaf.save(GEN / "office_door_leaf.png")
    thickness = _build_door_thickness(leaf)
    thickness.save(RUNTIME / "office_door_leaf_thickness.png")
    thickness.save(GEN / "office_door_leaf_thickness.png")
    bake_hover(
        RUNTIME / "office_door_leaf.png",
        RUNTIME / "office_door_leaf_hover.png",
    )
    closed = Image.new("RGBA", (512, 896), (0, 0, 0, 0))
    closed.alpha_composite(leaf, ((512 - leaf.width) // 2, max(0, 896 - leaf.height - 8)))
    closed.save(RUNTIME / "office_door_leaf_closed.png")
    jamb_h = _center_opaque_height(leaf)
    print(
        "exterior",
        leaf.size,
        "jambH",
        jamb_h,
        f"jambH/W={jamb_h / max(1, EXTERIOR_LEAF_W):.2f}",
    )


def _trim16(im: Image.Image) -> Image.Image:
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.where(a > 16)
    if len(ys) == 0:
        return im
    return im.crop(
        (
            max(0, int(xs.min()) - 1),
            max(0, int(ys.min()) - 1),
            min(im.width, int(xs.max()) + 2),
            min(im.height, int(ys.max()) + 2),
        )
    )


def _build_slim_frame_from_wood(src: Path) -> Image.Image:
    """Exact dimetric frame using the Image Generator source as its wood finish.

    IG frames are often too thick relative to the hole; scaling them by inner size
    leaves a freestanding ring wider than the shell opening. Grain is sampled from
    the IG master; geometry is exact.
    """
    raw = Image.open(src).convert("RGBA")
    body = trim_alpha(raw if raw.getchannel("A").getextrema()[0] < 255 else chroma_key(raw))
    ba = np.asarray(body)
    mask = ba[:, :, 3] > 40
    ys, xs = np.where(mask)
    if len(xs) == 0:
        raise SystemExit(f"no wood in frame source {src}")

    # Preserve the generated moulding and wear by rebuilding it from its four
    # real frame segments. This thins the casing without flattening the Image
    # Generator finish into a synthetic average-color ring.
    source_hole = _flood_inner(ba[:, :, 3])
    iys, ixs = np.where(source_hole)
    if len(ixs):
        ix0, ix1 = int(ixs.min()), int(ixs.max()) + 1
        iy0, iy1 = int(iys.min()), int(iys.max()) + 1
        casing = max(20, int(round(EXTERIOR_LEAF_H * 0.045)))
        jamb_l, jamb_r = casing, int(round(casing * 1.2))
        header = int(round(casing * 1.1))
        thresh = max(14, int(round(casing * 0.5)))
        out_w = jamb_l + EXTERIOR_LEAF_W + jamb_r
        out_h = header + EXTERIOR_LEAF_H + thresh

        def region_wood(x0: int, y0: int, x1: int, y1: int) -> np.ndarray:
            region = ba[y0:y1, x0:x1]
            opaque = region[region[:, :, 3] > 40, :3]
            return np.median(opaque, axis=0).astype(np.uint8)

        top_wood = region_wood(0, 0, body.width, iy0 + 1)
        left_wood = region_wood(0, iy0, ix0 + 1, iy1)
        right_wood = region_wood(ix1 - 1, iy0, body.width, iy1)
        bottom_wood = region_wood(0, iy1 - 1, body.width, body.height)
        assembled = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))

        left = body.crop((0, iy0, ix0 + 1, iy1)).resize(
            (jamb_l, EXTERIOR_LEAF_H), Image.Resampling.LANCZOS
        )
        right = body.crop((ix1 - 1, iy0, body.width, iy1)).resize(
            (jamb_r, EXTERIOR_LEAF_H), Image.Resampling.LANCZOS
        )
        top = body.crop((0, 0, body.width, iy0 + 1)).resize(
            (out_w, header), Image.Resampling.LANCZOS
        )
        bottom = body.crop((0, iy1 - 1, body.width, body.height)).resize(
            (out_w, thresh), Image.Resampling.LANCZOS
        )
        assembled.alpha_composite(top, (0, 0))
        assembled.alpha_composite(left, (0, header))
        assembled.alpha_composite(right, (jamb_l + EXTERIOR_LEAF_W, header))
        assembled.alpha_composite(bottom, (0, header + EXTERIOR_LEAF_H))
        exact = np.asarray(assembled).copy()
        exact[
            header : header + EXTERIOR_LEAF_H,
            jamb_l : jamb_l + EXTERIOR_LEAF_W,
        ] = 0
        # Close only the inner stop with a narrow sampled-wood line. A full
        # opaque underlay created obvious rectangular patches wherever the
        # generated perspective silhouette tapered at an outer corner.
        stop = 3
        x0, x1 = jamb_l, jamb_l + EXTERIOR_LEAF_W
        y0, y1 = header, header + EXTERIOR_LEAF_H
        exact[y0 - stop : y0, x0:x1, :3] = top_wood
        exact[y0 - stop : y0, x0:x1, 3] = 255
        exact[y0:y1, x0 - stop : x0, :3] = left_wood
        exact[y0:y1, x0 - stop : x0, 3] = 255
        exact[y0:y1, x1 : x1 + stop, :3] = right_wood
        exact[y0:y1, x1 : x1 + stop, 3] = 255
        exact[y1 : y1 + stop, x0:x1, :3] = bottom_wood
        exact[y1 : y1 + stop, x0:x1, 3] = 255
        return Image.fromarray(exact, "RGBA")

    grain = np.zeros((ba.shape[0], 3), np.float32)
    valid = np.zeros(ba.shape[0], dtype=bool)
    # Average opaque wood across each source row. Sampling a centre column hits
    # the transparent aperture for most rows and previously propagated black
    # through the jambs.
    for y in range(ba.shape[0]):
        row = ba[y, mask[y], :3]
        if len(row):
            grain[y] = np.median(row, axis=0)
            valid[y] = True
    for y in range(1, len(grain)):
        if not valid[y]:
            grain[y] = grain[y - 1]
    for y in range(len(grain) - 2, -1, -1):
        if not valid[y]:
            grain[y] = grain[y + 1]

    # Slim detective-office casing: outer width stays near 1.20× clear width.
    casing = max(20, int(round(EXTERIOR_LEAF_H * 0.045)))
    jamb_l, jamb_r = casing, int(round(casing * 1.2))
    header = int(round(casing * 1.1))
    thresh = max(14, int(round(casing * 0.5)))
    shear = 0.12
    out_w = jamb_l + EXTERIOR_LEAF_W + jamb_r
    out_h = header + EXTERIOR_LEAF_H + thresh
    up_rgb = np.zeros((out_h, out_w, 3), np.float32)
    up_a = np.zeros((out_h, out_w), np.float32)
    gh = len(grain)

    def fill_rect(x0: int, y0: int, x1: int, y1: int, tone: float = 1.0) -> None:
        x0, x1 = max(0, x0), min(out_w, x1)
        y0, y1 = max(0, y0), min(out_h, y1)
        for y in range(y0, y1):
            sy = int(y * (gh - 1) / max(1, out_h - 1)) % gh
            source_row = ba[sy, mask[sy], :3].astype(np.float32)
            span = x1 - x0
            if len(source_row) >= 2:
                sample_at = np.linspace(0, len(source_row) - 1, span)
                base = np.column_stack(
                    [
                        np.interp(sample_at, np.arange(len(source_row)), source_row[:, c])
                        for c in range(3)
                    ]
                )
            else:
                base = np.repeat(grain[sy][None, :], span, axis=0)
            noise = ((y * 13 + np.arange(x0, x1) * 7) % 17 - 8) * 0.65
            up_rgb[y, x0:x1] = np.clip(base * tone + noise[:, None], 0, 255)
            up_a[y, x0:x1] = 255

    fill_rect(0, 0, out_w, out_h)
    hx0, hy0 = jamb_l, header
    hx1, hy1 = jamb_l + EXTERIOR_LEAF_W, header + EXTERIOR_LEAF_H
    up_a[hy0:hy1, hx0:hx1] = 0
    up_rgb[hy0:hy1, hx0:hx1] = 0
    if header > 0:
        up_rgb[:header] *= np.linspace(1.12, 0.95, header)[:, None, None]
    up_rgb[hy1:out_h] *= 0.82
    for y in range(hy0, min(hy0 + 2, hy1)):
        up_rgb[y, hx0:hx1] = (78, 58, 38)
        up_a[y, hx0:hx1] = 200
    for x, t in ((hx0 - 1, 1.1), (hx1, 0.95)):
        if 0 <= x < out_w:
            up_rgb[hy0:hy1, x] = np.clip(np.array([70.0, 52.0, 34.0]) * t, 0, 255)
            up_a[hy0:hy1, x] = 230

    pad_top = int(round(out_w * shear)) + 4
    ch, cw = out_h + pad_top + 4, out_w + 8
    out_rgb = np.zeros((ch, cw, 3), np.float32)
    out_a = np.zeros((ch, cw), np.float32)
    for x in range(out_w):
        shift = int(round((out_w - 1 - x) * shear))
        y0 = pad_top - shift
        for y in range(out_h):
            dy = y0 + y
            if 0 <= dy < ch and up_a[y, x] > 0:
                out_rgb[dy, x + 4] = up_rgb[y, x]
                out_a[dy, x + 4] = up_a[y, x]
    im = Image.fromarray(
        np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a, 0, 255)]).astype(np.uint8), "RGBA"
    )
    a = np.asarray(im)[:, :, 3]
    xs = np.where(a.max(axis=0) > 16)[0]
    ys = np.where(a.max(axis=1) > 16)[0]
    im = im.crop(
        (
            max(0, int(xs.min()) - 1),
            max(0, int(ys.min()) - 1),
            min(im.width, int(xs.max()) + 2),
            min(im.height, int(ys.max()) + 2),
        )
    )
    fa = np.asarray(im).copy()
    hole = _flood_inner(fa[:, :, 3])
    fa[hole, :] = 0
    im = Image.fromarray(fa, "RGBA")
    # Match mid-gap width to leaf
    mg = _mid_gap(np.asarray(im)[:, :, 3])
    iys, ixs = np.where(_flood_inner(np.asarray(im)[:, :, 3]))
    if mg and len(iys):
        ih = int(iys.max() - iys.min() + 1)
        sx = EXTERIOR_LEAF_W / max(1, mg)
        sy = EXTERIOR_LEAF_H / max(1, ih)
        s = (sx + sy) / 2.0
        if abs(s - 1.0) > 0.02:
            im = im.resize(
                (max(1, int(round(im.width * s))), max(1, int(round(im.height * s)))),
                Image.Resampling.LANCZOS,
            )
            fa = np.asarray(im).copy()
            fa[_flood_inner(fa[:, :, 3]), :] = 0
            fa[(fa[:, :, 3] > 0) & (fa[:, :, 3] < 40), 3] = 0
            im = Image.fromarray(fa, "RGBA")
    return im


def ship_frame() -> None:
    """Slim frame ring: inner matches leaf; one visible casing authority."""
    src = _first_existing(
        GEN / "office_door_frame_ig_v101_voss_reference_rgba.png",
        GEN / "office_door_frame_ig_v101_voss_reference_chroma.png",
        ASSETS / "office_door_frame_ig_v101_voss_reference_chroma.png",
        GEN / "office_door_frame_ig_v10_voss_reference_rgba.png",
        GEN / "office_door_frame_ig_v10_voss_reference_chroma.png",
        ASSETS / "office_door_frame_ig_v10_voss_reference_chroma.png",
        GEN / "office_door_frame_ig_v04_voss_reference_rgba.png",
        GEN / "office_door_frame_ig_v04_voss_reference_chroma.png",
        GEN / "office_door_frame_ig_v03.png",
        ASSETS / "office_door_frame_ig_v03.png",
        GEN / "office_door_frame_ig_v02.png",
        ASSETS / "office_door_frame_ig_v02.png",
    )
    GEN.mkdir(parents=True, exist_ok=True)
    if src.parent != GEN:
        shutil.copy(src, GEN / src.name)
    upright = _harden_door_matte(_build_slim_frame_from_wood(src))
    upright.save(GEN / "office_door_frame_upright_master.png")
    frame = _harden_door_matte(
        _vertical_shear(upright, rp.AXIS_NE[1] / rp.AXIS_NE[0]), thr=32
    )
    frame.save(GEN / "office_door_frame.png")
    frame.save(RUNTIME / "office_door_frame.png")
    fa = np.asarray(frame)[:, :, 3]
    mg2 = _mid_gap(fa)
    i2 = _flood_inner(fa)
    iys2, ixs2 = np.where(i2)
    inner_cx = int(round((ixs2.min() + ixs2.max()) * 0.5))
    inner_center_h = int(i2[:, inner_cx].sum())
    print(
        "frame",
        frame.size,
        f"mid_gap={mg2}",
        f"inner={ixs2.max() - ixs2.min() + 1}x{inner_center_h}",
        f"target_leaf={EXTERIOR_LEAF_W}x{EXTERIOR_LEAF_H}",
        f"outer/open≈{(frame.width * (rp.BAKED_DOORWAY_H * rp.ENVIRONMENT_SCALE / max(1, inner_center_h))) / (rp.BAKED_DOORWAY_W * rp.ENVIRONMENT_SCALE):.2f}",
    )


def ship_internal() -> None:
    src = _first_existing(
        GEN / "office_internal_door_leaf_solo_chroma_v101.png",
        ASSETS / "office_internal_door_leaf_solo_chroma_v101.png",
        GEN / "office_internal_door_leaf_solo_chroma_v10.png",
        ASSETS / "office_internal_door_leaf_solo_chroma_v10.png",
        GEN / "office_internal_door_leaf_solo_chroma_v05.png",
        GEN / "office_internal_door_leaf_solo_chroma_v04.png",
        ASSETS / "office_internal_door_leaf_ig_v05_prop.png",
        ASSETS / "office_internal_door_leaf_ig_v04_wide.png",
        ASSETS / "office_internal_door_leaf_ig_v03.png",
    )
    _copy_if_distinct(src, GEN / src.name)
    opening = json.loads((RUNTIME / "office_partition_opening.json").read_text(encoding="utf-8"))
    door_w = max(8, int(round(opening["opening_w_px"])))
    door_h = max(8, int(round(opening["opening_h_px"])))
    keyed = chroma_key(Image.open(src))
    # V10 upright elevations use uniform cover-fit. Legacy perspective sources
    # still go through the V05 rectify quad so hinge length stays correct.
    if "v10" in src.name:
        body = fit_cover(keyed, door_w, door_h)
    else:
        body = _rectify_internal_leaf(keyed, door_w, door_h)
    body = _harden_door_matte(body)
    body = _bevel_door_edges(body, hinge_right=False)
    # export_leaf flips for hinge orientation — pre-flip so lettering reads correctly.
    body = body.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    master = GEN / "office_internal_door_leaf_lettered_master.png"
    body.save(master)
    leaf = part.export_leaf(opening, master)
    leaf = _harden_door_matte(leaf, thr=32)
    leaf.save(RUNTIME / "office_internal_door_leaf.png")
    leaf.save(GEN / "office_internal_door_leaf.png")
    print(
        "internal",
        leaf.size,
        "contentH",
        opaque_content_height(leaf),
        f"opening {door_w}x{door_h} H/W={door_h / door_w:.2f}",
    )


def ship_props() -> None:
    """Ship leaf/frame props only — does not rebuild wall plates."""
    RUNTIME.mkdir(parents=True, exist_ok=True)
    ship_exterior()
    ship_frame()
    ship_internal()
    print("NOTE: agency lettering is baked into PNGs; scene must not add SKLabelNodes.")


def main(rebuild_walls: bool = False) -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    ship_exterior()
    ship_frame()
    if rebuild_walls:
        # Full architecture rebuild (rewrites partition tiling + suite bake).
        # Prefer process_office_door_aperture_v10.py to keep wall crowns locked.
        part.main()
        suite.main([])
    ship_internal()
    print("NOTE: agency lettering is baked into PNGs; scene must not add SKLabelNodes.")


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="Ship lettered office door props")
    ap.add_argument(
        "--rebuild-walls",
        action="store_true",
        help="Also rebuild partition + suite plates (rewrites wall pixels)",
    )
    args = ap.parse_args()
    if args.rebuild_walls:
        main(rebuild_walls=True)
    else:
        ship_props()
