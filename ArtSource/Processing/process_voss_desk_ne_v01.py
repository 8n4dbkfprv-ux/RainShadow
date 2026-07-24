"""Slice/chroma/register Voss NE seated desk chain into runtime atlases.

Registration matches standing/walk: V7 BGEE pixelize (80px native, 64 colors,
nearest → 200px texture) then FOOT_Y = 434 on a 512 canvas.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

import process_pre_rendered_characters_v3 as raster
from process_pre_rendered_characters_v7 import pixelize_figure_v7


ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(
    "/Users/laurensvanoorschot/.cursor/projects/"
    "Users-laurensvanoorschot-Desktop-RainShadow/assets"
)
GEN = ROOT / "ArtSource" / "Generated" / "Characters" / "Detective" / "DeskNEV1"
IDLE_ATLAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Atlases" / "VossSeatedIdle.atlas"
ARMS_ATLAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Atlases" / "VossSeatedArms.atlas"
TRANS_ATLAS = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Atlases" / "VossSeatTransitions.atlas"
OFFICE = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"

FRAME = raster.FRAME_SIZE
NATIVE_BODY_HEIGHT = 80  # V7
TEXTURE_BODY_HEIGHT = 200
FOOT_Y = raster.FOOT_Y

# Same crunch as process_pre_rendered_characters_v7 (standing/walk atlases).
raster.pixelize_figure = pixelize_figure_v7


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=50.0, soft=18.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    dist = np.linalg.norm(rgb - np.array(key, dtype=np.float32), axis=2)
    alpha = np.clip((dist - tol) / soft * 255.0, 0, 255)
    g, r, b = rgb[:, :, 1], rgb[:, :, 0], rgb[:, :, 2]
    greenish = (g > r + 18) & (g > b + 18) & (g > 40)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    green_dom = (g == mx) & ((g - mn) > 20) & (g > 35)
    alpha = np.where(greenish | green_dom, 0, alpha)
    spill = np.clip(1.0 - dist / (tol + soft + 40.0), 0, 1)
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * (1.0 - spill[..., None] * 0.85) + lum * (spill[..., None] * 0.85)
    rgb = np.where(alpha[..., None] < 8, 0, rgb)
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def trim_alpha(im: Image.Image, threshold: int = 30, pad: int = 2) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return im
    return im.crop(
        (
            max(0, int(xs.min()) - pad),
            max(0, int(ys.min()) - pad),
            min(im.width, int(xs.max()) + 1 + pad),
            min(im.height, int(ys.max()) + 1 + pad),
        )
    )


def slice_strip(path: Path, expected_min: int = 4) -> list[Image.Image]:
    sheet = chroma_key(Image.open(path))
    arr = np.array(sheet)
    a = arr[:, :, 3]
    # Column occupancy
    col = (a > 40).any(axis=0)
    cells: list[Image.Image] = []
    in_run = False
    start = 0
    for x, occ in enumerate(col):
        if occ and not in_run:
            in_run = True
            start = x
        elif not occ and in_run:
            in_run = False
            cell = trim_alpha(Image.fromarray(arr[:, start:x], "RGBA"))
            if cell.width * cell.height > 400:
                cells.append(cell)
    if in_run:
        cell = trim_alpha(Image.fromarray(arr[:, start:], "RGBA"))
        if cell.width * cell.height > 400:
            cells.append(cell)
    if len(cells) < expected_min:
        # Equal-width fallback
        n = max(expected_min, 4)
        w = sheet.width // n
        cells = [trim_alpha(chroma_key(sheet.crop((i * w, 0, (i + 1) * w, sheet.height)))) for i in range(n)]
    return cells


def head_width(im: Image.Image, threshold: int = 40) -> int:
    """Opaque width of the top ~12% of the silhouette (fedora band)."""
    a = np.asarray(im.convert("RGBA"))
    mask = a[:, :, 3] > threshold
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return 1
    y0, y1 = int(ys.min()), int(ys.max())
    band_h = max(1, int((y1 - y0 + 1) * 0.12))
    cols = np.where(mask[y0 : y0 + band_h].any(axis=0))[0]
    if len(cols) == 0:
        return 1
    return int(cols.max() - cols.min() + 1)


def pixelize_shared(figure: Image.Image, reference_height: int) -> Image.Image:
    """V7 crunch with a fixed source→native scale (no per-frame height normalize).

    `reference_height` source pixels map to NATIVE_BODY_HEIGHT, then nearest-up
    to texture. Crouched frames stay shorter on the canvas; head size stays
    locked to the standing-end reference so sit/stand-up do not look oversized.
    """
    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[pixels[..., 3] < 16] = 0
    figure = Image.fromarray(pixels, "RGBA")
    bbox = figure.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Figure has no opaque subject")
    figure = figure.crop(bbox)

    ref_h = max(1, reference_height)
    native_h = max(1, round(figure.height * NATIVE_BODY_HEIGHT / ref_h))
    native_w = max(1, round(figure.width * NATIVE_BODY_HEIGHT / ref_h))
    native = raster.premultiplied_resize(figure, (native_w, native_h))
    alpha = native.getchannel("A")

    opaque = np.asarray(native)
    opaque_rgb = opaque[opaque[..., 3] > 0][:, :3]
    if len(opaque_rgb) == 0:
        raise RuntimeError("Figure has no opaque pixels after resize")
    palette_source = Image.fromarray(opaque_rgb.reshape((1, -1, 3)), "RGB")
    palette = palette_source.quantize(
        colors=64,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    limited_rgb = (
        native.convert("RGB")
        .quantize(palette=palette, dither=Image.Dither.NONE)
        .convert("RGB")
    )
    native = Image.merge("RGBA", (*limited_rgb.split(), alpha))
    texture_h = max(1, round(native_h * TEXTURE_BODY_HEIGHT / NATIVE_BODY_HEIGHT))
    texture_w = max(1, round(native_w * TEXTURE_BODY_HEIGHT / NATIVE_BODY_HEIGHT))
    return native.resize((texture_w, texture_h), Image.Resampling.NEAREST)


def lock_atlas_canvas(canvas: Image.Image) -> Image.Image:
    """Stamp near-invisible corner sentinels so Xcode .atlas trim keeps 512×512.

    SpriteKit packs trim transparent edges. With SKAction.animate(resize: false)
    into a fixed 256 node, trimmed sit frames stretch differently every frame.
    Alpha-1 corners preserve the authored canvas without a visible speck.
    """
    for x, y in ((0, 0), (FRAME - 1, 0), (0, FRAME - 1), (FRAME - 1, FRAME - 1)):
        canvas.putpixel((x, y), (0, 0, 0, 1))
    return canvas


def register_shared(im: Image.Image, reference_height: int) -> Image.Image:
    """Shared-scale V7 pixelize; feet on FOOT_Y (same pivot as standing/walk)."""
    pix = pixelize_shared(trim_alpha(im), reference_height)
    # Never exceed the standing texture body — mid sit frames were ~208px and
    # read as a brief inflate before the crouch.
    if pix.height > TEXTURE_BODY_HEIGHT:
        new_w = max(1, round(pix.width * TEXTURE_BODY_HEIGHT / pix.height))
        pix = pix.resize((new_w, TEXTURE_BODY_HEIGHT), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - pix.width) // 2
    y = FOOT_Y - pix.height
    canvas.alpha_composite(pix, (x, max(0, min(FRAME - pix.height, y))))
    return lock_atlas_canvas(canvas)


def lock_cycle_scale(cell: Image.Image, ref: Image.Image) -> Image.Image:
    """Rescale a foot-registered cell so its opaque bbox matches `ref`.

    Seated breath sources are nearly the same size, but nearest crunch rounds
    each cell differently (e.g. 148→145px / hat 70→65). On a fixed SpriteKit
    node that reads as the detective pulsing larger and smaller every frame.
    Uniform height lock plus a final width match keep pose deltas without a
    visible scale pulse (width match is a ≤4% anisotropic nudge).
    """
    ref_bbox = opaque_bbox(ref)
    ref_w = ref_bbox[2] - ref_bbox[0] + 1
    ref_h = ref_bbox[3] - ref_bbox[1] + 1
    if ref_h <= 1 or ref_w <= 1:
        return cell

    bbox = opaque_bbox(cell)
    x0, y0, x1, y1 = bbox
    crop = cell.crop((x0, y0, x1 + 1, y1 + 1))
    if crop.height <= 1 or crop.width <= 1:
        return cell

    # Pass 1: uniform scale to reference height.
    scale = ref_h / crop.height
    nw = max(1, round(crop.width * scale))
    nh = max(1, round(crop.height * scale))
    if (nw, nh) != crop.size:
        crop = crop.resize((nw, nh), Image.Resampling.NEAREST)

    # Pass 2: match reference width (small anisotropic fix for NN rounding).
    if crop.width != ref_w:
        crop = crop.resize((ref_w, crop.height), Image.Resampling.NEAREST)

    out = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = (FRAME - crop.width) // 2
    y = FOOT_Y - crop.height
    out.alpha_composite(crop, (x, max(0, min(FRAME - crop.height, y))))
    return lock_atlas_canvas(out)


def register(im: Image.Image) -> Image.Image:
    """Legacy per-frame normalize — prefer register_shared for desk strips."""
    return lock_atlas_canvas(raster.register(trim_alpha(im)))


def expand_to(frames: list[Image.Image], count: int) -> list[Image.Image]:
    """Stretch a short strip to `count` frames without restarting the motion.

    Looping from frame 0 (the old pad) made stand-up play twice: an 8-cell
    rise became frames 0..7 then 0..3 again. Temporal remapping keeps a single
    seated→standing progression across the full clip length.
    """
    if not frames:
        return frames
    if len(frames) >= count:
        return frames[:count]
    if len(frames) == 1:
        return [frames[0]] * count
    out: list[Image.Image] = []
    last = len(frames) - 1
    for i in range(count):
        t = i / (count - 1) * last
        out.append(frames[int(round(t))])
    return out


def harden_silhouette_alpha(cell: Image.Image, threshold: int = 96) -> Image.Image:
    """Binary alpha for under-desk layers — kills soft fringes on the floor.

    Soft mid-alphas at chair feet read as a fuzzy haze where the lower layer
    meets the floorboards past the apron.
    """
    arr = np.array(cell.convert("RGBA"))
    a = arr[:, :, 3]
    hard = a >= threshold
    arr[:, :, 3] = np.where(hard, 255, 0).astype(np.uint8)
    arr[~hard, :3] = 0
    return Image.fromarray(arr, "RGBA")


def split_upper_lower(cell: Image.Image, lap_frac: float = 0.78) -> tuple[Image.Image, Image.Image]:
    """Split a registered seated cell on a horizontal feet seam.

    Upper = torso/fedora/arms + chair back (must stay camera-near / in front of
    the desk). Lower = only the under-desk feet / front chair legs that the
    kneehole apron should hide. Seam stays ~0.78 so desk-reaching hands remain
    on the upper layer (a lower seam buried the hands behind the apron).
    Both keep the same 512 feet registration.
    """
    arr = np.array(cell.convert("RGBA"))
    a = arr[:, :, 3]
    ys = np.where(a > 40)[0]
    if len(ys) == 0:
        empty = lock_atlas_canvas(Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0)))
        return empty.copy(), empty.copy()
    y0, y1 = int(ys.min()), int(ys.max())
    # Low seam: keep chair back with the upper layer for rear-view.
    seam = y0 + int((y1 - y0) * lap_frac)
    upper = arr.copy()
    upper[seam:, :, 3] = 0
    lower = arr.copy()
    lower[:seam, :, 3] = 0
    # Harden feet/chair-leg alpha so soft fringes do not haze the floor.
    lower_im = harden_silhouette_alpha(Image.fromarray(lower, "RGBA"))
    return (
        lock_atlas_canvas(Image.fromarray(upper, "RGBA")),
        lock_atlas_canvas(lower_im),
    )


def split_hands_from_upper(
    upper: Image.Image, hand_frac: float = 0.32
) -> tuple[Image.Image, Image.Image]:
    """Peel desk-reaching hands off the upper cell into a foreground arms layer.

    Rear-view upper includes coat + hands at similar heights. Without a separate
    hands layer the whole upper draws above the desk top and reads as sitting
    *on* the wood. Hands stay above `office_desk_top_occluder`; torso stays below.
    """
    arr = np.array(upper.convert("RGBA"))
    a = arr[:, :, 3]
    ys = np.where(a > 40)[0]
    if len(ys) == 0:
        empty = lock_atlas_canvas(Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0)))
        return upper, empty
    y0, y1 = int(ys.min()), int(ys.max())
    hand_cut = y1 - max(1, int((y1 - y0) * hand_frac))
    hands = arr.copy()
    hands[:hand_cut, :, 3] = 0
    torso = arr.copy()
    torso[hand_cut:, :, 3] = 0
    return (
        lock_atlas_canvas(Image.fromarray(torso, "RGBA")),
        lock_atlas_canvas(Image.fromarray(hands, "RGBA")),
    )


def build_desk_top_occluder(bare_path: Path, front_path: Path, out_path: Path) -> None:
    """Non-apron desk surface: hides coat that would paint on top/pedestal wood.

    Everything in the bare desk that is not the camera-facing apron. Apron stays
    a separate layer so the sandwich is: legs < apron < torso < desk-top.
    A short band above the apron lip left coat on the near pedestal.
    """
    bare = np.array(Image.open(bare_path).convert("RGBA"))
    front = np.array(Image.open(front_path).convert("RGBA"))
    bare_a = bare[:, :, 3] > 40
    front_a = front[:, :, 3] > 40
    top_mask = bare_a & ~front_a
    out = bare.copy()
    out[:, :, 3] = np.where(top_mask, bare[:, :, 3], 0)
    Image.fromarray(out, "RGBA").save(out_path)
    print("desk top occluder opaque%", float(top_mask.mean()))


def opaque_bbox(im: Image.Image, threshold: int = 40) -> tuple[int, int, int, int]:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def register_arms(im: Image.Image, idle_ref: Image.Image) -> Image.Image:
    """Register an arms-only cell as a small hands-band overlay.

    Contract from the original SE pair (idle body bbox 98w x 200h at 234..433;
    arms bbox 80w x 76h at 276..351): arms width ~0.82 of body width, bottom of
    the arms ~58.5% down the body, centered slightly left of the body center.
    """
    bx0, by0, bx1, by1 = opaque_bbox(idle_ref)
    body_w = bx1 - bx0 + 1
    body_h = by1 - by0 + 1
    body_cx = (bx0 + bx1) / 2

    im = trim_alpha(im)
    scale = (body_w * 0.82) / im.width
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)

    out = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    x = int(round(body_cx - 4 - nw / 2))
    y = int(round(by0 + body_h * 0.585 - nh))
    out.alpha_composite(resized, (max(0, x), max(0, y)))
    return out


def build_actor_occluder(bare_path: Path, seated_path: Path, out_path: Path) -> None:
    bare = np.array(Image.open(bare_path).convert("RGBA"))
    seated = Image.open(seated_path).convert("RGBA")
    # Place seated in the SW knee well (slightly left of desk center, low).
    canvas = Image.new("RGBA", (bare.shape[1], bare.shape[0]), (0, 0, 0, 0))
    target_h = int(bare.shape[0] * 0.50)
    scale = target_h / seated.height
    sw = max(1, int(seated.width * scale))
    sh = max(1, int(seated.height * scale))
    seated_r = seated.resize((sw, sh), Image.Resampling.LANCZOS)
    x = bare.shape[1] // 2 - sw // 2 - int(bare.shape[1] * 0.04)
    y = bare.shape[0] - sh - int(bare.shape[0] * 0.04)
    canvas.alpha_composite(seated_r, (max(0, x), max(0, y)))
    seated_a = np.array(canvas)[:, :, 3] > 40
    bare_a = bare[:, :, 3] > 40
    yy = np.arange(bare.shape[0])[:, None]
    # Tight lap band only (lower ~30% of seated silhouette) so the pedestal
    # cannot paint over the rear-view torso/fedora when this layer is in front.
    seated_ys = np.where(seated_a.any(axis=1))[0]
    if len(seated_ys) == 0:
        mask = bare_a & (yy > bare.shape[0] * 0.70)
    else:
        s0, s1 = int(seated_ys.min()), int(seated_ys.max())
        lap_cut = s0 + int((s1 - s0) * 0.70)
        lap = seated_a & (yy >= lap_cut)
        mask = bare_a & lap
    if mask.mean() < 0.005:
        mask = bare_a & (yy > bare.shape[0] * 0.72)
    out = bare.copy()
    out[:, :, 3] = np.where(mask, bare[:, :, 3], 0)
    Image.fromarray(out, "RGBA").save(out_path)
    print("actor occluder opaque%", float(mask.mean()))


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    IDLE_ATLAS.mkdir(parents=True, exist_ok=True)
    ARMS_ATLAS.mkdir(parents=True, exist_ok=True)
    TRANS_ATLAS.mkdir(parents=True, exist_ok=True)

    # V3 rear-view strips: same NE rear pose as V2, olive-brown V6 coat lock
    # (V2 drifted charcoal). Hands stay on the body sprite.
    idle_src = ASSETS / "voss_seated_idle_ne_rear_strip_v03.png"
    stand_src = ASSETS / "voss_stand_up_ne_rear_strip_v03.png"
    for src in (idle_src, stand_src):
        if src.exists():
            shutil.copy(src, GEN / src.name)

    # Expand source cells first, then register with one shared scale so crouched
    # frames are not zoomed to full body height (that made sit/stand look huge).
    stand_src_cells = expand_to(slice_strip(stand_src, 8), 12)
    # Standing-end frame maps to the full 200px texture body (matches walk/idle).
    stand_ref = stand_src_cells[-1]
    stand_ref_h = stand_ref.height
    stand_ref_head = head_width(stand_ref)

    idle_src_cells = expand_to(slice_strip(idle_src, 4), 8)
    # Idle strip was authored larger than stand-up; pick reference height so its
    # fedora width matches the stand-up standing-end after shared scale.
    idle_head = head_width(idle_src_cells[0])
    idle_ref_h = max(1, round(idle_head * stand_ref_h / max(1, stand_ref_head)))

    idle_cells = [register_shared(c, idle_ref_h) for c in idle_src_cells]
    # Nearest crunch drifts seated breath cells by a few pixels; lock every
    # frame to cell 0 so idle no longer reads as a size pulse at the desk.
    idle_ref = idle_cells[0]
    idle_cells = [lock_cycle_scale(c, idle_ref) for c in idle_cells]
    for i, cell in enumerate(idle_cells):
        cell.save(GEN / f"voss_seated_idle_ne_{i:02d}.png")
        cell.save(IDLE_ATLAS / f"voss_seated_idle_ne_{i:02d}.png")
        # Keep SE names as aliases for any leftover references during transition.
        cell.save(IDLE_ATLAS / f"voss_seated_idle_se_{i:02d}.png")
        upper, lower = split_upper_lower(cell)
        upper.save(GEN / f"voss_seated_upper_ne_{i:02d}.png")
        lower.save(GEN / f"voss_seated_lower_ne_{i:02d}.png")
        upper.save(IDLE_ATLAS / f"voss_seated_upper_ne_{i:02d}.png")
        lower.save(IDLE_ATLAS / f"voss_seated_lower_ne_{i:02d}.png")

    # Rear-view hands sit inside the upper cell. Keep the arms overlay empty —
    # peeling a mid-band just put coat on top of the desk-top occluder.
    empty = lock_atlas_canvas(Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0)))
    for i in range(8):
        empty.save(GEN / f"voss_seated_arms_ne_{i:02d}.png")
        empty.save(ARMS_ATLAS / f"voss_seated_arms_ne_{i:02d}.png")
        empty.save(ARMS_ATLAS / f"voss_seated_arms_se_{i:02d}.png")

    stand_cells = [register_shared(c, stand_ref_h) for c in stand_src_cells]
    sit_cells = list(reversed(stand_cells))
    for i, cell in enumerate(stand_cells):
        cell.save(TRANS_ATLAS / f"voss_stand_up_ne_{i:02d}.png")
        cell.save(TRANS_ATLAS / f"voss_stand_up_se_{i:02d}.png")
    for i, cell in enumerate(sit_cells):
        cell.save(TRANS_ATLAS / f"voss_sit_down_ne_{i:02d}.png")
        cell.save(TRANS_ATLAS / f"voss_sit_down_se_{i:02d}.png")

    build_actor_occluder(
        OFFICE / "office_desk_bare.png",
        IDLE_ATLAS / "voss_seated_idle_ne_00.png",
        OFFICE / "office_desk_actor_occluder.png",
    )
    build_desk_top_occluder(
        OFFICE / "office_desk_bare.png",
        OFFICE / "office_desk_front_occluder_v04.png",
        OFFICE / "office_desk_top_occluder.png",
    )
    print(
        "idle",
        len(idle_cells),
        "stand",
        len(stand_cells),
        f"stand_ref_h={stand_ref_h}",
        f"idle_ref_h={idle_ref_h}",
    )

if __name__ == "__main__":
    main()
