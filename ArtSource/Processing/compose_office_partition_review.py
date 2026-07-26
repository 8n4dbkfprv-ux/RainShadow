"""Offline review plates A–E for the authored partition + cutaway mask.

A shell only
B partition plate on transparency
C shell + full partition (no furniture)
D = C (mask disabled equivalent: full plate)
E shell + cutaway plate
Also writes halves.

Live F/G still come from capture_office_review.sh.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHELL = ROOT / "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png"
PROPS = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
OUT = ROOT / "ArtSource/Generated/Office/review"


def save(im: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.png"
    im.save(path)
    im.resize((im.width // 2, im.height // 2), Image.Resampling.LANCZOS).save(
        OUT / f"{name}_half.png"
    )
    print(f"wrote {path.relative_to(ROOT)} {im.size}")


def main() -> None:
    shell = Image.open(SHELL).convert("RGBA")
    plate = Image.open(PROPS / "office_partition_wall.png").convert("RGBA")
    cutaway = Image.open(PROPS / "office_partition_wall_cutaway.png").convert("RGBA")
    void = Image.open(PROPS / "office_foreground_cutaway.png").convert("RGBA")
    leaf = Image.open(PROPS / "office_internal_door_leaf.png").convert("RGBA")
    mask = Image.open(PROPS / "office_partition_cutaway_mask.png").convert("L")

    # A — shell only
    save(shell.convert("RGB"), "A_shell_only")

    # B — partition plate alone on checker/transparency (dark field)
    alone = Image.new("RGBA", shell.size, (12, 12, 16, 255))
    alone.alpha_composite(plate)
    save(alone.convert("RGB"), "B_partition_plate_only")

    # C / D — shell + full plate + void (mask off)
    c = shell.copy()
    c.alpha_composite(plate)
    c.alpha_composite(void)
    save(c.convert("RGB"), "C_shell_plus_partition")
    save(c.convert("RGB"), "D_mask_disabled")

    # E — shell + cutaway plate + void (mask on)
    e = shell.copy()
    e.alpha_composite(cutaway)
    e.alpha_composite(void)
    save(e.convert("RGB"), "E_mask_enabled")

    # Mask visualization
    mask_rgb = Image.merge("RGB", (mask, mask, mask))
    save(mask_rgb, "E_cutaway_mask_luma")

    print("leaf", leaf.size, "opening metrics in office_partition_opening.json")


if __name__ == "__main__":
    main()
