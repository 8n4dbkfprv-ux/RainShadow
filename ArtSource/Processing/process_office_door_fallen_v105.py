"""Build the runtime fallen-door texture from the V10.5 Image Generator master.

The generator master is already chroma-keyed to RGBA by the shared imagegen
helper. This processor keeps the full, centered transparent canvas so the
runtime can swap from the animated upright leaf to the pre-projected landed
art without an anchor jump.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "ArtSource/Generated/Office/Props/office_door_leaf_fallen_rgba_v105.png"
)
RUNTIME = (
    ROOT
    / "RainShadow Shared/Resources/Art/Props/Office/office_door_leaf_fallen.png"
)

SOURCE_SIZE = (1536, 1024)
RUNTIME_SIZE = (768, 512)


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing fallen-door RGBA master: {SOURCE}")

    image = Image.open(SOURCE).convert("RGBA")
    if image.size != SOURCE_SIZE:
        raise SystemExit(f"unexpected fallen-door source size {image.size}")

    alpha = image.getchannel("A")
    if alpha.getbbox() is None:
        raise SystemExit("fallen-door source has no opaque subject")
    if any(alpha.getpixel(point) != 0 for point in (
        (0, 0),
        (SOURCE_SIZE[0] - 1, 0),
        (0, SOURCE_SIZE[1] - 1),
        (SOURCE_SIZE[0] - 1, SOURCE_SIZE[1] - 1),
    )):
        raise SystemExit("fallen-door source corners must be transparent")

    runtime = image.resize(RUNTIME_SIZE, Image.Resampling.LANCZOS)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(RUNTIME)
    print(f"wrote {RUNTIME.relative_to(ROOT)} {runtime.size}")


if __name__ == "__main__":
    main()
