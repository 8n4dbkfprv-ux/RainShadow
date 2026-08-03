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


def soften_for_paperdoll_craft(figure: Image.Image, radius: float = 2.2) -> Image.Image:
    """Drop micro-detail/contrast so V7 crunch matches paperdoll craft density."""
    import numpy as np

    rgba = figure.convert("RGBA")
    rgb = Image.merge("RGB", rgba.split()[:3]).filter(ImageFilter.GaussianBlur(radius=radius))
    # Mild contrast pull toward midtones (paperdoll is softer than V11 masters).
    arr = np.asarray(rgb).astype(np.float32)
    mean = arr.mean(axis=(0, 1), keepdims=True)
    arr = mean + (arr - mean) * 0.78
    rgb = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    alpha = rgba.split()[-1]
    return Image.merge("RGBA", (*rgb.split(), alpha))


def warm_brown_lock(figure: Image.Image) -> Image.Image:
    """Pull olive/yellow-green coat spill toward paperdoll + walk warm brown.

    Soften + V7 crunch can reintroduce G-dominant midtones on desk cells; enforce
    R > G on coat and match walk coat mean so seated/NE no longer reads olive.

    Always re-stamps atlas corner sentinels afterward: the soft-alpha wipe would
    otherwise clear lock_atlas_canvas's alpha=1 corners and let Xcode trim each
    frame to a different rect (fixed 232 node then stretches → size pulse).
    """
    import numpy as np

    import process_voss_desk_ne_v01 as ne

    walk_path = ATLASES / "VossWalk.atlas" / "voss_walk_s_00.png"
    px = np.asarray(figure.convert("RGBA")).copy()
    rgb = px[..., :3].astype(np.float32)
    a = px[..., 3].astype(np.float32)
    mask = a > 40
    if not mask.any():
        return ne.lock_atlas_canvas(figure.convert("RGBA"))

    # Target from walk coat (authoritative play-scale brown).
    if walk_path.exists():
        walk = np.asarray(Image.open(walk_path).convert("RGBA"))
        wa = walk[..., 3] > 40
        wrgb = walk[..., :3][wa].astype(np.float32)
        coat = wrgb[(wrgb[:, 0] > wrgb[:, 2]) & (wrgb[:, 0] > 55) & (wrgb[:, 0] < 190)]
        tgt = coat.mean(0) if len(coat) else np.array([90.0, 62.0, 30.0], dtype=np.float32)
    else:
        tgt = np.array([90.0, 62.0, 30.0], dtype=np.float32)

    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    other = np.maximum(r, b)
    spill = mask & ((g - other) > 4)
    g = np.where(spill, np.minimum(g, other + 1), g)
    cur = np.stack([r[mask], g[mask], b[mask]], 1).mean(0)
    scale = np.clip(tgt / (cur + 1e-5), 0.8, 1.25)
    r = np.where(mask, np.clip(r * scale[0], 0, 255), r)
    g = np.where(mask, np.clip(g * scale[1], 0, 255), g)
    b = np.where(mask, np.clip(b * scale[2], 0, 255), b)
    coat_m = mask & (r > b) & (r > 45) & (r < 210)
    g = np.where(coat_m & (g > r - 8), r - 12, g)
    b = np.where(coat_m, np.minimum(255, b + 8), b)
    still = mask & (g > r + 5) & (g > b + 5)
    a[still] = 0
    out = np.stack([r, g, b, a], -1)
    # Soft fringe cleanup — corners restored by lock_atlas_canvas below.
    out[out[..., 3] < 8] = 0
    locked = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    return ne.lock_atlas_canvas(locked)


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12"
PORTRAIT_SOURCE = ROOT / "ArtSource/Generated/UI/Dialogue"
DIALOGUE_UI = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV12Prior"
PAPERDOLL = (
    ROOT / "ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png"
)

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
    # warm_brown_lock ends with lock_atlas_canvas so trim cannot shrink cells.
    install_locked_frame_v12(warm_brown_lock(frame), atlas_name, filename, source_dir)


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


def process_voss_locomotion() -> None:
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_walk_{direction}_cycle")
        for phase, figure in enumerate(raster.crop_components(rgba, 8, 1)):
            save_frame_v12(
                raster.register(soften_for_paperdoll_craft(figure)),
                "VossWalk.atlas",
                f"voss_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    southwest_idle: list[Image.Image] = []
    for direction in v6.DIRECTIONS:
        rgba = keyed(DETECTIVE_SOURCE, f"voss_idle_{direction}_strip")
        for phase, figure in enumerate(raster.crop_components(rgba, 4, 1)):
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
        warm_brown_lock(
            ne.register_shared(soften_for_paperdoll_craft(figure), stand_ref_h)
        )
        for figure in idle_figures
    ]
    stand_cells = [
        warm_brown_lock(
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
