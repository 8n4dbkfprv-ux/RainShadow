#!/usr/bin/env python3
"""Unseat the bad Sable Row portal.office stamp and rebake IE outdoor plates.

The f266886b portal paintover seated a razor-sharp Image Generator take
(Laplacian variance ~600) into a soft painterly plate region (~7). Soft
feathering cannot hide that: the neighbourhood reads as a lit rectangular
island on the Voss stoop. The pre-portal plate already has a painted door
from the ward rebuild; restoring it removes the stamp.

    python3 ArtSource/Processing/unseat_sable_row_portal_office_v01.py
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/CityDistrict/V2/UnifiedPlates/sable_row"
PORTAL = ROOT / "ArtSource/Generated/CityDistrict/V2/PortalPaint/sable_row/portal_office"
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
GEN_BLOCK = ROOT / "ArtSource/Generated/CityDistrict/V2/SableRow/city_sable_row_block_v02.png"

PRE = STAGE / "city_sable_row_area_v02.pre_portal.png"
STAGED = STAGE / "city_sable_row_area_v02.png"
BLOCK = ART / "city_sable_row_block_v02.png"
META = PORTAL / "meta.json"


def install_copy(src: Path, dst: Path) -> None:
    dst = Path(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    shutil.copy2(src, dst)


def main() -> int:
    if not PRE.exists():
        print(f"missing pre-portal backup: {PRE}", file=sys.stderr)
        return 1
    meta = json.loads(META.read_text())
    crop = tuple(int(v) for v in meta["crop"])

    pre = Image.open(PRE)
    staged = Image.open(STAGED)
    if pre.size != staged.size:
        print(f"size mismatch pre={pre.size} staged={staged.size}", file=sys.stderr)
        return 1

    # Sanity: only the portal crop should differ.
    import numpy as np

    pa = np.asarray(pre.convert("RGB"))
    sa = np.asarray(staged.convert("RGB"))
    diff = np.any(pa != sa, axis=2)
    ys, xs = np.where(diff)
    if len(xs) == 0:
        print("staged already matches pre-portal; nothing to unseat")
    else:
        bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        print(f"diff bbox {bbox} ({len(xs)} px) — expected crop {crop}")
        if bbox != crop:
            print(
                "warning: diff bbox is not exactly the portal crop; "
                "restoring full pre-portal anyway",
                file=sys.stderr,
            )

    print("restoring pre-portal → staged + installed block…")
    install_copy(PRE, STAGED)
    install_copy(PRE, BLOCK)
    if GEN_BLOCK.exists():
        install_copy(PRE, GEN_BLOCK)

    # Seated crop becomes the restored facade (no portal take).
    restored = Image.open(PRE).crop(crop).convert("RGB")
    restored.save(PORTAL / "seated.png", compress_level=3)
    restored.save(PORTAL / "source.png", compress_level=3)
    (PORTAL / "UNSEATED.txt").write_text(
        "portal.office take unseated 2026-08-26: IG take sharpness "
        "mismatched the soft plate (see unseat_sable_row_portal_office_v01.py).\n"
    )
    print(f"updated {PORTAL.relative_to(ROOT)}/seated.png + source.png")

    print("rebaking day + night placeholder…")
    bake = ROOT / "ArtSource/Processing/bake_sable_row_ie_outdoor_v01.py"
    rc = subprocess.call([sys.executable, str(bake)], cwd=str(ROOT))
    if rc != 0:
        return rc
    print("ALL CHECKS PASS (sable portal.office unseated + IE plates rebaked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
