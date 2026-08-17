#!/usr/bin/env python3
"""A/B pixelation study V03: pick the V15 crunch at the *current* camera.

V14 (56 rows / 1-bit / ramps) was selected by `qa_pixelation_ab_v02.py` at the
13% camera of 2026-08-06. Two things changed since:

- `DefaultPlayZoom.targetBodyToVisibleHeight` reverted to **0.09** (BG:EE area
  density), so the study camera is stale again.
- The user-visible defect this study answers: our sprite pixels are ~3.2x
  coarser than the office plate (56 rows / 70.3 wu = 0.80 px/wu against the
  plate's 2.53). A BG:EE sprite is *never* coarser than its background — both
  share one raster, and the EE engine's zoom smooths them together.

Candidates therefore climb the density axis toward plate parity (200 rows =
2.84 px/wu) and add the V15 value-contrast stage. Play-scale tiles are
composited twice: nearest (shipped runtime) and linear (the planned runtime
filtering, which is what the EE engine does when zoomed).

Nothing here writes to an atlas. It bakes candidates and stages two sheets.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import crunch as crunch_mod
import install_voss_v16 as v16

ROOT = Path(__file__).resolve().parents[2]
SUBJECT = (
    ROOT
    / "ArtSource/Generated/Characters/Detective/PreRendered3DV21/Frames/voss_idle_sw_00_chroma_v21.png"
)
OFFICE_PLATE = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png"
BGEE_REFS = ROOT / "ArtSource/References/BGEE"
OUTPUT = ROOT / "ArtSource/Generated/Characters/Detective/PixelationAB"
SHIPPED_FRAME = (
    ROOT / "RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas/voss_standing_idle_sw_00.png"
)

# ---------------------------------------------------------------------------
# Play-scale geometry, derived from the Swift constants rather than guessed.
#   OfficeInteriorScale.ActorDisplay: 512 canvas, 200px body, 180pt node
#   OfficeInteriorScale.environment:  0.395 world units per plate pixel
#   DefaultPlayZoom.targetBodyToVisibleHeight: 0.09  (reverted from 0.13)
#   TechnicalArchitecture §4.1: 16:9 viewport ~1789x1007
# ---------------------------------------------------------------------------
FRAME_SIZE = 512
TEXTURE_BODY_HEIGHT = 200
FOOT_Y = 434
SPRITE_DISPLAY_WORLD = 180.0
FOOT_ANCHOR = 40 / 256
ENVIRONMENT = 0.395
TARGET_BODY_FRACTION = 0.09
VIEWPORT_HEIGHT = 1007

BODY_WORLD = TEXTURE_BODY_HEIGHT / FRAME_SIZE * SPRITE_DISPLAY_WORLD          # 70.31
CAMERA_VISIBLE_WORLD = BODY_WORLD / TARGET_BODY_FRACTION                      # 781.25
VISIBLE_PLATE_PX = CAMERA_VISIBLE_WORLD / ENVIRONMENT                         # 1977.8
PLATE_TO_SCREEN = VIEWPORT_HEIGHT / VISIBLE_PLATE_PX                          # 0.5092
SPRITE_SCREEN_PX = round(SPRITE_DISPLAY_WORLD / ENVIRONMENT * PLATE_TO_SCREEN)  # 232
BODY_SCREEN_PX = TEXTURE_BODY_HEIGHT / FRAME_SIZE * SPRITE_SCREEN_PX          # ~91

PLATE_ROOT = (2000, 1300)
TILE_SCREEN = 260

PLATE_PX_PER_WU = 1 / ENVIRONMENT  # 2.53


VARIANTS = [
    ("v14", "V14  56 rows  64c  (shipped)", crunch_mod.V14),
    (
        "mid112",
        "112 rows  128c  c1.00",
        crunch_mod.CrunchSpec(
            native_rows=112, colors=128, hard_alpha=True, ramp_palette=True,
            contrast=1.00, ramp_steps=16, soften_radius=1.8,
        ),
    ),
    (
        "v15_flat",
        "V15  200 rows  128c  vc1.00",
        crunch_mod.CrunchSpec(
            native_rows=200, colors=128, hard_alpha=True, ramp_palette=True,
            contrast=1.00, ramp_steps=16, soften_radius=1.2,
        ),
    ),
    (
        "v15_c118",
        "V15  200 rows  128c  vc1.18",
        crunch_mod.CrunchSpec(
            native_rows=200, colors=128, hard_alpha=True, ramp_palette=True,
            contrast=1.00, ramp_steps=16, soften_radius=1.2, value_contrast=1.18,
        ),
    ),
    (
        "v15_c135",
        "V15  200 rows  128c  vc1.35",
        crunch_mod.CrunchSpec(
            native_rows=200, colors=128, hard_alpha=True, ramp_palette=True,
            contrast=1.00, ramp_steps=16, soften_radius=1.2, value_contrast=1.35,
        ),
    ),
]


def bake(keyed: Image.Image, spec: crunch_mod.CrunchSpec) -> Image.Image:
    soft = crunch_mod.soften(keyed, radius=spec.soften_radius, contrast=spec.contrast)
    figure = crunch_mod.crunch(soft, spec=spec)
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(
        figure, ((FRAME_SIZE - figure.width) // 2, FOOT_Y - figure.height)
    )
    return canvas


def screen_plate() -> Image.Image:
    plate = Image.open(OFFICE_PLATE).convert("RGBA")
    size = (round(plate.width * PLATE_TO_SCREEN), round(plate.height * PLATE_TO_SCREEN))
    return plate.resize(size, Image.Resampling.LANCZOS)


def office_tile(frame: Image.Image, plate: Image.Image, resample: Image.Resampling) -> Image.Image:
    root_x = round(PLATE_ROOT[0] * PLATE_TO_SCREEN)
    root_y = round(PLATE_ROOT[1] * PLATE_TO_SCREEN)
    half = TILE_SCREEN // 2
    tile = plate.crop((root_x - half, root_y - half, root_x + half, root_y + half)).copy()

    centre_x, centre_y = half, half
    shadow = Image.new("RGBA", tile.size)
    shadow_w = round(SPRITE_SCREEN_PX * 0.105)
    shadow_h = round(SPRITE_SCREEN_PX * 0.039)
    ImageDraw.Draw(shadow).ellipse(
        (centre_x - shadow_w, centre_y - shadow_h, centre_x + shadow_w, centre_y + shadow_h),
        fill=(0, 0, 0, 110),
    )
    tile.alpha_composite(shadow)

    display = frame.resize((SPRITE_SCREEN_PX, SPRITE_SCREEN_PX), resample)
    top = centre_y - round(SPRITE_SCREEN_PX * (1 - FOOT_ANCHOR))
    tile.alpha_composite(display, (centre_x - SPRITE_SCREEN_PX // 2, top))
    return tile


def labelled(tile: Image.Image, text: str, label_height: int = 28) -> Image.Image:
    block = Image.new("RGBA", (tile.width, tile.height + label_height), (18, 18, 18, 255))
    block.alpha_composite(tile.convert("RGBA"), (0, 0))
    ImageDraw.Draw(block).text((6, tile.height + 8), text, fill=(230, 230, 230, 255))
    return block


def zoom_tile(frame: Image.Image, zoom: int = 3) -> Image.Image:
    display = frame.resize((SPRITE_SCREEN_PX, SPRITE_SCREEN_PX), Image.Resampling.NEAREST)
    bbox = display.getchannel("A").point(lambda v: 255 if v >= 16 else 0).getbbox()
    crop = display.crop(bbox)
    crop = crop.resize((crop.width * zoom, crop.height * zoom), Image.Resampling.NEAREST)
    tile = Image.new("RGBA", (crop.width + 20, crop.height + 20), (30, 30, 34, 255))
    tile.alpha_composite(crop, (10, 10))
    return tile


def grid(tiles: list[Image.Image], columns: int) -> Image.Image:
    width = max(tile.width for tile in tiles)
    height = max(tile.height for tile in tiles)
    rows = (len(tiles) + columns - 1) // columns
    sheet = Image.new("RGBA", (width * columns, height * rows), (18, 18, 18, 255))
    for index, tile in enumerate(tiles):
        x = (index % columns) * width + (width - tile.width) // 2
        y = (index // columns) * height
        sheet.alpha_composite(tile, (x, y))
    return sheet


def reference_tiles() -> list[Image.Image]:
    tiles: list[Image.Image] = []
    native = Image.open(BGEE_REFS / "bgee_avatar_color_slots_paperdoll.png").convert("RGBA")
    scale = BODY_SCREEN_PX / native.height
    scaled = native.resize(
        (max(1, round(native.width * scale)), round(native.height * scale)),
        Image.Resampling.LANCZOS,
    )
    tile = Image.new("RGBA", (TILE_SCREEN, TILE_SCREEN), (25, 25, 28, 255))
    tile.alpha_composite(scaled, ((TILE_SCREEN - scaled.width) // 2, (TILE_SCREEN - scaled.height) // 2))
    tiles.append(labelled(tile, "REF  native BG asset at play body height (linear)"))

    for name in ("bgee_avatar_green_robe.png", "bgee_avatar_red_tunic_fighter.png"):
        ref = Image.open(BGEE_REFS / name).convert("RGBA")
        scale = (BODY_SCREEN_PX * 1.25) / ref.height
        ref = ref.resize(
            (max(1, round(ref.width * scale)), max(1, round(ref.height * scale))),
            Image.Resampling.LANCZOS,
        )
        tile = Image.new("RGBA", (TILE_SCREEN, TILE_SCREEN), (25, 25, 28, 255))
        tile.alpha_composite(ref, ((TILE_SCREEN - ref.width) // 2, (TILE_SCREEN - ref.height) // 2))
        tiles.append(labelled(tile, f"REF  {name.split('_', 2)[2].replace('.png', '')}"))
    return tiles


def measure(frame: Image.Image, native_rows: int) -> dict[str, float]:
    pixels = np.asarray(frame)
    alpha = pixels[..., 3]
    visible = alpha > 0
    gated = alpha >= 16
    ys, xs = np.nonzero(gated)
    opaque = pixels[alpha == 255][:, :3]
    luma = opaque.mean(axis=1) if len(opaque) else np.array([0.0])
    sprite_px_per_wu = native_rows / BODY_WORLD
    return {
        "body_h": float(ys.max() - ys.min() + 1),
        "foot_y": float(ys.max()),
        "opaque_pct": 100.0 * (alpha == 255).sum() / max(1, visible.sum()),
        "colours": float(len(np.unique(opaque, axis=0))) if len(opaque) else 0.0,
        "luma_sd": float(luma.std()),
        "px_per_wu": sprite_px_per_wu,
        "vs_plate": sprite_px_per_wu / PLATE_PX_PER_WU,
    }


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    print(
        f"Play scale: body {BODY_SCREEN_PX:.1f}px of a {VIEWPORT_HEIGHT}px viewport "
        f"({100 * BODY_SCREEN_PX / VIEWPORT_HEIGHT:.1f}%), sprite node {SPRITE_SCREEN_PX}px, "
        f"plate scaled {PLATE_TO_SCREEN:.4f}, plate {PLATE_PX_PER_WU:.2f} px/wu\n"
    )

    keyed = v16.key_chroma(Image.open(SUBJECT).convert("RGB"))
    plate = screen_plate()

    play_tiles: list[Image.Image] = []
    zoom_tiles: list[Image.Image] = []
    rows: list[tuple[str, dict[str, float]]] = []

    shipped = Image.open(SHIPPED_FRAME).convert("RGBA")
    play_tiles.append(
        labelled(office_tile(shipped, plate, Image.Resampling.NEAREST), "SHIPPED nearest (on disk)")
    )
    play_tiles.append(
        labelled(office_tile(shipped, plate, Image.Resampling.BILINEAR), "SHIPPED linear")
    )
    zoom_tiles.append(labelled(zoom_tile(shipped), "SHIPPED  VossIdle sw_00 on disk"))
    rows.append(("SHIPPED on disk", measure(shipped, crunch_mod.V14.native_rows)))

    for key, label, spec in VARIANTS:
        frame = bake(keyed, spec)
        frame.save(OUTPUT / f"v03_variant_{key}.png", optimize=True)
        play_tiles.append(
            labelled(office_tile(frame, plate, Image.Resampling.NEAREST), f"{label}  nearest")
        )
        play_tiles.append(
            labelled(office_tile(frame, plate, Image.Resampling.BILINEAR), f"{label}  linear")
        )
        zoom_tiles.append(labelled(zoom_tile(frame), label))
        rows.append((label, measure(frame, spec.native_rows)))

    play_tiles.extend(reference_tiles())

    grid(play_tiles, columns=2).convert("RGB").save(
        OUTPUT / "qa_playscale_sheet_v03.png", optimize=True
    )
    grid(zoom_tiles, columns=3).convert("RGB").save(
        OUTPUT / "qa_zoom_sheet_v03.png", optimize=True
    )

    header = (
        f"{'variant':<34} {'body':>5} {'foot':>5} {'opaque%':>8} {'cols':>5} "
        f"{'luma sd':>8} {'px/wu':>6} {'vs plate':>9}"
    )
    print(header)
    print("-" * len(header))
    for label, m in rows:
        print(
            f"{label:<34} {m['body_h']:>5.0f} {m['foot_y']:>5.0f} {m['opaque_pct']:>8.1f} "
            f"{m['colours']:>5.0f} {m['luma_sd']:>8.1f} {m['px_per_wu']:>6.2f} {m['vs_plate']:>8.2f}x"
        )
    print(
        "\nGates: body must be 198...202, foot row must be 433."
        "\nReference: a real BG paperdoll asset measures 100% opaque, luma sd 45.7."
        "\nBG:EE parity means vs-plate ~1.0x; V14 ships at 0.32x."
    )
    print(f"\nWrote {OUTPUT.relative_to(ROOT)}: {len(VARIANTS)} variants + 2 sheets")


if __name__ == "__main__":
    main()
