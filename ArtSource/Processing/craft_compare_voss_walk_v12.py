#!/usr/bin/env python3
"""Craft + color gates for Voss walk cells vs paperdoll / seated play-scale.

Rejects over-detailed IG installs and coat/face grades that drift from the
frozen seated NE00 wardrobe targets used by identity_wardrobe_lock.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
PAPERDOLL = (
    ROOT / "ArtSource/Generated/Characters/Detective/Paperdoll/voss_paperdoll_front_chroma_v11.png"
)
SEATED = ATLASES / "VossSeatedIdle.atlas" / "voss_seated_idle_ne_00.png"
WALK = ATLASES / "VossWalk.atlas"

# Frozen seated targets (same as process_pre_rendered_characters_v12.play_scale_wardrobe_stats)
COAT_TGT = np.array([98.3, 66.7, 35.6], dtype=np.float32)
FACE_TGT = np.array([140.6, 98.8, 56.0], dtype=np.float32)

# Gates relative to a same-dir backup cell when provided; else absolute.
MAX_COAT_L2 = 22.0
MAX_FACE_L2 = 28.0
MAX_DETAIL_RATIO = 1.35  # vs backup walk cell (IG after heavy soften)
MAX_ABS_DETAIL = 6.5  # hard cap; wardrobe chroma-boost can raise edge energy
MIN_AREA_RATIO = 0.72
MAX_AREA_RATIO = 1.35


@dataclass
class CraftReport:
    ok: bool
    coat_l2: float
    face_l2: float
    detail: float
    area: int
    reasons: list[str]

    def summary(self) -> str:
        status = "PASS" if self.ok else "FAIL"
        why = ("; ".join(self.reasons)) if self.reasons else "ok"
        return (
            f"{status} coat_l2={self.coat_l2:.1f} face_l2={self.face_l2:.1f} "
            f"detail={self.detail:.2f} area={self.area} ({why})"
        )


def _mask(im: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    a = np.asarray(im.convert("RGBA"))
    return a, a[..., 3] > 40


def _roi_means(rgb: np.ndarray, mask: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    ys, xs = np.where(mask)
    if len(xs) == 0:
        z = np.zeros(3, dtype=np.float32)
        return z, z
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    h = y1 - y0 + 1
    # Face: upper 22%
    face = np.zeros_like(mask)
    face[y0 : y0 + max(4, int(h * 0.22)), x0:x1] = mask[
        y0 : y0 + max(4, int(h * 0.22)), x0:x1
    ]
    # Coat: mid torso band
    c0 = y0 + int(h * 0.22)
    c1 = y0 + int(h * 0.68)
    coat = np.zeros_like(mask)
    coat[c0:c1, x0:x1] = mask[c0:c1, x0:x1]
    # Prefer brownish coat pixels when available
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    brown = coat & (r > b + 4) & (r > 28) & (r < 210)
    if int(brown.sum()) >= 40:
        coat = brown

    def mean(m: np.ndarray) -> np.ndarray:
        if int(m.sum()) < 12:
            return rgb[mask].mean(axis=0).astype(np.float32)
        return rgb[m].mean(axis=0).astype(np.float32)

    return mean(coat), mean(face)


def detail_score(im: Image.Image) -> float:
    a, mask = _mask(im)
    gray = a[..., :3].astype(np.float32).mean(axis=-1)
    gy = np.abs(np.diff(gray, axis=0))
    m2 = mask[:-1] & mask[1:]
    if not m2.any():
        return 0.0
    return float(gy[m2].mean())


def opaque_area(im: Image.Image) -> int:
    return int((np.asarray(im.convert("RGBA"))[..., 3] > 10).sum())


def evaluate_cell(
    candidate: Image.Image,
    *,
    backup: Image.Image | None = None,
) -> CraftReport:
    a, mask = _mask(candidate)
    rgb = a[..., :3].astype(np.float32)
    coat, face = _roi_means(rgb, mask)
    coat_l2 = float(np.linalg.norm(coat - COAT_TGT))
    face_l2 = float(np.linalg.norm(face - FACE_TGT))
    detail = detail_score(candidate)
    area = opaque_area(candidate)
    reasons: list[str] = []

    if coat_l2 > MAX_COAT_L2:
        reasons.append(f"coat drift {coat_l2:.1f}>{MAX_COAT_L2}")
    # Rear / mostly-occluded faces sample hair — skip hard face gate when the
    # face ROI is dark (mean luminance under 70).
    face_lum = float(face.mean()) if face is not None else 0.0
    if face_l2 > MAX_FACE_L2 and face_lum >= 70.0:
        reasons.append(f"face drift {face_l2:.1f}>{MAX_FACE_L2}")
    if detail > MAX_ABS_DETAIL:
        reasons.append(f"detail {detail:.2f}>{MAX_ABS_DETAIL}")

    if backup is not None:
        b_detail = detail_score(backup)
        b_area = max(1, opaque_area(backup))
        # Skip ratio when absolute detail is already in the paperdoll band —
        # low-detail backups make ratios explode for acceptable cells.
        if (
            b_detail > 0
            and detail > MAX_ABS_DETAIL * 0.7
            and detail > b_detail * MAX_DETAIL_RATIO
        ):
            reasons.append(
                f"detail ratio {detail / b_detail:.2f}>{MAX_DETAIL_RATIO} vs backup"
            )
        ratio = area / b_area
        if ratio < MIN_AREA_RATIO or ratio > MAX_AREA_RATIO:
            reasons.append(f"area ratio {ratio:.2f} outside [{MIN_AREA_RATIO},{MAX_AREA_RATIO}]")

    return CraftReport(
        ok=not reasons,
        coat_l2=coat_l2,
        face_l2=face_l2,
        detail=detail,
        area=area,
        reasons=reasons,
    )


def evaluate_cycle(
    cells: list[Image.Image],
    backups: list[Image.Image] | None = None,
) -> tuple[bool, list[CraftReport]]:
    reports: list[CraftReport] = []
    for i, cell in enumerate(cells):
        bak = backups[i] if backups is not None else None
        reports.append(evaluate_cell(cell, backup=bak))
    return all(r.ok for r in reports), reports


def write_craft_strip(
    path: Path,
    cells: list[Image.Image],
    labels: list[str] | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    crops = []
    for c in cells:
        a = np.asarray(c.convert("RGBA"))
        m = a[..., 3] > 10
        ys, xs = np.where(m)
        crops.append(c.crop((xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5)))
    h = max(c.height for c in crops)
    w = sum(c.width for c in crops) + 8 * len(crops)
    strip = Image.new("RGB", (w, h + 28), (24, 24, 24))
    from PIL import ImageDraw

    draw = ImageDraw.Draw(strip)
    x = 0
    for i, c in enumerate(crops):
        bg = Image.new("RGBA", c.size, (24, 24, 24, 255))
        bg.alpha_composite(c.convert("RGBA"))
        strip.paste(bg.convert("RGB"), (x, 22))
        lab = labels[i] if labels and i < len(labels) else str(i)
        draw.text((x, 2), lab, fill=(220, 220, 220))
        x += c.width + 8
    strip.save(path, quality=95)


def main() -> None:
    seated = Image.open(SEATED).convert("RGBA")
    walk_s = Image.open(WALK / "voss_walk_s_00.png").convert("RGBA")
    for name, im in (("seated", seated), ("walk_s00", walk_s)):
        print(name, evaluate_cell(im).summary())


if __name__ == "__main__":
    main()
