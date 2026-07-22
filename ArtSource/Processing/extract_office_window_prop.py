"""Extract the baked office window into a transparent runtime prop.

The office shell owns the window pixels, but hover highlighting works on
independent sprites.  This keeps the shipped shell pixels exactly intact and
only supplies an alpha silhouette around the window frame.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "RainShadow Shared"
    / "Resources"
    / "Art"
    / "Areas"
    / "DetectiveOffice"
    / "office_shell_base.png"
)
OUTPUT = (
    ROOT
    / "RainShadow Shared"
    / "Resources"
    / "Art"
    / "Props"
    / "Office"
    / "office_window.png"
)

# Pixel coordinates in the 4096x2048 shell (origin at the PNG's top-left).
CROP = (1_128, 330, 1_432, 752)
WINDOW_FRAME = (
    (33, 99),
    (279, 20),
    (278, 292),
    (31, 398),
)
SUPERSAMPLE = 4


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    prop = source.crop(CROP)

    mask = Image.new(
        "L",
        (prop.width * SUPERSAMPLE, prop.height * SUPERSAMPLE),
        0,
    )
    draw = ImageDraw.Draw(mask)
    draw.polygon(
        [(x * SUPERSAMPLE, y * SUPERSAMPLE) for x, y in WINDOW_FRAME],
        fill=255,
    )
    mask = mask.resize(prop.size, Image.Resampling.LANCZOS)
    prop.putalpha(ImageChops.darker(prop.getchannel("A"), mask))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    prop.save(OUTPUT, optimize=True)


if __name__ == "__main__":
    main()
