#!/usr/bin/env python3
"""Install idle + walk from SeatedMatch V2 Image Generator masters.

Craft path matches seated play-scale:
  extract → soften → V7 crunch → seated wardrobe lock → atlas

V2 shipping rules (vs V1):
  - Prefer v5 masters; fall through older only if coat/lum gates pass.
  - Hard-fail walk dirs that cannot pass L/R + coat gates (no dark backup ship).
  - After idle install, wardrobe-match stand_up_*_11 / sit_down_*_00 toward
    direction-matched standing idle so sit→stand handoff does not pop.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import process_pre_rendered_characters_v3 as raster  # noqa: E402
import crunch as crunch_mod  # noqa: E402
import process_voss_desk_ne_v01 as ne  # noqa: E402
from compose_chroma_strip_v11 import compose  # noqa: E402
from craft_compare_voss_walk_v12 import evaluate_cell, write_craft_strip  # noqa: E402
from process_pre_rendered_characters_v7 import pixelize_figure_v7  # noqa: E402
from process_pre_rendered_characters_v12 import (  # noqa: E402
    DETECTIVE_SOURCE,
    _coat_roi_mask,
    _face_roi_mask,
    _match_region,
    install_locked_frame_v12,
    soften_for_paperdoll_craft,
)
from qa_voss_walk_gait_v12 import foot_lead as _foot_lead_strict  # noqa: E402

raster.pixelize_figure = pixelize_figure_v7


def foot_lead(im: Image.Image) -> str:
    """Screen-space planted-foot lead; more sensitive than gait QA (= within 2px)."""
    a = np.asarray(im.convert("RGBA"))
    mask = a[..., 3] > 10
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return "?"
    y1 = int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    mid = (x0 + x1) // 2
    h = int(ys.max() - ys.min() + 1)
    band = mask.copy()
    band[: y1 - max(6, int(h * 0.14)), :] = False
    bl = band.copy()
    bl[:, mid:] = False
    br = band.copy()
    br[:, :mid] = False
    ly = int(np.where(bl)[0].max()) if bl.any() else -1
    ry = int(np.where(br)[0].max()) if br.any() else -1
    if ly < 0 and ry < 0:
        return _foot_lead_strict(im)
    if ly < 0:
        return "R"
    if ry < 0:
        return "L"
    if ly > ry:
        return "L"
    if ry > ly:
        return "R"
    return "L" if int(bl.sum()) >= int(br.sum()) else "R"

SM = DETECTIVE_SOURCE / "SeatedMatchV1"
GEN = SM / "Gen"
QA = SM / "QA"
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"
ATLAS_IDLE = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas"
ATLAS_WALK = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossWalk.atlas"
ATLAS_TRANS = ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatTransitions.atlas"
SEATED = (
    ROOT / "RainShadow Shared/Resources/Art/Atlases/VossSeatedIdle.atlas/voss_seated_idle_ne_00.png"
)
FRAMES = DETECTIVE_SOURCE / "Frames"

DIRS = ("s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n")
GREEN = (0, 255, 0)

# Exact seated NE00 midcoat (muted warm brown — not orange khaki, not cobalt pants).
SEATED_COAT = np.array([115.1, 78.0, 42.3], dtype=np.float32)
SEATED_COAT_CHROMA = np.array([115.1, 78.0, 42.3], dtype=np.float32)
SEATED_COAT_UPPER_LUM = 105.0  # seated-like; kills yellow shoulder glow
SEATED_COAT_LOWER_LUM = 72.0
SEATED_FACE = np.array([155.0, 110.0, 68.0], dtype=np.float32)
SEATED_HAIR = np.array([105.8, 73.6, 41.0], dtype=np.float32)
# Seated cool-leg sample — slight navy, not bright cobalt ankle bands.
SEATED_PANTS = np.array([44.0, 36.0, 42.0], dtype=np.float32)
SEATED_BODY_LUM = 68.4
SEATED_COAT_GR = float(SEATED_COAT_CHROMA[1] / SEATED_COAT_CHROMA[0])  # ~0.678
SEATED_COAT_BR = float(SEATED_COAT_CHROMA[2] / SEATED_COAT_CHROMA[0])  # ~0.367
COAT_L2_MAX = 12.0
LUM_DRIFT_MAX = 9.0
CYCLE_COAT_L2_MAX = 12.0
REJECTED = SM / "RejectedSeated"


def is_green(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (g > 140) & (g > r + 40) & (g > b + 40)


def standing_pose_score(fig: Image.Image) -> tuple[int, dict[str, float]]:
    """Score upright standing vs seated desk pose. Seated refs score <= 0."""
    px = np.asarray(fig.convert("RGBA"))
    a = px[..., 3] > 10
    if not a.any():
        return -99, {}
    ys, xs = np.where(a)
    h = int(ys.max() - ys.min() + 1)
    w = int(xs.max() - xs.min() + 1)
    aspect = w / max(h, 1)
    rows = a.sum(axis=1).astype(np.float32)
    cum = np.cumsum(rows) / max(float(rows.sum()), 1.0)
    mid = float(np.searchsorted(cum, 0.5) / max(a.shape[0], 1))
    lower_mass = float(rows[int(a.shape[0] * 0.45) :].sum() / max(float(rows.sum()), 1.0))
    score = 0
    score += 2 if aspect < 0.55 else (-2 if aspect > 0.72 else 0)
    score += 2 if mid < 0.52 else (-2 if mid > 0.58 else 0)
    score += 1 if lower_mass < 0.62 else (-1 if lower_mass > 0.70 else 0)
    info = {
        "aspect": float(aspect),
        "mid": mid,
        "lower_mass": lower_mass,
        "h": float(h),
        "w": float(w),
    }
    return score, info


def is_standing_figure(fig: Image.Image) -> bool:
    score, info = standing_pose_score(fig)
    if score < 2:
        print(f"  reject seated/non-standing pose score={score} {info}")
        return False
    return True


def quarantine(path: Path, reason: str) -> None:
    REJECTED.mkdir(parents=True, exist_ok=True)
    dest = REJECTED / path.name
    if path.resolve() == dest.resolve():
        return
    print(f"  quarantine {path.name}: {reason}")
    try:
        shutil.move(str(path), str(dest))
    except Exception:
        shutil.copy2(path, dest)


def collect() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)
    REJECTED.mkdir(parents=True, exist_ok=True)
    if not ASSETS.exists():
        return
    for ver in ("v6c", "v6b", "v6", "v5b", "v5", "v4b", "v4", "v3", "v2", "v1", "v1b"):
        for p in ASSETS.glob(f"voss_*_seatedmatch_{ver}_gen.png"):
            # Never pull files already quarantined.
            if (REJECTED / p.name).exists():
                continue
            shutil.copy2(p, GEN / p.name)


def cell_metrics(cell: Image.Image) -> dict[str, float]:
    px = np.asarray(cell.convert("RGBA"))
    mask = px[..., 3] > 40
    if not mask.any():
        return {"coat_l2": 999.0, "lum": 0.0, "height": 0.0}
    rgb = px[..., :3].astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    ys, xs = np.where(mask)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    h = y1 - y0 + 1
    coat = _band_mask(mask, y0, y1, x0, x1, 0.28, 0.72)
    shirtish = (r > 155) & (g > 145) & (b > 125) & (np.abs(r - g) < 30)
    # Score coat-like pixels only (ignore white shirt / skin in the gate band).
    coat &= ~shirtish
    coat &= (r > 48) & (b < r * 0.95) & (g < r * 1.05)
    if int(coat.sum()) < 20:
        coat = _band_mask(mask, y0, y1, x0, x1, 0.28, 0.72)
    coat_mean = rgb[coat].mean(axis=0) if coat.any() else rgb[mask].mean(axis=0)
    return {
        "coat_l2": float(np.linalg.norm(coat_mean - SEATED_COAT)),
        "lum": float(rgb[mask].mean()),
        "height": float(h),
    }


def passes_color_gates(cell: Image.Image, *, coat_max: float = COAT_L2_MAX) -> bool:
    m = cell_metrics(cell)
    ok = m["coat_l2"] <= coat_max and abs(m["lum"] - SEATED_BODY_LUM) <= LUM_DRIFT_MAX
    if not ok:
        print(
            f"  gate fail coat_l2={m['coat_l2']:.1f} lum={m['lum']:.1f} "
            f"(max coat {coat_max}, lum±{LUM_DRIFT_MAX} around {SEATED_BODY_LUM})"
        )
    return ok


def find_idle(direction: str) -> Path | None:
    for name in (
        f"voss_idle_{direction}_seatedmatch_v5b_gen.png",
        f"voss_idle_{direction}_seatedmatch_v5_gen.png",
        f"voss_idle_{direction}_seatedmatch_v4_gen.png",
        f"voss_idle_{direction}_seatedmatch_v3_gen.png",
        f"voss_idle_{direction}_seatedmatch_v2_gen.png",
        f"voss_idle_{direction}_seatedmatch_v1_gen.png",
    ):
        for folder in (GEN, ASSETS):
            p = folder / name
            if not p.exists() or (REJECTED / p.name).exists():
                continue
            try:
                fig = extract_figure(p)
            except Exception:
                continue
            if not is_standing_figure(fig):
                quarantine(p, "seated pose in idle master")
                continue
            return p
    return None


def find_walk_pair(direction: str) -> Path | None:
    """Prefer standing opposite-pair that survives as true L/R after craft lock."""
    candidates: list[Path] = []
    for name in (
        f"voss_walk_{direction}_opp_seatedmatch_v6_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v5b_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v5_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v4b_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v4_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v3_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v2_gen.png",
        f"voss_walk_{direction}_opp_seatedmatch_v1_gen.png",
    ):
        for folder in (GEN, ASSETS):
            p = folder / name
            if (
                p.exists()
                and p not in candidates
                and not (REJECTED / p.name).exists()
            ):
                candidates.append(p)

    best: Path | None = None
    best_score = -1.0
    for p in candidates:
        figs = split_pair(p)
        if len(figs) < 2:
            continue
        if not all(is_standing_figure(f) for f in figs[:2]):
            quarantine(p, "seated pose in walk opp pair")
            continue
        try:
            a = process_to_atlas_cell(figs[0])
            b = process_to_atlas_cell(figs[1])
        except Exception:
            continue
        leads = {foot_lead(a), foot_lead(b)}
        score = 3.0 if leads == {"L", "R"} else 0.0
        # Prefer color-gate passers, but still accept L/R pairs that are slightly bright
        # (final cycle lock + lum trim can recover walk_s).
        if passes_color_gates(a) and passes_color_gates(b):
            score += 1.0
        elif abs(cell_metrics(a)["lum"] - SEATED_BODY_LUM) < 12 and abs(
            cell_metrics(b)["lum"] - SEATED_BODY_LUM
        ) < 12:
            score += 0.25
        else:
            score = 0.0
        if "v6" in p.name:
            score += 0.45
        elif "v5b" in p.name:
            score += 0.35
        elif "v5" in p.name:
            score += 0.3
        elif "v4b" in p.name:
            score += 0.2
        elif "v4" in p.name:
            score += 0.15
        if score > best_score:
            best_score = score
            best = p
    if best is not None and best_score >= 3.0:
        return best
    return None


def extract_figure(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    px = np.asarray(im).copy()
    if px[..., 3].min() > 250:
        rgb = np.asarray(Image.open(path).convert("RGB"))
        green = is_green(rgb.astype(np.int16))
        px = np.dstack([rgb, np.where(green, 0, 255).astype(np.uint8)])
    else:
        green = is_green(px[..., :3].astype(np.int16))
        px[green, 3] = 0
    px[px[..., 3] < 8] = 0
    labels, n = ndimage.label(px[..., 3] > 10)
    if n > 1:
        keep = 1 + int(np.argmax([(labels == k).sum() for k in range(1, n + 1)]))
        px[labels != keep] = 0
    fig = Image.fromarray(px, "RGBA")
    bbox = fig.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"empty {path}")
    return fig.crop(bbox)


def split_pair(path: Path) -> list[Image.Image]:
    im = Image.open(path).convert("RGB")
    a = np.asarray(im)
    a = a[int(a.shape[0] * 0.06) :]
    w = a.shape[1] // 2
    figs: list[Image.Image] = []
    for i in range(2):
        cell = a[:, i * w : (i + 1) * w]
        m = ~is_green(cell.astype(np.int16))
        labels, n = ndimage.label(m)
        if not n:
            continue
        keep = 1 + int(np.argmax([(labels == k).sum() for k in range(1, n + 1)]))
        m = labels == keep
        ys, xs = np.where(m)
        if len(xs) < 40:
            continue
        rgb = cell[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
        alpha = np.where(
            m[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1], 255, 0
        ).astype(np.uint8)
        green = is_green(rgb.astype(np.int16))
        alpha[green] = 0
        fig = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
        bbox = fig.getchannel("A").getbbox()
        if bbox:
            figs.append(fig.crop(bbox))
    return figs


def _band_mask(
    mask: np.ndarray, y0: int, y1: int, x0: int, x1: int, lo: float, hi: float
) -> np.ndarray:
    h = max(1, y1 - y0 + 1)
    out = np.zeros_like(mask)
    out[y0 + int(h * lo) : y0 + int(h * hi), x0 : x1 + 1] = mask[
        y0 + int(h * lo) : y0 + int(h * hi), x0 : x1 + 1
    ]
    return out


def _stamp_seated_coat_chroma(
    r: np.ndarray,
    g: np.ndarray,
    b: np.ndarray,
    coat_full: np.ndarray,
    y0: int,
    h: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Replace coat hue with seated mid chroma; keep nearly all fold luminance."""
    if int(coat_full.sum()) < 30:
        return r, g, b
    stacked = np.stack([r, g, b], axis=-1)
    pix_lum = stacked.mean(axis=-1, keepdims=True)
    # Soft vertical luminance nudge only (not a flat envelope — that killed hem detail).
    yy = np.arange(stacked.shape[0], dtype=np.float32)[:, None]
    t = np.clip((yy - (y0 + 0.14 * h)) / max(1.0, 0.76 * h), 0.0, 1.0)
    target_row = (1.0 - t) * SEATED_COAT_UPPER_LUM + t * SEATED_COAT_LOWER_LUM
    # Per-row mean lum → mild pull toward seated gradient (preserves folds).
    fold_lum = pix_lum.copy()
    for yi in range(stacked.shape[0]):
        m = coat_full[yi]
        if int(m.sum()) < 8:
            continue
        cur = float(pix_lum[yi][m].mean())
        tgt = float(target_row[yi, 0])
        delta = (tgt - cur) * 0.22
        fold_lum[yi, m] = np.clip(pix_lum[yi, m] + delta, 18, 160)

    # Cap highlights hard — standing was reading orange/glowy vs muted seated.
    hot = coat_full[..., None] & (fold_lum > 108)
    fold_lum = np.where(hot, 108.0 - (fold_lum - 108) * 0.55, fold_lum)
    fold_lum = np.clip(fold_lum, 18, 110)

    chroma = SEATED_COAT_CHROMA / (float(SEATED_COAT_CHROMA.mean()) + 1e-5)
    remapped = chroma * fold_lum
    stacked = np.where(coat_full[..., None], np.clip(remapped, 0, 255), stacked)
    r, g, b = stacked[..., 0], stacked[..., 1], stacked[..., 2]
    g = np.where(coat_full, np.clip(r * SEATED_COAT_GR, 0, 255), g)
    b = np.where(coat_full, np.clip(r * SEATED_COAT_BR, 0, 255), b)
    return r, g, b


def _stamp_region_chroma(
    r: np.ndarray,
    g: np.ndarray,
    b: np.ndarray,
    region: np.ndarray,
    target: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Keep local luminance; force target RGB ratios on region."""
    if int(region.sum()) < 8:
        return r, g, b
    stacked = np.stack([r, g, b], axis=-1)
    pix_lum = stacked.mean(axis=-1, keepdims=True)
    chroma = target / (float(target.mean()) + 1e-5)
    remapped = chroma * pix_lum
    stacked = np.where(region[..., None], np.clip(remapped, 0, 255), stacked)
    return stacked[..., 0], stacked[..., 1], stacked[..., 2]


def seated_authority_lock(
    figure: Image.Image, *, exposure: float = 1.0
) -> Image.Image:
    """Hold a cell to the seated NE00 grade without flattening its wardrobe.

    This lock was written for masters that arrive monochrome and inconsistent —
    olive scalps, mustard shoulder yokes, muddy walk coats — and it fixes them by
    stamping the seated coat's chroma ratio across 10-86% of the body, clamping
    G <= R x 0.68 globally, and deleting any pixel that reads green. That is
    effective on flat masters and fatal to a real wardrobe: it would erase a
    #364636 tie outright and turn charcoal trousers brown.

    So the chroma-replacing passes now run only when the frame has nothing worth
    preserving. `crunch.has_material_separation` decides, calibrated against the
    BG:EE references. Luminance/exposure matching and the chroma-key fringe
    cleanup are always safe and always run.
    """
    separated = crunch_mod.has_material_separation(figure)
    px = np.asarray(figure.convert("RGBA")).copy()
    rgb = px[..., :3].astype(np.float32)
    a = px[..., 3].astype(np.float32)
    mask = a > 40
    if not mask.any():
        return ne.lock_atlas_canvas(figure.convert("RGBA"))

    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (r + g + b) / 3.0
    lit = mask & (lum > 18)

    box = np.where(mask)
    y0, y1 = int(box[0].min()), int(box[0].max())
    x0, x1 = int(box[1].min()), int(box[1].max())
    h = max(1, y1 - y0)

    head_band = _band_mask(mask, y0, y1, x0, x1, 0.0, 0.20)
    # Skin = warm face/ears only (high lum). Olive hair must NOT count as face.
    skinish = (
        (r > 120)
        & (g > 80)
        & (b > 45)
        & (g < r * 0.88)
        & (b < r * 0.58)
        & (lum > 90)
        & (lum < 230)
    )
    face_m = ((_face_roi_mask(mask) & head_band) | (head_band & skinish)) & lit & mask
    # Hair / olive scalp / walk_n mustard yoke in head band.
    hair_m = head_band & lit & ~face_m & (lum > 18) & (lum < 160)
    hair_m &= (b < r * 0.70) & (g < r * 1.15)

    coat_band = _band_mask(mask, y0, y1, x0, x1, 0.10, 0.86) & lit & ~face_m
    shirtish = (r > 155) & (g > 145) & (b > 125) & (np.abs(r - g) < 30)
    coat_full = coat_band & ~shirtish & ~hair_m & (lum > 16) & (lum < 220) & (b < r * 1.05)
    coat_full &= ~((lum < 70) & (b + 4 >= g) & (r < 85) & _band_mask(mask, y0, y1, x0, x1, 0.70, 0.86))
    # Olive shoulder/yoke pixels that sat in head band → treat as coat too.
    yoke = head_band & lit & ~face_m & (lum > 50) & (r > 70) & (b < r * 0.50) & (g > r * 0.65)
    coat_full |= yoke
    hair_m &= ~coat_full

    # Face: chroma + mild lift for muddy walk_s (keep body lum near seated).
    r, g, b = _match_region(
        r, g, b, face_m, SEATED_FACE, scale_lo=0.85, scale_hi=1.35, chroma_boost=1.0,
        luminance_only=separated,
    )
    if face_m.any():
        face_lum = float(((r + g + b) / 3.0)[face_m].mean())
        if face_lum < 115:
            boost = float(np.clip(125.0 / max(face_lum, 1.0), 1.0, 1.18))
            r = np.where(face_m, np.clip(r * boost, 0, 255), r)
            g = np.where(face_m, np.clip(g * boost, 0, 255), g)
            b = np.where(face_m, np.clip(b * boost, 0, 255), b)
        if not separated:
            r, g, b = _stamp_region_chroma(r, g, b, face_m, SEATED_FACE)
            g = np.where(face_m & (g > r * 0.82), r * 0.78, g)

    if not separated:
        # Hair: kill walk_n olive scalp (g/r was ~0.81).
        r, g, b = _stamp_region_chroma(r, g, b, hair_m, SEATED_HAIR)
        g = np.where(hair_m & (g > r * 0.72), r * 0.70, g)

        r, g, b = _stamp_seated_coat_chroma(r, g, b, coat_full, y0, h)

    pant_band = _band_mask(mask, y0, y1, x0, x1, 0.78, 0.98)
    if not separated:
        # Global olive kill on anything still too green (coat leftovers, vest
        # edges). Far too broad to survive a wardrobe: it clamps the whole figure
        # onto one hue, and an olive overcoat and green tie are legitimately green.
        olive = mask & ~pant_band & (g > r * 0.70) & (lum > 25) & (lum < 190)
        g = np.where(olive, np.minimum(g, r * 0.68), g)
        # This one specifically destroys a mustard waistcoat.
        yellow = mask & ~pant_band & ~face_m & (r > 95) & (g > 70) & (b < r * 0.34)
        b = np.where(yellow, np.minimum(255, r * SEATED_COAT_BR), b)
        g = np.where(yellow, np.minimum(g, r * SEATED_COAT_GR), g)

    pant_m = pant_band & ~face_m & ~coat_full
    pant_m &= ~((r > g + 10) & (r > b + 14) & (r > 75))
    pant_m &= (r + g + b) / 3.0 < 100
    if int(pant_m.sum()) >= 8 and not separated:
        stacked = np.stack([r, g, b], axis=-1)
        pl = stacked.mean(axis=-1, keepdims=True) + 1e-5
        navy = SEATED_PANTS * (pl / float(SEATED_PANTS.mean()))
        stacked = np.where(
            pant_m[..., None],
            np.clip(navy * 0.92 + stacked * 0.08, 0, 255),
            stacked,
        )
        r, g, b = stacked[..., 0], stacked[..., 1], stacked[..., 2]

    edge = mask & ~ndimage.binary_erosion(mask, iterations=2)
    # Chroma-key spill cleanup. The thresholds are deliberately tight on a flat
    # master, where nothing on Voss is legitimately green — but a dark green tie
    # or an olive coat trips `g > r + 6` at the silhouette, so with a wardrobe
    # present only true key spill (as green as `_is_chroma_green` looks for) is
    # culled.
    spill_margin = 40 if separated else 6
    fringe = edge & (g > r + spill_margin) & (g > b + spill_margin)
    shoe_green = (
        _band_mask(mask, y0, y1, x0, x1, 0.88, 1.0)
        & (g > r + (spill_margin if separated else 12))
        & (g > b + (spill_margin if separated else 8))
        & (g > 60)
    )
    kill = fringe | shoe_green
    if kill.any():
        a = np.where(kill, 0, a)
        mask = a > 40
        coat_full &= mask
        hair_m &= mask
        face_m &= mask

    if exposure != 1.0:
        r = np.where(mask, r * exposure, r)
        g = np.where(mask, g * exposure, g)
        b = np.where(mask, b * exposure, b)

    # Re-apply wardrobe chroma (ratios only — luminance fixed in final body-lum pass).
    if not separated:
        r, g, b = _stamp_region_chroma(r, g, b, face_m, SEATED_FACE)
        r, g, b = _stamp_region_chroma(r, g, b, hair_m, SEATED_HAIR)
        r, g, b = _stamp_seated_coat_chroma(r, g, b, coat_full, y0, h)
    gate = _band_mask(coat_full, y0, y1, x0, x1, 0.28, 0.72)
    if int(gate.sum()) >= 20 and not separated:
        stacked = np.stack([r, g, b], axis=-1)
        # Match chroma/mean gently without brightening whole body.
        cur_gate = stacked[gate].mean(axis=0)
        # Preserve gate luminance; only nudge chromaticity toward seated.
        cur_lum = float(cur_gate.mean()) + 1e-5
        target = SEATED_COAT * (cur_lum / float(SEATED_COAT.mean()))
        delta = (target - cur_gate) * 0.85
        stacked = np.where(
            coat_full[..., None], np.clip(stacked + delta, 0, 255), stacked
        )
        r, g, b = stacked[..., 0], stacked[..., 1], stacked[..., 2]

    if int(pant_m.sum()) >= 8 and not separated:
        stacked = np.stack([r, g, b], axis=-1)
        pl = stacked.mean(axis=-1, keepdims=True) + 1e-5
        navy = SEATED_PANTS * (pl / float(SEATED_PANTS.mean()))
        stacked = np.where(
            pant_m[..., None],
            np.clip(navy * 0.94 + stacked * 0.06, 0, 255),
            stacked,
        )
        r, g, b = stacked[..., 0], stacked[..., 1], stacked[..., 2]

    if not separated:
        # Final olive sweep — the single most destructive line for a wardrobe:
        # it clamps G under R x 0.68 across the whole body, so an olive overcoat
        # and a green tie both turn brown.
        lum = (r + g + b) / 3.0
        olive2 = mask & ~pant_m & (g > r * 0.72) & (lum > 30) & (lum < 180)
        g = np.where(olive2, np.minimum(g, r * 0.68), g)

    # Body-lum on non-coat first (scaling coat undoes seated coat snap).
    noncoat = mask & ~coat_full
    if noncoat.any():
        cur_nc = float(np.stack([r, g, b], -1)[noncoat].mean())
        # Aim non-coat so overall body lands near seated.
        cur_all = float(np.stack([r, g, b], -1)[mask].mean())
        if cur_all > 1:
            scale = float(np.clip(SEATED_BODY_LUM / cur_all, 0.85, 1.10))
            # Prefer scaling non-coat; mild scale on coat.
            r = np.where(noncoat, r * scale, r)
            g = np.where(noncoat, g * scale, g)
            b = np.where(noncoat, b * scale, b)
            r = np.where(coat_full, r * (0.5 + 0.5 * scale), r)
            g = np.where(coat_full, g * (0.5 + 0.5 * scale), g)
            b = np.where(coat_full, b * (0.5 + 0.5 * scale), b)

    # Coat snap AFTER lum — exact seated midcoat (ratios + mean). This block runs
    # last and overrides everything before it, so it is the dominant flattener:
    # with a wardrobe present it alone took hue spread from 0.345 back to 0.03.
    if not separated:
        r, g, b = _stamp_seated_coat_chroma(r, g, b, coat_full, y0, h)
        r, g, b = _stamp_region_chroma(r, g, b, hair_m, SEATED_HAIR)
        r, g, b = _stamp_region_chroma(r, g, b, face_m, SEATED_FACE)
        gate = _band_mask(coat_full, y0, y1, x0, x1, 0.28, 0.72)
        if int(gate.sum()) >= 20:
            stacked = np.stack([r, g, b], axis=-1)
            delta = SEATED_COAT - stacked[gate].mean(axis=0)
            stacked = np.where(
                coat_full[..., None], np.clip(stacked + delta, 0, 255), stacked
            )
            r, g, b = stacked[..., 0], stacked[..., 1], stacked[..., 2]

    # Soft overall lum trim if coat snap pushed body bright (keep coat chroma).
    cur = float(np.stack([r, g, b], -1)[mask].mean())
    if cur > SEATED_BODY_LUM + 3:
        scale = float(np.clip(SEATED_BODY_LUM / cur, 0.86, 1.0))
        adj = mask & ~coat_full & ~face_m
        r = np.where(adj, r * scale, r)
        g = np.where(adj, g * scale, g)
        b = np.where(adj, b * scale, b)
        # Mild coat pull so walk_s (bright shirt) still clears lum gate.
        r = np.where(coat_full, r * (0.65 + 0.35 * scale), r)
        g = np.where(coat_full, g * (0.65 + 0.35 * scale), g)
        b = np.where(coat_full, b * (0.65 + 0.35 * scale), b)
        if not separated:
            g = np.where(coat_full, np.clip(r * SEATED_COAT_GR, 0, 255), g)
            b = np.where(coat_full, np.clip(r * SEATED_COAT_BR, 0, 255), b)

    # Mild face lift AFTER lum trim (walk_s muddy faces) — chroma first, tiny lift.
    if face_m.any():
        if not separated:
            r, g, b = _stamp_region_chroma(r, g, b, face_m, SEATED_FACE)
            g = np.where(face_m & (g > r * 0.82), r * 0.78, g)
        face_lum = float(((r + g + b) / 3.0)[face_m].mean())
        body = float(np.stack([r, g, b], -1)[mask].mean())
        if face_lum < 105 and body < SEATED_BODY_LUM + 6:
            boost = float(np.clip(112.0 / max(face_lum, 1.0), 1.0, 1.10))
            r = np.where(face_m, np.clip(r * boost, 0, 255), r)
            g = np.where(face_m, np.clip(g * boost, 0, 255), g)
            b = np.where(face_m, np.clip(b * boost, 0, 255), b)

    out = np.stack([r, g, b, a], axis=-1)
    out[out[..., 3] < 8] = 0
    return ne.lock_atlas_canvas(
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    )


def process_to_atlas_cell(fig: Image.Image, *, re_register: bool = True) -> Image.Image:
    # Milder soften than V1 so seated play detail survives crunch.
    soft = soften_for_paperdoll_craft(fig, radius=2.6 if re_register else 1.4)
    arr = np.asarray(soft.convert("RGBA")).astype(np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3:4] / 255.0
    body = alpha > 0.15
    if body.any():
        mean = (rgb * alpha).sum(axis=(0, 1), keepdims=True) / (
            alpha.sum(axis=(0, 1), keepdims=True) + 1e-5
        )
        # Keep more local color so seated lock has signal (was muddying toward olive mean).
        rgb = np.where(body, mean + (rgb - mean) * (0.88 if re_register else 0.94), rgb)
    arr[..., :3] = np.clip(rgb, 0, 255)
    soft = Image.fromarray(arr.astype(np.uint8), "RGBA")
    registered = raster.register(soft) if re_register else soft
    return seated_authority_lock(registered, exposure=1.0)


def bob_cell(cell: Image.Image, dy: int) -> Image.Image:
    a = np.asarray(cell.convert("RGBA"))
    out = np.zeros_like(a)
    if dy > 0:
        out[dy:] = a[:-dy]
    elif dy < 0:
        out[:dy] = a[-dy:]
    else:
        out = a.copy()
    return ne.lock_atlas_canvas(Image.fromarray(out, "RGBA"))


def slight_scale_fig(fig: Image.Image, s: float) -> Image.Image:
    return fig.resize(
        (max(1, int(fig.width * s)), max(1, int(fig.height * s))),
        Image.Resampling.LANCZOS,
    )


def save_chroma(cell: Image.Image, path: Path) -> None:
    arr = np.asarray(cell.convert("RGBA"))
    rgb = arr[..., :3].copy()
    rgb[arr[..., 3] < 10] = GREEN
    Image.fromarray(rgb, "RGB").save(path)


def install_idle_dir(direction: str) -> bool:
    path = find_idle(direction)
    if path is None:
        print(f"idle {direction}: HARD FAIL — missing standing gen (no backup ship)")
        return False

    print(f"idle {direction}: {path.name}")
    fig = extract_figure(path)
    if not is_standing_figure(fig):
        quarantine(path, "seated pose at idle install")
        print(f"idle {direction}: HARD FAIL — seated pose")
        return False
    base = process_to_atlas_cell(fig)
    # After V7, opaque height must remain standing-scale (~200), never seated (~155).
    m0 = cell_metrics(base)
    if m0["height"] < 185:
        quarantine(path, f"post-crunch height {m0['height']:.0f} looks seated")
        print(f"idle {direction}: HARD FAIL — post-crunch height {m0['height']:.0f}")
        return False
    if not passes_color_gates(base):
        print(f"idle {direction}: HARD FAIL — color gates")
        return False

    variants = [
        base,
        process_to_atlas_cell(slight_scale_fig(fig, 0.985)),
        bob_cell(base, 1),
        process_to_atlas_cell(slight_scale_fig(fig, 1.015)),
    ]
    for i, cell in enumerate(variants):
        install_locked_frame_v12(
            cell,
            "VossIdle.atlas",
            f"voss_standing_idle_{direction}_{i:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_chroma(cell, FRAMES / f"voss_idle_{direction}_{i:02d}_chroma_v12.png")
    paths = [FRAMES / f"voss_idle_{direction}_{i:02d}_chroma_v12.png" for i in range(4)]
    if all(p.exists() for p in paths):
        compose(
            paths,
            DETECTIVE_SOURCE / f"voss_idle_{direction}_strip_chroma_v12.png",
            4,
            1,
        )
    print(f"  {evaluate_cell(variants[0]).summary()}")
    m = cell_metrics(base)
    print(f"  metrics coat_l2={m['coat_l2']:.1f} lum={m['lum']:.1f} h={m['height']:.0f}")
    return True


def blend(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    aa = np.asarray(a.convert("RGBA")).astype(np.float32)
    bb = np.asarray(b.convert("RGBA")).astype(np.float32)
    return ne.lock_atlas_canvas(
        Image.fromarray(np.clip(aa * (1 - t) + bb * t, 0, 255).astype(np.uint8), "RGBA")
    )


def find_walk_singles(direction: str) -> tuple[Path, Path] | None:
    naming = [
        (
            f"voss_walk_{direction}_r_seatedmatch_v6_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v6c_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v6b_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v6_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v6_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v6b_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v6b_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v6b_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v6_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v6_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v5b_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v5b_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v5_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v5_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v4_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v5_gen.png",
        ),
        (
            f"voss_walk_{direction}_r_seatedmatch_v4_gen.png",
            f"voss_walk_{direction}_l_seatedmatch_v4_gen.png",
        ),
        (
            f"voss_walk_{direction}_oppA_seatedmatch_v5_gen.png",
            f"voss_walk_{direction}_oppB_seatedmatch_v5_gen.png",
        ),
        (
            f"voss_walk_{direction}_fwd_seatedmatch_v5_gen.png",
            f"voss_walk_{direction}_back_seatedmatch_v5_gen.png",
        ),
        (
            f"voss_walk_{direction}_fwd_seatedmatch_v4_gen.png",
            f"voss_walk_{direction}_back_seatedmatch_v4_gen.png",
        ),
    ]
    for a_name, b_name in naming:
        a = b = None
        for folder in (GEN, ASSETS):
            pa, pb = folder / a_name, folder / b_name
            if pa.exists() and not (REJECTED / pa.name).exists():
                a = pa
            if pb.exists() and not (REJECTED / pb.name).exists():
                b = pb
        if a and b:
            try:
                fa, fb = extract_figure(a), extract_figure(b)
            except Exception:
                continue
            if not (is_standing_figure(fa) and is_standing_figure(fb)):
                quarantine(a, "seated pose in walk single")
                quarantine(b, "seated pose in walk single")
                continue
            return a, b
    return None


def install_cycle_from_contacts(
    direction: str, fig_a: Image.Image, fig_b: Image.Image
) -> bool:
    if not (is_standing_figure(fig_a) and is_standing_figure(fig_b)):
        print("  reject — contacts include seated pose")
        return False
    a = process_to_atlas_cell(fig_a)
    b = process_to_atlas_cell(fig_b)
    la, lb = foot_lead(a), foot_lead(b)
    print(f"  leads {la}/{lb}")
    if {la, lb} == {"L", "R"}:
        r = a if la == "R" else b
        l = a if la == "L" else b
        r_src = fig_a if la == "R" else fig_b
        l_src = fig_a if la == "L" else fig_b
    else:
        print("  reject — contacts are not L/R opposite")
        return False

    if not (passes_color_gates(r) and passes_color_gates(l)):
        return False

    # Tiny pose variants without darkening (0.98 scale was dropping body lum ~8pts).
    r1 = process_to_atlas_cell(slight_scale_fig(r_src, 0.995))
    l1 = process_to_atlas_cell(slight_scale_fig(l_src, 0.995))
    if not passes_color_gates(r1):
        r1 = seated_authority_lock(r, exposure=1.03)
    if not passes_color_gates(l1):
        l1 = seated_authority_lock(l, exposure=1.03)
    def clean_blend(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
        """Alpha-aware blend + seated re-lock so mid frames stay seated-matched."""
        aa = np.asarray(a.convert("RGBA")).astype(np.float32)
        bb = np.asarray(b.convert("RGBA")).astype(np.float32)
        am = aa[..., 3:4] / 255.0
        bm = bb[..., 3:4] / 255.0
        w = am * (1.0 - t) + bm * t
        rgb = np.zeros_like(aa[..., :3])
        ok = w[..., 0] > 0.05
        num = aa[..., :3] * (am * (1.0 - t)) + bb[..., :3] * (bm * t)
        rgb[ok] = num[ok] / np.maximum(w[ok], 1e-3)
        out = np.dstack([rgb, np.clip(w[..., 0] * 255.0, 0, 255)])
        out[out[..., 3] < 40] = 0
        # The weighted alpha is soft wherever the two silhouettes disagree, which
        # would put V14's 1-bit contract back to ~50% opaque on frames 02 and 06.
        blended = crunch_mod.harden_alpha(
            Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
        )
        return seated_authority_lock(blended, exposure=1.0)

    mid_rl = clean_blend(r, l, 0.2)
    mid_lr = clean_blend(l, r, 0.2)
    cycle = [
        r,
        r1,
        mid_rl,
        bob_cell(r, 1),
        l,
        l1,
        mid_lr,
        bob_cell(l, 1),
    ]
    cycle_leads = "".join(foot_lead(c) for c in cycle)
    # Gate coat/lum on every frame after re-lock — standing must match seated.
    for i, c in enumerate(cycle):
        m = cell_metrics(c)
        if m["height"] < 185:
            print(f"  [{i}] reject seated-scale height={m['height']:.0f}")
            return False
        if m["coat_l2"] > CYCLE_COAT_L2_MAX + 4:
            print(f"  [{i}] reject coat_l2={m['coat_l2']:.1f}")
            return False
        if abs(m["lum"] - SEATED_BODY_LUM) > LUM_DRIFT_MAX:
            print(f"  [{i}] reject lum={m['lum']:.1f}")
            return False
    if "L" not in cycle_leads or "R" not in cycle_leads:
        print(f"  reject gait (leads={cycle_leads})")
        return False

    for i, cell in enumerate(cycle):
        install_locked_frame_v12(
            cell,
            "VossWalk.atlas",
            f"voss_walk_{direction}_{i:02d}.png",
            DETECTIVE_SOURCE,
        )
        save_chroma(cell, FRAMES / f"voss_walk_{direction}_{i:02d}_chroma_v12.png")
    print(f"  ACCEPT leads={cycle_leads}")
    return True


def install_walk_dir(direction: str) -> bool:
    # Prefer authored R/L singles (v6+) before older opp plates.
    singles = find_walk_singles(direction)
    if singles is not None:
        print(f"walk {direction}: singles {singles[0].name} + {singles[1].name}")
        try:
            fa = extract_figure(singles[0])
            fb = extract_figure(singles[1])
        except Exception as exc:
            print(f"  single extract failed: {exc}")
        else:
            if install_cycle_from_contacts(direction, fa, fb):
                return True
        print("  singles rejected — try opp pair")

    path = find_walk_pair(direction)
    if path is not None:
        print(f"walk {direction}: {path.name}")
        figs = split_pair(path)
        if len(figs) >= 2 and install_cycle_from_contacts(direction, figs[0], figs[1]):
            return True
        print("  pair rejected")

    print(f"walk {direction}: HARD FAIL — no gated master (refusing dark backup)")
    return False


def mirror_se_idle_from_sw() -> None:
    for i in range(4):
        sw = ATLAS_IDLE / f"voss_standing_idle_sw_{i:02d}.png"
        if not sw.exists():
            continue
        im = Image.open(sw).convert("RGBA")
        flipped = ne.lock_atlas_canvas(im.transpose(Image.Transpose.FLIP_LEFT_RIGHT))
        install_locked_frame_v12(
            flipped,
            "VossIdle.atlas",
            f"voss_standing_idle_se_{i:02d}.png",
            DETECTIVE_SOURCE,
        )


def wardrobe_match_to_idle(src: Image.Image, idle: Image.Image) -> Image.Image:
    """Pull transition endpoint colors toward standing idle without re-crunch."""
    px = np.asarray(src.convert("RGBA")).copy()
    id_px = np.asarray(idle.convert("RGBA"))
    mask = px[..., 3] > 40
    id_mask = id_px[..., 3] > 40
    if not mask.any() or not id_mask.any():
        return src
    target = id_px[..., :3][id_mask].astype(np.float32).mean(axis=0)
    rgb = px[..., :3].astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (r + g + b) / 3.0
    lit = mask & (lum > 18)
    coat_m = _coat_roi_mask(mask) & lit
    face_m = _face_roi_mask(mask) & lit
    # Match coat toward idle coat band
    id_ys, id_xs = np.where(id_mask)
    iy0, iy1 = int(id_ys.min()), int(id_ys.max())
    ix0, ix1 = int(id_xs.min()), int(id_xs.max())
    ih = iy1 - iy0 + 1
    id_coat = np.zeros_like(id_mask)
    id_coat[iy0 + int(ih * 0.28) : iy0 + int(ih * 0.72), ix0 : ix1 + 1] = id_mask[
        iy0 + int(ih * 0.28) : iy0 + int(ih * 0.72), ix0 : ix1 + 1
    ]
    coat_t = (
        id_px[..., :3][id_coat].astype(np.float32).mean(axis=0)
        if id_coat.any()
        else target
    )
    r, g, b = _match_region(
        r, g, b, coat_m, coat_t, scale_lo=0.85, scale_hi=1.35, chroma_boost=1.0
    )
    # Match the face toward the idle's *measured* face, the way the coat above is
    # matched toward the idle's measured coat. Targeting the frozen SEATED_FACE
    # constant instead left the handoff free to drift: under V14 the idle face
    # settles near 147/102/60 while the constant is 155/110/68, which showed up as
    # a visible face pop when stand-up ended and the idle clip took over.
    id_face = np.zeros_like(id_mask)
    id_face[iy0 : iy0 + int(ih * 0.30), ix0 : ix1 + 1] = id_mask[
        iy0 : iy0 + int(ih * 0.30), ix0 : ix1 + 1
    ]
    face_t = (
        id_px[..., :3][id_face].astype(np.float32).mean(axis=0)
        if int(id_face.sum()) >= 20
        else SEATED_FACE
    )
    r, g, b = _match_region(
        r, g, b, face_m, face_t, scale_lo=0.85, scale_hi=1.30, chroma_boost=1.0
    )
    # Mild global lum nudge toward idle body mean
    cur_lum = float(np.stack([r, g, b], -1)[mask].mean())
    id_lum = float(id_px[..., :3][id_mask].astype(np.float32).mean())
    if cur_lum > 1:
        scale = np.clip(id_lum / cur_lum, 0.90, 1.10)
        r = np.where(mask, r * scale, r)
        g = np.where(mask, g * scale, g)
        b = np.where(mask, b * scale, b)
    out = np.stack([r, g, b, px[..., 3]], axis=-1)
    matched = ne.lock_atlas_canvas(
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    )
    # Same seated wardrobe lock as idle/walk so stand_up_11 coat_l2 matches.
    locked = seated_authority_lock(matched, exposure=1.0)
    # Final additive snap of coat gate toward idle coat (kills residual handoff drift).
    lp = np.asarray(locked.convert("RGBA")).copy()
    ip = np.asarray(idle.convert("RGBA"))
    lm = lp[..., 3] > 40
    imask = ip[..., 3] > 40
    if lm.any() and imask.any():
        lys, lxs = np.where(lm)
        ly0, ly1 = int(lys.min()), int(lys.max())
        lx0, lx1 = int(lxs.min()), int(lxs.max())
        iys, ixs = np.where(imask)
        iy0, iy1 = int(iys.min()), int(iys.max())
        ix0, ix1 = int(ixs.min()), int(ixs.max())
        gate_l = _band_mask(lm, ly0, ly1, lx0, lx1, 0.28, 0.72)
        gate_i = _band_mask(imask, iy0, iy1, ix0, ix1, 0.28, 0.72)
        lr, lg, lb = (
            lp[..., 0].astype(np.float32),
            lp[..., 1].astype(np.float32),
            lp[..., 2].astype(np.float32),
        )
        shirtish = (lr > 155) & (lg > 145) & (lb > 125) & (np.abs(lr - lg) < 30)
        gate_l &= ~shirtish & (lr > 48) & (lb < lr * 0.95)
        if int(gate_l.sum()) >= 20 and int(gate_i.sum()) >= 20:
            delta = ip[..., :3][gate_i].astype(np.float32).mean(0) - np.stack(
                [lr, lg, lb], -1
            )[gate_l].mean(0)
            for i, ch in enumerate((lr, lg, lb)):
                vals = np.clip(ch + delta[i], 0, 255)
                if i == 0:
                    lr = np.where(gate_l, vals, ch)
                elif i == 1:
                    lg = np.where(gate_l, vals, ch)
                else:
                    lb = np.where(gate_l, vals, ch)
            lp[..., 0], lp[..., 1], lp[..., 2] = lr, lg, lb
            locked = ne.lock_atlas_canvas(
                Image.fromarray(np.clip(lp, 0, 255).astype(np.uint8), "RGBA")
            )

        # Close the residual on the head band too. seated_authority_lock above
        # pulls the head back toward the frozen seated grade, so the earlier
        # mean-match alone leaves the handoff outside its gate.
        #
        # This scales rather than adds. An additive delta lifts every pixel in
        # the band by the same amount — hair, collar and coat shoulders along
        # with skin — which flattened the head into a pale blob at 56 native
        # rows. A per-channel scale keeps the band's internal light/dark
        # structure while moving its mean.
        lp = np.asarray(locked.convert("RGBA")).copy()
        lm = lp[..., 3] > 40
        face_l = _face_roi_mask(lm) & lm
        face_i = _face_roi_mask(imask) & imask
        if int(face_l.sum()) >= 20 and int(face_i.sum()) >= 20:
            current = lp[..., :3][face_l].astype(np.float32).mean(0)
            target = ip[..., :3][face_i].astype(np.float32).mean(0)
            scale = np.clip(target / (current + 1e-5), 0.85, 1.20)
            for channel in range(3):
                values = np.clip(
                    lp[..., channel].astype(np.float32) * scale[channel], 0, 255
                )
                lp[..., channel] = np.where(face_l, values, lp[..., channel]).astype(np.uint8)
            locked = ne.lock_atlas_canvas(
                Image.fromarray(np.clip(lp, 0, 255).astype(np.uint8), "RGBA")
            )
    return locked


def lock_standup_handoff() -> None:
    """Re-lock stand_up frame 11 / sit_down frame 00 toward matched standing idle."""
    # NE seat chain hands off to NW idle; SE to SE idle (mirrored SW).
    mapping = (("ne", "nw"), ("se", "se"))
    for seat_dir, idle_dir in mapping:
        idle_path = ATLAS_IDLE / f"voss_standing_idle_{idle_dir}_00.png"
        stand_path = ATLAS_TRANS / f"voss_stand_up_{seat_dir}_11.png"
        sit_path = ATLAS_TRANS / f"voss_sit_down_{seat_dir}_00.png"
        if not idle_path.exists() or not stand_path.exists():
            print(f"handoff {seat_dir}: missing idle/stand — skip")
            continue
        idle = Image.open(idle_path).convert("RGBA")
        stand = Image.open(stand_path).convert("RGBA")
        locked = wardrobe_match_to_idle(stand, idle)
        # finalise=False: `stand` came off disk already palette-correct, and the
        # handoff match is a deliberate nudge on top of it. Re-ramping here would
        # pull the head band back onto the torso coat ramp and undo the match.
        install_locked_frame_v12(
            locked,
            "VossSeatTransitions.atlas",
            f"voss_stand_up_{seat_dir}_11.png",
            DETECTIVE_SOURCE,
            finalise=False,
        )
        # sit_down_00 is reverse of stand_up_11
        install_locked_frame_v12(
            locked,
            "VossSeatTransitions.atlas",
            f"voss_sit_down_{seat_dir}_00.png",
            DETECTIVE_SOURCE,
            finalise=False,
        )
        sm = cell_metrics(stand)
        lm = cell_metrics(locked)
        im = cell_metrics(idle)
        print(
            f"handoff {seat_dir}: stand11 lum {sm['lum']:.1f}→{lm['lum']:.1f} "
            f"(idle {im['lum']:.1f}) coat_l2 {sm['coat_l2']:.1f}→{lm['coat_l2']:.1f}"
        )
        if sit_path.exists():
            pass  # already written above


def write_qa() -> dict[str, object]:
    seated = Image.open(SEATED).convert("RGBA")
    cells = [
        ("seated", seated),
        ("idle_sw", Image.open(ATLAS_IDLE / "voss_standing_idle_sw_00.png")),
        ("idle_s", Image.open(ATLAS_IDLE / "voss_standing_idle_s_00.png")),
        ("idle_w", Image.open(ATLAS_IDLE / "voss_standing_idle_w_00.png")),
        ("walk_sw", Image.open(ATLAS_WALK / "voss_walk_sw_00.png")),
        ("walk_s", Image.open(ATLAS_WALK / "voss_walk_s_00.png")),
        ("walk_w", Image.open(ATLAS_WALK / "voss_walk_w_00.png")),
        ("walk_n", Image.open(ATLAS_WALK / "voss_walk_n_00.png")),
    ]
    write_craft_strip(
        QA / "seated_match_v2_final_compare.jpg",
        [c for _, c in cells],
        [n for n, _ in cells],
    )

    report: dict[str, object] = {"dirs": {}, "handoff": {}, "ok": True}
    for d in DIRS:
        idle_p = ATLAS_IDLE / f"voss_standing_idle_{d}_00.png"
        walk_p = ATLAS_WALK / f"voss_walk_{d}_00.png"
        entry: dict[str, object] = {}
        if idle_p.exists():
            m = cell_metrics(Image.open(idle_p))
            entry["idle"] = m
            if m["coat_l2"] > COAT_L2_MAX or abs(m["lum"] - SEATED_BODY_LUM) > LUM_DRIFT_MAX:
                report["ok"] = False
        if walk_p.exists():
            m = cell_metrics(Image.open(walk_p))
            leads = "".join(
                foot_lead(Image.open(ATLAS_WALK / f"voss_walk_{d}_{i:02d}.png"))
                for i in range(8)
            )
            entry["walk"] = m
            entry["leads"] = leads
            if (
                m["coat_l2"] > COAT_L2_MAX
                or abs(m["lum"] - SEATED_BODY_LUM) > LUM_DRIFT_MAX
                or ("L" not in leads or "R" not in leads)
            ):
                report["ok"] = False
        report["dirs"][d] = entry

    for seat_dir, idle_dir in (("ne", "nw"), ("se", "se")):
        stand = ATLAS_TRANS / f"voss_stand_up_{seat_dir}_11.png"
        idle = ATLAS_IDLE / f"voss_standing_idle_{idle_dir}_00.png"
        if stand.exists() and idle.exists():
            sm = cell_metrics(Image.open(stand))
            im = cell_metrics(Image.open(idle))
            report["handoff"][seat_dir] = {
                "stand_lum": sm["lum"],
                "idle_lum": im["lum"],
                "stand_coat_l2": sm["coat_l2"],
                "height_delta": abs(sm["height"] - im["height"]),
            }
            # Handoff coat scored vs seated target; allow a bit more slack than idle.
            if (
                abs(sm["lum"] - im["lum"]) > LUM_DRIFT_MAX
                or sm["coat_l2"] > COAT_L2_MAX + 4
                or abs(sm["height"] - im["height"]) > 2
            ):
                report["ok"] = False

    lines = ["# SeatedMatch V2 QA", ""]
    for d, entry in report["dirs"].items():  # type: ignore[union-attr]
        lines.append(f"## {d}")
        lines.append(f"- {entry}")
    lines.append("## handoff")
    lines.append(str(report["handoff"]))
    lines.append(f"\nOK={report['ok']}")
    (QA / "seated_match_v2_gates.txt").write_text("\n".join(lines) + "\n")
    return report


def main() -> int:
    collect()
    print(f"Gen has {len(list(GEN.glob('*seatedmatch_v5*')))} v5 masters")

    idle_ok: list[str] = []
    idle_fail: list[str] = []
    walk_ok: list[str] = []
    walk_fail: list[str] = []

    for d in DIRS:
        if install_idle_dir(d):
            idle_ok.append(d)
        else:
            idle_fail.append(d)
    mirror_se_idle_from_sw()

    for d in DIRS:
        if install_walk_dir(d):
            walk_ok.append(d)
        else:
            walk_fail.append(d)

    if idle_ok:
        lock_standup_handoff()

    report = write_qa()
    print("\n=== SUMMARY ===")
    print(f"idle ok: {idle_ok}")
    print(f"idle FAIL: {idle_fail}")
    print(f"walk ok: {walk_ok}")
    print(f"walk FAIL: {walk_fail}")
    print(f"QA: {QA / 'seated_match_v2_final_compare.jpg'}")
    print(f"gates OK={report['ok']}")
    if idle_fail or walk_fail or not report["ok"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
