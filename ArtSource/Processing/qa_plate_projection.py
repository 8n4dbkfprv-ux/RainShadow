#!/usr/bin/env python3
"""Measure the ground-axis angles actually baked into an area plate.

"Follows BG:EE" is a measurable property, not a matter of opinion: under the
Infinity Engine camera every ground line lands on one of two screen slopes,
+0.75 and -0.75 (±36.87° from horizontal), and every upright stays vertical.
Floorboards, wall bases, kerbs, roof eaves and sill lines all obey it.

This tool builds a magnitude-weighted histogram of edge-tangent orientations
and reports the dominant ground-axis peaks, so a generated or hand-painted
master can be graded against `ie_projection` before it is installed.

    python3 ArtSource/Processing/qa_plate_projection.py <plate.png> [...]
    python3 ArtSource/Processing/qa_plate_projection.py --shipped

Exit code is non-zero when any plate misses the lock by more than the
tolerance, so this can gate an install.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie

ROOT = Path(__file__).resolve().parents[2]

# Always grade against the BG:EE target, never against `ie_projection.ACTIVE`.
# This tool exists to decide whether a master is allowed to become the new art,
# so it must not move when the active camera does.
TARGET_DEG = ie.BGEE.ground_axis_deg  # 36.8699
# Generated/painterly art will never be perfect. This band is wide enough to
# accept honest painterly variance and narrow enough to reject the legacy
# camera, whose axes sit at 26.57° — 10.3° away.
TOLERANCE_DEG = 4.0
LEGACY_DEG = ie.LEGACY_V2.ground_axis_deg  # 26.565

# Orientation band treated as "ground axis". Excludes near-horizontal edges
# (plate borders, letterboxing, scanlines) and near-vertical uprights, whose
# smoothed tails otherwise leak a false peak into the high end of the band.
BAND = (10.0, 68.0)
BIN_DEG = 0.5


def _blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Separable Gaussian. A 3x3 Sobel alone reads the stair-stepping of a
    rasterised line rather than the line, and snaps orientations to 0/26.6/45.
    Smoothing first is what makes the estimate track the true angle."""
    if sigma <= 0:
        return a
    radius = max(1, int(3 * sigma))
    x = np.arange(-radius, radius + 1, dtype=np.float32)
    k = np.exp(-(x**2) / (2 * sigma * sigma))
    k /= k.sum()
    out = a
    for axis in (0, 1):
        pad_width = [(0, 0), (0, 0)]
        pad_width[axis] = (radius, radius)
        p = np.pad(out, pad_width, mode="edge")
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl: list[slice] = [slice(None), slice(None)]
            sl[axis] = slice(i, i + out.shape[axis])
            acc += w * p[tuple(sl)]
        out = acc
    return out


def _gradients(gray: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    kx = np.array([[-1.0, 0.0, 1.0], [-2.0, 0.0, 2.0], [-1.0, 0.0, 1.0]])
    ky = np.array([[-1.0, -2.0, -1.0], [0.0, 0.0, 0.0], [1.0, 2.0, 1.0]])
    pad = np.pad(gray, 1, mode="edge")
    gx = np.zeros_like(gray)
    gy = np.zeros_like(gray)
    for j in range(3):
        for i in range(3):
            window = pad[j : j + gray.shape[0], i : i + gray.shape[1]]
            gx += kx[j, i] * window
            gy += ky[j, i] * window
    return gx, gy


def _content_crop(im: Image.Image, fill_frac: float = 0.85) -> Image.Image:
    """Crop letterboxed plates to the painted silhouette.

    A cramped office on a 4096×2304 canvas is mostly black void. That
    silhouette rim is a hard synthetic outline and pulls the histogram off
    the floorboards. Full-bleed city grounds fill the frame, so this is a
    no-op for them.
    """
    rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    lum = rgb.mean(axis=2)
    ys, xs = np.where(lum > 12)
    if xs.size < 100:
        return im
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    if (x1 - x0) * (y1 - y0) >= fill_frac * im.width * im.height:
        return im
    return im.crop((x0, y0, x1, y1))


def orientation_histogram(
    path: Path,
    max_side: int = 1600,
    *,
    pre_sigma: float = 1.6,
    tensor_sigma: float = 4.0,
    min_coherence: float = 0.35,
) -> tuple[np.ndarray, np.ndarray, dict]:
    """Structure-tensor orientation histogram.

    Per-pixel gradients are noisy and alias badly on hard lines. The structure
    tensor averages gradient *outer products* over a neighbourhood, so a run of
    pixels along one architectural line votes once, coherently, for that line's
    true orientation.
    """
    im = Image.open(path).convert("RGBA")
    im = _content_crop(im)
    scale = min(1.0, max_side / max(im.size))
    if scale < 1.0:
        im = im.resize(
            (max(1, int(im.width * scale)), max(1, int(im.height * scale))),
            Image.Resampling.LANCZOS,
        )
    rgba = np.asarray(im, dtype=np.float32)
    alpha = rgba[:, :, 3]
    gray = rgba[:, :, :3].mean(axis=2)

    gx, gy = _gradients(_blur(gray, pre_sigma))

    # Structure tensor, smoothed over a neighbourhood.
    jxx = _blur(gx * gx, tensor_sigma)
    jyy = _blur(gy * gy, tensor_sigma)
    jxy = _blur(gx * gy, tensor_sigma)

    # Closed-form eigen-decomposition of the symmetric 2x2 tensor.
    diff = jxx - jyy
    root = np.sqrt(diff * diff + 4.0 * jxy * jxy)
    lam1 = 0.5 * (jxx + jyy + root)  # across the edge
    lam2 = 0.5 * (jxx + jyy - root)  # along the edge
    coherence = np.where(lam1 + lam2 > 1e-9, (lam1 - lam2) / (lam1 + lam2 + 1e-9), 0.0)

    # Dominant gradient direction (eigenvector of lam1).
    gdir_x = jxx - jyy + root
    gdir_y = 2.0 * jxy

    # Ignore transparent regions and the pure-black void outside the silhouette:
    # both produce a hard synthetic outline that is not scene geometry.
    opaque = alpha > 32
    lit = gray > 12
    inner = np.zeros_like(opaque)
    margin = max(4, int(3 * tensor_sigma))
    inner[margin:-margin, margin:-margin] = True
    valid = opaque & lit & inner
    if not valid.any():
        raise ValueError(f"{path}: no opaque lit pixels")

    energy = lam1
    thresh = np.percentile(energy[valid], 88.0)
    strong = valid & (energy >= max(thresh, 1e-9)) & (coherence >= min_coherence)
    if not strong.any():
        raise ValueError(f"{path}: no coherent linear structure")

    # Edge tangent is perpendicular to the dominant gradient.
    tx = -gdir_y[strong]
    ty = gdir_x[strong]
    weights = (energy[strong] * coherence[strong]).astype(np.float64)

    # Angle from horizontal, wrapped to [-90, 90). Image y is down, so flip the
    # sign to report screen-space slope the way art directions read it.
    theta = np.degrees(np.arctan2(-ty, tx))
    theta = (theta + 90.0) % 180.0 - 90.0

    bins = np.arange(-90.0, 90.0 + BIN_DEG, BIN_DEG)
    hist, _ = np.histogram(theta, bins=bins, weights=weights)
    centers = (bins[:-1] + bins[1:]) / 2.0

    # Light circular smoothing so a peak is not split across adjacent bins.
    kernel = np.array([1.0, 2.0, 3.0, 2.0, 1.0])
    kernel /= kernel.sum()
    hist = np.convolve(np.concatenate([hist[-4:], hist, hist[:4]]), kernel, mode="same")[
        4:-4
    ]

    total = hist.sum()
    vertical = hist[np.abs(np.abs(centers) - 90.0) <= 4.0].sum()
    stats = {
        "size": im.size,
        "vertical_share": float(vertical / total) if total else 0.0,
        "coherent_px": int(strong.sum()),
    }
    return centers, hist, stats


def _refine(centers: np.ndarray, hist: np.ndarray, peak_idx: int) -> float:
    """Sub-bin peak location by parabolic interpolation of the histogram."""
    if peak_idx <= 0 or peak_idx >= len(hist) - 1:
        return float(centers[peak_idx])
    y0, y1, y2 = hist[peak_idx - 1], hist[peak_idx], hist[peak_idx + 1]
    denom = y0 - 2.0 * y1 + y2
    if abs(denom) < 1e-12:
        return float(centers[peak_idx])
    delta = 0.5 * (y0 - y2) / denom
    delta = float(np.clip(delta, -1.0, 1.0))
    return float(centers[peak_idx] + delta * BIN_DEG)


def dominant_axes(centers: np.ndarray, hist: np.ndarray) -> tuple[float, float]:
    lo, hi = BAND
    pos = np.where((centers >= lo) & (centers <= hi))[0]
    neg = np.where((centers <= -lo) & (centers >= -hi))[0]
    if pos.size == 0 or neg.size == 0:
        raise ValueError("no ground-axis energy in band")
    peak_pos = _refine(centers, hist, int(pos[np.argmax(hist[pos])]))
    peak_neg = _refine(centers, hist, int(neg[np.argmax(hist[neg])]))
    return peak_pos, peak_neg


def grade(path: Path) -> dict:
    centers, hist, stats = orientation_histogram(path)
    peak_pos, peak_neg = dominant_axes(centers, hist)
    mean_abs = (abs(peak_pos) + abs(peak_neg)) / 2.0
    worst = max(abs(abs(peak_pos) - TARGET_DEG), abs(abs(peak_neg) - TARGET_DEG))
    return {
        "path": path,
        "size": stats["size"],
        "peak_pos": peak_pos,
        "peak_neg": peak_neg,
        "mean_abs": mean_abs,
        "worst_delta": worst,
        "slope_pos": math.tan(math.radians(abs(peak_pos))),
        "slope_neg": math.tan(math.radians(abs(peak_neg))),
        "vertical_share": stats["vertical_share"],
        "passes": worst <= TOLERANCE_DEG,
        "reads_as_legacy": abs(mean_abs - LEGACY_DEG) < abs(mean_abs - TARGET_DEG),
        "centers": centers,
        "hist": hist,
    }


def overlay(result: dict, out_path: Path) -> None:
    """Annotated proof card: measured axes drawn against the BG:EE target."""
    src = Image.open(result["path"]).convert("RGBA")
    card_w = 1200
    scale = card_w / src.width
    plate = src.resize((card_w, max(1, int(src.height * scale))), Image.Resampling.LANCZOS)
    header = 150
    card = Image.new("RGB", (card_w, plate.height + header), (16, 18, 24))
    card.paste(plate.convert("RGB"), (0, header))
    d = ImageDraw.Draw(card)

    name = result["path"].name
    verdict = "PASS" if result["passes"] else "FAIL"
    colour = (90, 210, 120) if result["passes"] else (230, 90, 80)
    d.text((18, 14), f"{name}", fill=(232, 232, 238))
    d.text((18, 34), f"measured ground axes: {result['peak_pos']:+.2f}  {result['peak_neg']:+.2f}", fill=(170, 180, 200))
    d.text((18, 52), f"target (BG:EE): +{TARGET_DEG:.2f} / -{TARGET_DEG:.2f}   slopes +-0.75", fill=(170, 180, 200))
    d.text((18, 70), f"worst delta: {result['worst_delta']:.2f} deg   tolerance {TOLERANCE_DEG:.1f}", fill=(170, 180, 200))
    d.text((18, 88), f"legacy camera would read {LEGACY_DEG:.2f}", fill=(140, 150, 170))
    d.text((18, 112), verdict, fill=colour)

    # Draw the measured axes and the target axes from a common origin.
    ox, oy = card_w // 2, header + plate.height // 2
    length = min(card_w, plate.height) * 0.28
    for ang, col, width in (
        (TARGET_DEG, (90, 210, 120), 2),
        (-TARGET_DEG, (90, 210, 120), 2),
        (result["peak_pos"], (245, 190, 70), 3),
        (result["peak_neg"], (245, 190, 70), 3),
    ):
        dx = length * math.cos(math.radians(ang))
        dy = -length * math.sin(math.radians(ang))
        d.line([(ox - dx, oy - dy), (ox + dx, oy + dy)], fill=col, width=width)
    d.text((ox + 8, oy + 8), "green = BG:EE target, amber = measured", fill=(200, 200, 210))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    card.save(out_path)


SHIPPED = [
    "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png",
    "RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png",
    "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_sable_row_block_v02.png",
    "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_wharf_ladder_block_v02.png",
    "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_riverside_block_v02.png",
    "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_harborpoint_pd_block_v02.png",
    "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_lila_street_block_v02.png",
    "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_civic_records_block_v02.png",
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("plates", nargs="*", type=Path)
    ap.add_argument("--shipped", action="store_true", help="grade the shipped area plates")
    ap.add_argument("--overlay-dir", type=Path, default=None)
    args = ap.parse_args()

    paths = [ROOT / p for p in SHIPPED] if args.shipped else list(args.plates)
    if not paths:
        ap.error("give plate paths or --shipped")

    print(f"BG:EE target ground axes +-{TARGET_DEG:.2f} deg (slopes +-0.75), tolerance {TOLERANCE_DEG:.1f}")
    print(f"{'plate':52s} {'+axis':>8s} {'-axis':>8s} {'worst':>7s} {'vert%':>6s}  verdict")
    failures = 0
    for path in paths:
        if not path.exists():
            print(f"{path.name:52s} {'MISSING':>8s}")
            failures += 1
            continue
        r = grade(path)
        tag = "PASS" if r["passes"] else ("FAIL (reads legacy)" if r["reads_as_legacy"] else "FAIL")
        if not r["passes"]:
            failures += 1
        print(
            f"{path.name:52s} {r['peak_pos']:+8.2f} {r['peak_neg']:+8.2f} "
            f"{r['worst_delta']:7.2f} {r['vertical_share'] * 100:5.1f}%  {tag}"
        )
        if args.overlay_dir:
            overlay(r, args.overlay_dir / f"{path.stem}_projection.png")

    print(f"\n{len(paths) - failures}/{len(paths)} plates on the BG:EE lock")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
