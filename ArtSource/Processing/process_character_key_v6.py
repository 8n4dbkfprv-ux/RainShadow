#!/usr/bin/env python3
"""Gate the V6 Voss/March identity keys at play scale before batch animation."""

from pathlib import Path

from PIL import Image, ImageDraw

import process_pre_rendered_characters_v3 as raster
from process_character_gait_v5 import remove_green_screen


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV6"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV6"
OFFICE_PLATE = ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png"
PREVIEW = ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v06.png"


def process_key(source_dir: Path, stem: str) -> Image.Image:
    chroma = source_dir / f"{stem}_chroma_v06.png"
    rgba = source_dir / f"{stem}_rgba_v06.png"
    runtime = source_dir / f"{stem}_runtime_v06.png"
    remove_green_screen(chroma, rgba)
    frame = raster.register(Image.open(rgba).convert("RGBA"))
    frame.save(runtime, optimize=True)
    print(f"Wrote {runtime.relative_to(ROOT)}")
    return frame


def make_office_preview(voss: Image.Image, lila: Image.Image) -> None:
    office = Image.open(OFFICE_PLATE).convert("RGBA")
    actors = [(790, 800, voss, 54, 20), (1450, 800, lila, 44, 15)]
    shadow_layer = Image.new("RGBA", office.size)
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for root_x, root_y, _, shadow_w, shadow_h in actors:
        shadow_draw.ellipse(
            (root_x - shadow_w // 2, root_y - shadow_h // 2, root_x + shadow_w // 2, root_y + shadow_h // 2),
            fill=(0, 0, 0, 88),
        )
    office.alpha_composite(shadow_layer)
    for root_x, root_y, frame, _, _ in actors:
        display = frame.resize((256, 256), Image.Resampling.NEAREST)
        office.alpha_composite(display, (root_x - 128, root_y - 217))
    office.convert("RGB").save(PREVIEW, optimize=True)
    print(f"Wrote {PREVIEW.relative_to(ROOT)}")


def main() -> None:
    voss = process_key(DETECTIVE_SOURCE, "voss_key_se")
    lila = process_key(CLIENT_SOURCE, "lila_key_sw")
    make_office_preview(voss, lila)


if __name__ == "__main__":
    main()
