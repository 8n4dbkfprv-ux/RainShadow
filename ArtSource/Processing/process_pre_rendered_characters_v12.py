#!/usr/bin/env python3
"""V12 paperdoll-locked Voss atlas install with V7 BGEE crunch.

Harlan Voss only: PreRendered3DV12 masters re-locked to inventory paperdoll V11
identity and SE key V12 craft (bare-headed; clean coat hem; no over-detail).
LilaArrival.atlas is left untouched. Inventory paperdoll is not reprocessed.

Reuses V6 slicing/mirroring/registration and V7 pixelization (80px / 64 colors /
nearest → 200px). Portrait installs via Lanczos when a master is present.
"""

from __future__ import annotations

from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFilter

import process_pre_rendered_characters_v3 as raster
import process_pre_rendered_characters_v6 as v6
from process_pre_rendered_characters_v7 import pixelize_figure_v7
from process_character_gait_v5 import remove_green_screen


def soften_for_paperdoll_craft(figure: Image.Image, radius: float = 3.4) -> Image.Image:
    """Drop micro-detail/contrast so V7 crunch matches seated/paperdoll craft density."""
    import numpy as np

    rgba = figure.convert("RGBA")
    rgb = Image.merge("RGB", rgba.split()[:3]).filter(ImageFilter.GaussianBlur(radius=radius))
    # Stronger midtone pull — V13 IG masters still carry more micro-contrast than seated.
    arr = np.asarray(rgb).astype(np.float32)
    mean = arr.mean(axis=(0, 1), keepdims=True)
    arr = mean + (arr - mean) * 0.68
    rgb = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    alpha = rgba.split()[-1]
    return Image.merge("RGBA", (*rgb.split(), alpha))


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12"
PORTRAIT_SOURCE = ROOT / "ArtSource/Generated/UI/Dialogue"
DIALOGUE_UI = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV12Prior"
PAPERDOLL = (
    ROOT / "ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png"
)
SEATED_COLOR_FALLBACK = (
    ATLASES / "VossSeatedIdle.atlas" / "voss_seated_idle_ne_00.png"
)

# Cached play-scale face/coat targets (seated NE00 preferred; paperdoll fallback).
_WARDROBE_TARGET: dict[str, list[float]] | None = None


def _is_chroma_green(rgb: "np.ndarray") -> "np.ndarray":
    import numpy as np

    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (g > 140) & (g > r + 40) & (g > b + 40)


def _opaque_body_box(alpha_mask: "np.ndarray") -> tuple[int, int, int, int] | None:
    import numpy as np

    ys, xs = np.where(alpha_mask)
    if len(xs) == 0:
        return None
    return int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())


def _coat_mask(rgb: "np.ndarray", alpha_mask: "np.ndarray") -> "np.ndarray":
    """Opaque brown wardrobe (coat/vest), including darker folds."""
    import numpy as np

    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (r + g + b) / 3.0
    # Broader than the first lock so shaded coat folds still grade with the body.
    return (
        alpha_mask
        & (r > b + 4)
        & (r > 28)
        & (r < 210)
        & (lum > 22)
        & (lum < 175)
        & (g < r + 8)
        & ((r - g) > -2)
    )


def _skin_mask(rgb: "np.ndarray", alpha_mask: "np.ndarray") -> "np.ndarray":
    """Face/hand skin: warm mid-high luminance, not coat brown."""
    import numpy as np

    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (r + g + b) / 3.0
    return (
        alpha_mask
        & (r > g)
        & (g > b)
        & (r > 70)
        & (lum > 55)
        & (lum < 210)
        & ((r - b) > 18)
        & ((r - b) < 110)
        & ((r - g) < 55)
        # Coat is darker and more R-led; keep high-sat dark brown out of skin.
        & ~((lum < 95) & ((r - b) > 40) & (r < 130))
    )


def _face_roi_mask(alpha_mask: "np.ndarray") -> "np.ndarray":
    """Upper silhouette band where the head/face lives on foot-registered cells."""
    import numpy as np

    box = _opaque_body_box(alpha_mask)
    out = np.zeros_like(alpha_mask, dtype=bool)
    if box is None:
        return out
    y0, y1, x0, x1 = box
    h = max(1, y1 - y0 + 1)
    w = max(1, x1 - x0 + 1)
    # Top ~28% of body height, centre 70% of width.
    fy0 = y0
    fy1 = y0 + max(2, int(h * 0.30))
    fx0 = x0 + int(w * 0.15)
    fx1 = x0 + max(fx0 + 1, int(w * 0.85))
    out[fy0:fy1, fx0:fx1] = alpha_mask[fy0:fy1, fx0:fx1]
    return out


def _coat_roi_mask(alpha_mask: "np.ndarray") -> "np.ndarray":
    """Torso band used for play-scale coat measurement (excludes head/feet)."""
    import numpy as np

    box = _opaque_body_box(alpha_mask)
    out = np.zeros_like(alpha_mask, dtype=bool)
    if box is None:
        return out
    y0, y1, x0, x1 = box
    h = max(1, y1 - y0 + 1)
    w = max(1, x1 - x0 + 1)
    cy0 = y0 + int(h * 0.28)
    cy1 = y0 + max(cy0 + 1, int(h * 0.72))
    cx0 = x0 + int(w * 0.12)
    cx1 = x0 + max(cx0 + 1, int(w * 0.88))
    out[cy0:cy1, cx0:cx1] = alpha_mask[cy0:cy1, cx0:cx1]
    return out


def _match_region(
    r: "np.ndarray",
    g: "np.ndarray",
    b: "np.ndarray",
    region: "np.ndarray",
    target: "np.ndarray",
    *,
    scale_lo: float,
    scale_hi: float,
    chroma_boost: float = 1.0,
) -> tuple["np.ndarray", "np.ndarray", "np.ndarray"]:
    """Mean-match + optional chroma expand a pixel region toward target RGB."""
    import numpy as np

    if int(region.sum()) < 12:
        return r, g, b
    stacked = np.stack([r, g, b], axis=-1)
    cur = stacked[region].mean(axis=0)
    scale = np.clip(target / (cur + 1e-5), scale_lo, scale_hi)
    rr = np.where(region, np.clip(r * scale[0], 0, 255), r)
    gg = np.where(region, np.clip(g * scale[1], 0, 255), g)
    bb = np.where(region, np.clip(b * scale[2], 0, 255), b)
    if chroma_boost != 1.0 and int(region.sum()) >= 12:
        stacked2 = np.stack([rr, gg, bb], axis=-1)
        mean = stacked2[region].mean(axis=0)
        # Expand away from the local mean so muddy walk coats regain seated punch.
        for channel, arr in enumerate((rr, gg, bb)):
            delta = stacked2[..., channel] - mean[channel]
            boosted = mean[channel] + delta * chroma_boost
            arr_new = np.where(region, np.clip(boosted, 0, 255), arr)
            if channel == 0:
                rr = arr_new
            elif channel == 1:
                gg = arr_new
            else:
                bb = arr_new
    return rr, gg, bb


def play_scale_wardrobe_stats() -> dict[str, "np.ndarray"]:
    """Frozen face + coat targets from the accepted seated NE desk pose.

    Live atlas sampling is intentionally disabled: a single bad reinstall used
    to poison every other clip. Values measured from the committed seated NE00
    that reads correct at the desk in-game.
    """
    import numpy as np

    global _WARDROBE_TARGET
    if _WARDROBE_TARGET is not None:
        return {
            key: np.asarray(val, dtype=np.float32)
            for key, val in _WARDROBE_TARGET.items()
        }

    face_tgt = np.array([140.6, 98.8, 56.0], dtype=np.float32)
    coat_tgt = np.array([98.3, 66.7, 35.6], dtype=np.float32)
    _WARDROBE_TARGET = {
        "face": [float(x) for x in face_tgt],
        "coat": [float(x) for x in coat_tgt],
    }
    return {"face": face_tgt, "coat": coat_tgt}


def paperdoll_wardrobe_stats() -> dict[str, "np.ndarray"]:
    """Compat: expose coat/mid keys used by older helpers."""
    stats = play_scale_wardrobe_stats()
    return {"coat": stats["coat"], "mid": stats["coat"], "face": stats["face"]}


def paperdoll_wardrobe_target() -> "np.ndarray":
    """Mean RGB of the play-scale coat (compat helper for tests/QA)."""
    return play_scale_wardrobe_stats()["coat"]


def identity_wardrobe_lock(figure: Image.Image) -> Image.Image:
    """Match face + coat to the seated play-scale grade on every Voss cell.

    Idle/walk masters still painted darker faces and muddier coats than the desk
    seated pose. Mean-match the face ROI and coat ROI separately toward seated
    NE00 (paperdoll fallback), then chroma-boost the coat so standing no longer
    reads washed next to the chair.

    Always re-stamps atlas corner sentinels afterward.
    """
    import numpy as np

    import process_voss_desk_ne_v01 as ne

    px = np.asarray(figure.convert("RGBA")).copy()
    rgb = px[..., :3].astype(np.float32)
    a = px[..., 3].astype(np.float32)
    mask = a > 40
    if not mask.any():
        return ne.lock_atlas_canvas(figure.convert("RGBA"))

    targets = play_scale_wardrobe_stats()
    face_tgt = targets["face"]
    coat_tgt = targets["coat"]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]

    # Kill olive/green spill before grading.
    other = np.maximum(r, b)
    spill = mask & ((g - other) > 4)
    g = np.where(spill, np.minimum(g, other + 1), g)

    # Geometric ROIs (not color masks) so dark walk masters still get lifted.
    # Exclude near-black shadow only.
    lum = (r + g + b) / 3.0
    lit = mask & (lum > 18)

    face_m = _face_roi_mask(mask) & lit
    coat_m = _coat_roi_mask(mask) & lit & ~face_m

    # Face first so later coat passes cannot darken the head.
    r, g, b = _match_region(
        r, g, b, face_m, face_tgt, scale_lo=0.90, scale_hi=1.75, chroma_boost=1.12
    )
    r, g, b = _match_region(
        r, g, b, coat_m, coat_tgt, scale_lo=0.80, scale_hi=1.85, chroma_boost=1.28
    )

    # Remaining cloth: lower body / coat hem outside the torso ROI.
    stacked = np.stack([r, g, b], axis=-1)
    lum = stacked.mean(axis=-1)
    rest = mask & ~face_m & ~coat_m & (lum > 18) & (lum < 170) & (r > b + 2)
    if int(rest.sum()) >= 20:
        r, g, b = _match_region(
            r, g, b, rest, coat_tgt, scale_lo=0.85, scale_hi=1.65, chroma_boost=1.15
        )

    # Warm coat bias: keep R ahead of G on coat pixels.
    coat_m = _coat_mask(np.stack([r, g, b], axis=-1), mask)
    g = np.where(coat_m & (g > r - 8), r - 12, g)
    b = np.where(coat_m, np.minimum(255.0, b + 2.0), b)

    still = mask & (g > r + 5) & (g > b + 5)
    a[still] = 0
    out = np.stack([r, g, b, a], axis=-1)
    out[out[..., 3] < 8] = 0
    locked = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    return ne.lock_atlas_canvas(locked)


def warm_brown_lock(figure: Image.Image) -> Image.Image:
    """Backward-compatible alias — wardrobe authority is now the paperdoll."""
    return identity_wardrobe_lock(figure)

VOSS_ATLASES = (
    "VossWalk.atlas",
    "VossIdle.atlas",
    "VossSeatedIdle.atlas",
    "VossSeatedArms.atlas",
    "VossSeatTransitions.atlas",
)


def keyed(source_dir: Path, stem: str) -> Path:
    chroma = source_dir / f"{stem}_chroma_v12.png"
    rgba = source_dir / f"{stem}_rgba_v12.png"
    remove_green_screen(chroma, rgba)
    return rgba


def install_locked_frame_v12(
    frame: Image.Image,
    atlas_name: str,
    filename: str,
    source_dir: Path,
) -> None:
    """Install a frame after all color/alpha processing and geometry validation."""
    registered_dir = source_dir / "Registered_v12"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def save_frame_v12(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    # identity_wardrobe_lock ends with lock_atlas_canvas so trim cannot shrink cells.
    install_locked_frame_v12(identity_wardrobe_lock(frame), atlas_name, filename, source_dir)


def load_required_chroma_frames(source_dir: Path, stem: str, count: int) -> list[Image.Image]:
    """Key an authoritative per-frame V12 sequence; strips are preview-only."""
    figures: list[Image.Image] = []
    missing: list[Path] = []
    for index in range(count):
        chroma = source_dir / f"{stem}_{index:02d}_chroma_v12.png"
        if not chroma.exists():
            missing.append(chroma)
            continue
        temporary = source_dir / f".{stem}_{index:02d}_keyed_tmp.png"
        remove_green_screen(chroma, temporary)
        with Image.open(temporary) as keyed_frame:
            figures.append(keyed_frame.convert("RGBA").copy())
        temporary.unlink(missing_ok=True)
    if missing:
        names = ", ".join(path.name for path in missing)
        raise FileNotFoundError(f"Missing required V12 chroma masters: {names}")
    if len(figures) != count:
        raise RuntimeError(f"Expected {count} keyed {stem} frames, got {len(figures)}")
    return figures


def backup_prior_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in VOSS_ATLASES:
        source = ATLASES / atlas_name
        if not source.exists():
            continue
        destination = BACKUP / atlas_name
        destination.mkdir()
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)
    ui = BACKUP / "UI"
    ui.mkdir(exist_ok=True)
    for rel in (
        "RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_portrait_harlan_voss_v01.png",
        "RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png",
    ):
        path = ROOT / rel
        if path.exists():
            shutil.copy2(path, ui / path.name)


def crop_strip_cells(rgba_path: Path, columns: int) -> list[Image.Image]:
    """Equal-width strip cells; keep the largest opaque component per cell.

    Image-Generator strips sometimes leave tiny chroma crumbs that make
    connected-component slicing over-count. Grid cells match compose layout.
    """
    import numpy as np
    from scipy import ndimage

    sheet = Image.open(rgba_path).convert("RGBA")
    cell_w = sheet.width // columns
    figures: list[Image.Image] = []
    for index in range(columns):
        left = index * cell_w
        right = sheet.width if index == columns - 1 else (index + 1) * cell_w
        cell = sheet.crop((left, 0, right, sheet.height))
        alpha = np.asarray(cell)[..., 3]
        labels, count = ndimage.label(alpha >= 16, structure=np.ones((3, 3), dtype=np.uint8))
        if count == 0:
            raise RuntimeError(f"No figure in cell {index} of {rgba_path.name}")
        areas = ndimage.sum(labels > 0, labels, range(1, count + 1))
        best = int(np.argmax(areas)) + 1
        mask = labels == best
        pixels = np.asarray(cell).copy()
        pixels[~mask] = 0
        figure = Image.fromarray(pixels, "RGBA")
        bbox = figure.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"Empty figure in cell {index} of {rgba_path.name}")
        figures.append(figure.crop(bbox))
    return figures


def process_voss_locomotion() -> None:
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_walk_{direction}_cycle")
        for phase, figure in enumerate(crop_strip_cells(rgba, 8)):
            save_frame_v12(
                raster.register(soften_for_paperdoll_craft(figure)),
                "VossWalk.atlas",
                f"voss_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    southwest_idle: list[Image.Image] = []
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_idle_{direction}_strip")
        for phase, figure in enumerate(crop_strip_cells(rgba, 4)):
            frame = raster.register(soften_for_paperdoll_craft(figure))
            if direction == "sw":
                southwest_idle.append(frame)
            save_frame_v12(
                frame,
                "VossIdle.atlas",
                f"voss_standing_idle_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    for phase, frame in enumerate(southwest_idle):
        save_frame_v12(
            v6.flipped(frame),
            "VossIdle.atlas",
            f"voss_standing_idle_se_{phase:02d}.png",
            DETECTIVE_SOURCE,
        )


def process_voss_desk_chain_se() -> None:
    """SE desk chain only — NE cells are installed by process_voss_desk_ne_v12.

    All 20 chairless cells use one source-to-texture scale derived from the
    direction-matched standing endpoint. Invalid geometry fails validation.
    """
    import process_voss_desk_ne_v01 as ne

    frame_source = DETECTIVE_SOURCE / "Frames"
    idle_figures = [
        ne.trim_alpha(v6.flipped(figure))
        for figure in load_required_chroma_frames(frame_source, "voss_seated_idle", 8)
    ]
    stand_figures = [
        ne.trim_alpha(v6.flipped(figure))
        for figure in load_required_chroma_frames(frame_source, "voss_stand_up", 12)
    ]
    ne.validate_source_camera_scale("SE V12 chairless source", idle_figures + stand_figures)
    stand_ref_h = ne.source_opaque_height(stand_figures[-1])
    idle_cells = [
        identity_wardrobe_lock(
            ne.register_shared(soften_for_paperdoll_craft(figure), stand_ref_h)
        )
        for figure in idle_figures
    ]
    stand_cells = [
        identity_wardrobe_lock(
            ne.register_shared(soften_for_paperdoll_craft(figure), stand_ref_h)
        )
        for figure in stand_figures
    ]
    standing_reference = Image.open(
        ATLASES / "VossIdle.atlas/voss_standing_idle_se_00.png"
    ).convert("RGBA")
    ne.validate_shared_scale_chain(
        "SE V12", idle_cells, stand_cells, standing_reference
    )
    sit_cells = list(reversed(stand_cells))

    for index, frame in enumerate(idle_cells):
        install_locked_frame_v12(
            frame,
            "VossSeatedIdle.atlas",
            f"voss_seated_idle_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    # The full seated body includes Voss's arms. Keep the legacy layer present
    # but transparent so it can never double-render; the world prop owns chair art.
    empty = ne.lock_atlas_canvas(Image.new("RGBA", (ne.FRAME, ne.FRAME), (0, 0, 0, 0)))
    for index in range(8):
        install_locked_frame_v12(
            empty,
            "VossSeatedArms.atlas",
            f"voss_seated_arms_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )

    for index, frame in enumerate(stand_cells):
        install_locked_frame_v12(
            frame,
            "VossSeatTransitions.atlas",
            f"voss_stand_up_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )
    for index, frame in enumerate(sit_cells):
        install_locked_frame_v12(
            frame,
            "VossSeatTransitions.atlas",
            f"voss_sit_down_se_{index:02d}.png",
            DETECTIVE_SOURCE,
        )


def install_portrait_from_paperdoll() -> None:
    """Refresh dialogue portrait from paperdoll crop (Lanczos, no V7 crunch)."""
    master = PORTRAIT_SOURCE / "dialogue_portrait_harlan_voss_v01_master.png"
    if master.exists():
        portrait = Image.open(master).convert("RGB")
    elif PAPERDOLL.exists():
        # Soft head crop from paperdoll as interim master.
        im = Image.open(PAPERDOLL).convert("RGBA")
        import numpy as np

        px = np.asarray(im)
        rgb = px[..., :3].astype(np.int16)
        green = (rgb[..., 1] > 140) & (rgb[..., 1] > rgb[..., 0] + 40) & (rgb[..., 1] > rgb[..., 2] + 40)
        alpha = np.where(green, 0, px[..., 3])
        ys, xs = np.where(alpha > 40)
        if len(xs) == 0:
            return
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        h = y1 - y0 + 1
        # Head/shoulders band
        band = im.crop((x0, y0, x1 + 1, y0 + int(h * 0.42)))
        # Composite on dark noir
        bg = Image.new("RGB", band.size, (28, 30, 34))
        bg.paste(band, mask=band.split()[-1])
        portrait = bg
        PORTRAIT_SOURCE.mkdir(parents=True, exist_ok=True)
        portrait.save(master, optimize=True)
    else:
        return

    portrait = portrait.resize((512, 512), Image.Resampling.LANCZOS)
    DIALOGUE_UI.mkdir(parents=True, exist_ok=True)
    portrait.save(DIALOGUE_UI / "dialogue_portrait_harlan_voss_v01.png", optimize=True)


def make_previews_v12() -> None:
    frame_size = raster.FRAME_SIZE
    specs = [
        (
            "preview_walk_v12.png",
            "VossWalk.atlas",
            [f"voss_walk_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(8)],
            8,
        ),
        (
            "preview_idle_v12.png",
            "VossIdle.atlas",
            [f"voss_standing_idle_{d}_{i:02d}.png" for d in v6.DIRECTIONS for i in range(4)],
            4,
        ),
        (
            "preview_seat_transitions_v12.png",
            "VossSeatTransitions.atlas",
            [f"voss_stand_up_se_{i:02d}.png" for i in range(12)]
            + [f"voss_sit_down_se_{i:02d}.png" for i in range(12)],
            6,
        ),
    ]
    for filename, atlas_name, names, columns in specs:
        rows = (len(names) + columns - 1) // columns
        preview = Image.new("RGBA", (frame_size * columns, frame_size * rows), (24, 28, 31, 255))
        for index, name in enumerate(names):
            frame = Image.open(ATLASES / atlas_name / name).convert("RGBA")
            preview.alpha_composite(
                frame,
                ((index % columns) * frame_size, (index // columns) * frame_size),
            )
        preview.save(DETECTIVE_SOURCE / filename, optimize=True)

    # Paperdoll vs walk vs idle play-scale strip
    paper = Image.open(
        ROOT / "RainShadow Shared/Resources/Art/UI/Inventory/voss_paperdoll_front_rgba_v01.png"
    ).convert("RGBA")
    walk = Image.open(ATLASES / "VossWalk.atlas/voss_walk_s_00.png").convert("RGBA")
    idle = Image.open(ATLASES / "VossIdle.atlas/voss_standing_idle_se_00.png").convert("RGBA")
    canvas = Image.new("RGBA", (900, 320), (24, 28, 31, 255))
    ph = 280
    pw = max(1, round(paper.width * ph / paper.height))
    canvas.alpha_composite(paper.resize((pw, ph), Image.Resampling.LANCZOS), (16, 20))
    canvas.alpha_composite(walk.resize((256, 256), Image.Resampling.NEAREST), (340, 40))
    canvas.alpha_composite(idle.resize((256, 256), Image.Resampling.NEAREST), (620, 40))
    canvas.save(DETECTIVE_SOURCE / "qa_paperdoll_vs_sprites_v12.png", optimize=True)

    office_ref = ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png"
    if office_ref.exists():
        office = Image.open(office_ref).convert("RGBA")
        actor = ATLASES / "VossIdle.atlas/voss_standing_idle_se_00.png"
        root_x, root_y = 790, 800
        shadow_layer = Image.new("RGBA", office.size)
        draw = ImageDraw.Draw(shadow_layer)
        draw.ellipse((root_x - 27, root_y - 10, root_x + 27, root_y + 10), fill=(0, 0, 0, 88))
        office.alpha_composite(shadow_layer)
        frame = Image.open(actor).convert("RGBA").resize((256, 256), Image.Resampling.NEAREST)
        office.alpha_composite(frame, (root_x - 128, root_y - 217))
        office.convert("RGB").save(DETECTIVE_SOURCE / "preview_voss_in_office_v12.png", optimize=True)


def main() -> None:
    if not DETECTIVE_SOURCE.exists():
        raise FileNotFoundError(
            f"Missing V12 master directory {DETECTIVE_SOURCE}. "
            "Run relock_voss_identity_v12.py first."
        )

    global _WARDROBE_TARGET
    _WARDROBE_TARGET = None
    # Snapshot face/coat targets before any atlas write can poison the sample.
    targets = play_scale_wardrobe_stats()
    print(
        "Wardrobe targets face="
        f"{targets['face'].round(1).tolist()} coat={targets['coat'].round(1).tolist()}"
    )

    backup_prior_runtime()
    raster.pixelize_figure = pixelize_figure_v7
    process_voss_locomotion()
    process_voss_desk_chain_se()
    install_portrait_from_paperdoll()
    make_previews_v12()
    voss_cells = 9 * 8 + 9 * 4 + 4 + 8 + 8 + 24
    print(
        f"Registered {voss_cells} Voss V12 atlas cells (V7 crunch) from PreRendered3DV12; "
        f"prior runtime backed up to {BACKUP.name}; Lila untouched; paperdoll untouched"
    )


if __name__ == "__main__":
    main()
