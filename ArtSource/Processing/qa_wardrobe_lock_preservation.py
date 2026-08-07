#!/usr/bin/env python3
"""Verify the colour locks preserve a wardrobe once preservation is armed.

The locks were built for monochrome masters and fix them by stamping one chroma
ratio across most of the body, clamping G <= R x 0.68, and deleting greenish
pixels. On a real wardrobe that is destructive — it would erase a #364636 tie.
`crunch.PRESERVE_WARDROBE` gates those passes.

Today's masters are monochrome, so there is nothing to test the armed path
against until new art lands. This synthesises a separated figure from a shipped
frame (via the false-colour PoC), pushes it through both locks with preservation
off and on, and reports what survives.

Expected: OFF collapses the hue spread back toward monochrome; ON keeps it.
"""

from __future__ import annotations

from PIL import Image

import crunch as crunch_mod
from process_pre_rendered_characters_v12 import identity_wardrobe_lock
from install_voss_idle_walk_seated_match_v02 import seated_authority_lock
from qa_wardrobe_falsecolour_poc import WARDROBE as WARDROBE_TARGET, recolour, segment

SUBJECTS = [
    "VossIdle.atlas/voss_standing_idle_s_00.png",
    "VossIdle.atlas/voss_standing_idle_sw_00.png",
    "VossSeatedIdle.atlas/voss_seated_idle_ne_00.png",
]


def run(frame: Image.Image, armed: bool) -> Image.Image:
    previous = crunch_mod.PRESERVE_WARDROBE
    crunch_mod.PRESERVE_WARDROBE = armed
    try:
        return identity_wardrobe_lock(seated_authority_lock(frame, exposure=1.0))
    finally:
        crunch_mod.PRESERVE_WARDROBE = previous


# The materials the locks specifically attack, and how.
#   tie        `still = mask & (g > r+5) & (g > b+5); a[still] = 0`  → deleted outright
#   waistcoat  the `yellow` clamp forces b = r*0.367, g = r*0.678    → stops being ochre
#   trousers   coat chroma stamp + warm coat bias                    → stops being grey
WATCH = ("tie", "waistcoat", "trousers")


def material_state(frame: Image.Image, regions, name: str) -> tuple[float, float]:
    """Surviving fraction of a material, and how far its mean drifted from target."""
    import numpy as np

    region = regions[name]
    pixels = np.asarray(frame.convert("RGBA"))
    alive = region & (pixels[..., 3] >= 128)
    if int(region.sum()) == 0:
        return 1.0, 0.0
    survival = int(alive.sum()) / int(region.sum())
    if int(alive.sum()) < 4:
        return survival, 999.0
    mean = pixels[alive][:, :3].astype(float).mean(0)
    target = np.array(WARDROBE_TARGET[name], dtype=float)
    # Compare hue only: the locks are allowed to change exposure, not identity.
    drift = float(
        np.linalg.norm(mean / max(mean.mean(), 1e-5) - target / max(target.mean(), 1e-5))
    )
    return survival, drift


def main() -> int:
    from qa_pixelation_ab_v02 import ROOT

    atlases = ROOT / "RainShadow Shared/Resources/Art/Atlases"
    failures = 0

    print("Per-material survival through the colour locks.")
    print("survival = fraction of the material's pixels still opaque")
    print("drift    = hue distance from the intended wardrobe colour (lower is better)\n")

    for rel in SUBJECTS:
        shipped = Image.open(atlases / rel).convert("RGBA")
        synthetic = recolour(shipped)
        regions = segment(synthetic)

        off = run(synthetic, armed=False)
        on = run(synthetic, armed=True)

        print(f"{rel.split('/')[-1]}")
        for name in WATCH:
            if int(regions[name].sum()) < 8:
                continue
            s_off, d_off = material_state(off, regions, name)
            s_on, d_on = material_state(on, regions, name)
            flag = ""
            if s_on < 0.97:
                flag = "  ! armed lock still destroys it"
                failures += 1
            elif d_on > d_off + 0.02 or s_on < s_off - 0.03:
                flag = "  ! arming made it no better"
                failures += 1
            print(f"   {name:10s} OFF survival {s_off:5.2f} drift {d_off:5.2f}   "
                  f"ON survival {s_on:5.2f} drift {d_on:5.2f}{flag}")
        print()

    if failures:
        print(f"FAIL ({failures})")
    else:
        print("PASS — arming preservation keeps every watched material intact")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
