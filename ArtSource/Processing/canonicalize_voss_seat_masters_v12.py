#!/usr/bin/env python3
"""Author geometrically coherent V12 chairless seat masters.

The runtime installers refuse per-frame stretch repair. This script is the
master-authoring step that replaces independently reframed AI cells with a
single camera/body scale:

- one seated neutral per direction (idle 00 / stand 00)
- idle 01-07 = constrained upper-body breathing edits of that neutral
- stand 01-10 = existing pose art, foot-anchored onto a shared height curve
- stand 11 = direction-matched standing idle source (NW for NE, SW-flip for SE)
- sit-down is produced later as the exact reverse by the installers

Outputs flat #00FF00 chroma PNGs the V12 desk processors already consume.
"""

from __future__ import annotations

from pathlib import Path
import math
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import process_voss_desk_ne_v01 as ne  # noqa: E402
from process_character_gait_v5 import remove_green_screen  # noqa: E402

V12 = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV12"
V12_NE = V12 / "DeskNE"
V12_FRAMES = V12 / "Frames"

# Fixed master camera. Standing endpoint maps to ~200px after the shared V7 scale.
CANVAS_W = 1024
CANVAS_H = 1536
FOOT_Y = 1420
STAND_H = 1200
# 0.775 * 1200 = 930 → 155px after 200/STAND_H shared scale.
SEATED_H = 930
# Total crown rise on the baked canvas should land near 45px (gate 38-50).
GREEN = (0, 255, 0)


def load_figure(path: Path) -> Image.Image:
    tmp = path.with_name(f".tmp_{path.stem}_rgba.png")
    remove_green_screen(path, tmp)
    figure = ne.trim_alpha(Image.open(tmp).convert("RGBA"), threshold=16)
    tmp.unlink(missing_ok=True)
    if figure.getchannel("A").getbbox() is None:
        raise RuntimeError(f"No figure in {path}")
    return figure


def opaque_mask(figure: Image.Image, threshold: int = 16) -> np.ndarray:
    return np.asarray(figure.convert("RGBA"))[..., 3] >= threshold


def head_width_of(figure: Image.Image) -> int:
    return ne.head_width(figure, threshold=16)


def resize_to_height(figure: Image.Image, target_h: int) -> Image.Image:
    target_h = max(8, int(target_h))
    scale = target_h / max(1, figure.height)
    target_w = max(1, int(round(figure.width * scale)))
    return figure.resize((target_w, target_h), Image.Resampling.LANCZOS)


def match_head_width(
    figure: Image.Image,
    target_head: int,
    tolerance_px: int = 2,
    max_iters: int = 6,
) -> Image.Image:
    """Match absolute head width by widening only the crown/upper band.

    Mid stand-up poses often put a profile skull into the top 10% band, so a
    full-body horizontal scale would fatten the coat. Local upper-band scale
    keeps pelvis/feet and body mass stable while the head gate stays honest.
    """
    if target_head <= 1:
        return figure
    body = figure.convert("RGBA")
    for _ in range(max_iters):
        current = head_width_of(body)
        if current <= 1:
            return body
        if abs(current - target_head) <= tolerance_px:
            return body
        ratio = float(np.clip(target_head / current, 0.85, 1.25))
        arr = np.asarray(body).copy()
        h, w = arr.shape[:2]
        # Upper third covers skull + hair without hauling the seat width around.
        split = max(1, int(h * 0.34))
        upper = Image.fromarray(arr[:split], "RGBA")
        lower = Image.fromarray(arr[split:], "RGBA")
        new_w = max(1, int(round(upper.width * ratio)))
        upper_r = upper.resize((new_w, upper.height), Image.Resampling.LANCZOS)
        out_w = max(w, new_w)
        out = Image.new("RGBA", (out_w, h), (0, 0, 0, 0))
        out.paste(lower, ((out_w - w) // 2, split), lower)
        out.alpha_composite(upper_r, ((out_w - new_w) // 2, 0))
        body = out
    return body


def blend_figures(a: Image.Image, b: Image.Image, t: float) -> Image.Image:
    """Alpha-aware blend on a shared foot-aligned canvas."""
    t = max(0.0, min(1.0, t))
    h = max(a.height, b.height)
    w = max(a.width, b.width)
    canvas_a = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas_b = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas_a.alpha_composite(a, ((w - a.width) // 2, h - a.height))
    canvas_b.alpha_composite(b, ((w - b.width) // 2, h - b.height))
    return Image.blend(canvas_a, canvas_b, t)


def place_on_green(figure: Image.Image, target_h: int, target_head: int | None = None) -> Image.Image:
    body = resize_to_height(figure, target_h)
    if target_head is not None:
        body = match_head_width(body, target_head)
        # Re-assert height after mild horizontal-only correction.
        if body.height != target_h:
            body = resize_to_height(body, target_h)
    if body.width >= CANVAS_W - 4:
        scale = (CANVAS_W - 8) / body.width
        body = body.resize(
            (max(1, int(round(body.width * scale))), max(1, int(round(body.height * scale)))),
            Image.Resampling.LANCZOS,
        )
    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (*GREEN, 255))
    x = (CANVAS_W - body.width) // 2
    y = FOOT_Y - body.height
    if y < 0:
        # Prefer keeping feet; crop crown only if the figure still overflows.
        body = body.crop((0, -y, body.width, body.height))
        y = 0
    canvas.alpha_composite(body, (x, y))
    # Flatten onto pure green for the remove_green_screen path.
    rgb = Image.new("RGB", (CANVAS_W, CANVAS_H), GREEN)
    rgb.paste(canvas, mask=canvas.split()[-1])
    # Clean almost-green fringe.
    arr = np.asarray(rgb).copy()
    r, g, b = arr[..., 0].astype(np.int16), arr[..., 1].astype(np.int16), arr[..., 2].astype(np.int16)
    greenish = (g > 140) & (g > r + 35) & (g > b + 35)
    arr[greenish] = GREEN
    return Image.fromarray(arr, "RGB")


def ease_smooth(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def stand_target_height(index: int) -> int:
    """Monotone ease from seated to standing across 12 frames."""
    t = ease_smooth(index / 11.0)
    return int(round(SEATED_H + (STAND_H - SEATED_H) * t))


def breath_edit(neutral: Image.Image, phase: int) -> Image.Image:
    """Constrained idle: feet/pelvis fixed, tiny upper-body breath."""
    if phase == 0:
        return neutral.copy()

    arr = np.asarray(neutral.convert("RGBA")).copy()
    h, w = arr.shape[:2]
    # Pelvis/feet lock from ~55% of body height downward.
    split = int(h * 0.55)
    upper = Image.fromarray(arr[:split], "RGBA")
    lower = Image.fromarray(arr[split:], "RGBA")

    # ~1.0–1.6% vertical breath on the upper half only.
    amp = 0.010 + 0.006 * math.sin(phase * math.pi / 4.0)
    # Alternate lean direction slightly for life without lateral walk.
    lean = 0.004 * math.sin(phase * math.pi / 3.5)
    new_h = max(1, int(round(upper.height * (1.0 + amp))))
    new_w = max(1, int(round(upper.width * (1.0 + lean))))
    upper_r = upper.resize((new_w, new_h), Image.Resampling.BICUBIC)

    out = Image.new("RGBA", neutral.size, (0, 0, 0, 0))
    # Keep the upper/lower seam on the same row so feet never move.
    x = (w - upper_r.width) // 2
    y = split - upper_r.height
    out.paste(lower, (0, split), lower)
    out.alpha_composite(upper_r, (x, max(0, y)))
    # Soft clamp alpha holes at the seam.
    return out.filter(ImageFilter.UnsharpMask(radius=0.6, percent=40, threshold=2))


def save_chroma(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)}")


def build_direction(
    *,
    label: str,
    idle_paths: list[Path],
    stand_paths: list[Path],
    standing_endpoint: Image.Image,
    out_idle: list[Path],
    out_stand: list[Path],
) -> None:
    if len(idle_paths) != 8 or len(stand_paths) != 12:
        raise RuntimeError(f"{label}: expected 8 idle + 12 stand sources")

    # Prefer stand 00 when it matches idle (NE does); otherwise idle 00.
    idle_candidates = [load_figure(p) for p in idle_paths]
    stand0 = load_figure(stand_paths[0])
    neutral = idle_candidates[0]
    # If stand0 is essentially the same silhouette, keep stand0's paint (often cleaner).
    def _iou(a: Image.Image, b: Image.Image) -> float:
        ha = 256
        ra = resize_to_height(a, ha)
        rb = resize_to_height(b, ha)
        w = max(ra.width, rb.width)
        def pad(im: Image.Image) -> np.ndarray:
            canvas = Image.new("RGBA", (w, ha), (0, 0, 0, 0))
            canvas.alpha_composite(im, ((w - im.width) // 2, 0))
            return opaque_mask(canvas)
        ma, mb = pad(ra), pad(rb)
        inter = int(np.logical_and(ma, mb).sum())
        union = int(np.logical_or(ma, mb).sum())
        return inter / max(1, union)

    if _iou(neutral, stand0) >= 0.92:
        neutral = stand0

    # Standing endpoint supplies both body scale and head reference.
    endpoint = resize_to_height(standing_endpoint, STAND_H)
    head_ref = head_width_of(endpoint)

    # Idle cycle from one neutral.
    idle_figures = [breath_edit(neutral, i) for i in range(8)]
    for i, figure in enumerate(idle_figures):
        chroma = place_on_green(figure, SEATED_H, head_ref)
        save_chroma(chroma, out_idle[i])

    # Stand-up: 00 = neutral, 11 = standing endpoint. Intermediate frames prefer
    # source poses, but any cell whose head band still drifts after locking is
    # replaced by an eased neutral→standing morph (keeps scale/camera fixed).
    stand_figures: list[Image.Image] = [neutral]
    for i in range(1, 11):
        candidate = load_figure(stand_paths[i])
        probe = match_head_width(resize_to_height(candidate, stand_target_height(i)), head_ref)
        probe_head = head_width_of(probe)
        if 0.90 * head_ref <= probe_head <= 1.10 * head_ref:
            stand_figures.append(candidate)
        else:
            t = ease_smooth(i / 11.0)
            print(
                f"{label}: stand {i:02d} head {probe_head} vs ref {head_ref}; "
                f"using neutral→stand morph t={t:.2f}"
            )
            stand_figures.append(
                blend_figures(
                    resize_to_height(neutral, stand_target_height(i)),
                    resize_to_height(standing_endpoint, stand_target_height(i)),
                    t,
                )
            )
    stand_figures.append(standing_endpoint)

    for i, figure in enumerate(stand_figures):
        body = match_head_width(resize_to_height(figure, stand_target_height(i)), head_ref)
        chroma = place_on_green(body, stand_target_height(i), head_ref)
        save_chroma(chroma, out_stand[i])

    # Quick geometry report on authored masters.
    heights = []
    heads = []
    for path in out_idle + out_stand:
        fig = load_figure(path)
        heights.append(ne.source_opaque_height(fig))
        heads.append(head_width_of(fig))
    idle_h, stand_h = heights[:8], heights[8:]
    print(
        f"{label} master heights idle={idle_h[0]}.. stand={stand_h[0]}->{stand_h[-1]} "
        f"rise={stand_h[-1] - stand_h[0]} head={min(heads)}-{max(heads)} "
        f"drift={max(heads)/max(1,min(heads)):.3f}"
    )
    if max(heads) / max(1, min(heads)) > 1.12:
        raise RuntimeError(f"{label}: authored head drift still exceeds 12%: {heads}")
    if abs(idle_h[0] - stand_h[0]) > 4:
        raise RuntimeError(f"{label}: idle/stand00 height mismatch {idle_h[0]} vs {stand_h[0]}")
    if abs(stand_h[-1] - STAND_H) > 4:
        raise RuntimeError(f"{label}: stand endpoint height {stand_h[-1]}, expected ~{STAND_H}")


def backup_and_source_paths(paths: list[Path], backup_dir: Path) -> list[Path]:
    """Snapshot originals once; always re-author from the snapshot when present."""
    backup_dir.mkdir(parents=True, exist_ok=True)
    sources: list[Path] = []
    for path in paths:
        snap = backup_dir / path.name
        if not snap.exists() and path.exists():
            Image.open(path).save(snap)
        sources.append(snap if snap.exists() else path)
    return sources


def main() -> None:
    # NE: rear-three-quarter desk chain; standing handoff is mirrored NW.
    ne_idle_out = [V12_NE / f"voss_seated_idle_ne_{i:02d}_chroma_v12.png" for i in range(8)]
    ne_stand_out = [V12_NE / f"voss_stand_up_ne_{i:02d}_chroma_v12.png" for i in range(12)]
    ne_idle = backup_and_source_paths(ne_idle_out, V12_NE / "MasterBackup_pre_canonicalize")
    ne_stand = backup_and_source_paths(ne_stand_out, V12_NE / "MasterBackup_pre_canonicalize")

    nw_stand = load_figure(V12_FRAMES / "voss_idle_nw_00_chroma_v12.png")
    build_direction(
        label="NE",
        idle_paths=ne_idle,
        stand_paths=ne_stand,
        standing_endpoint=nw_stand,
        out_idle=ne_idle_out,
        out_stand=ne_stand_out,
    )

    # SE: source art is authored SW then flipped at install; keep SW-facing masters.
    se_idle_out = [V12_FRAMES / f"voss_seated_idle_{i:02d}_chroma_v12.png" for i in range(8)]
    se_stand_out = [V12_FRAMES / f"voss_stand_up_{i:02d}_chroma_v12.png" for i in range(12)]
    se_idle = backup_and_source_paths(se_idle_out, V12_FRAMES / "MasterBackup_pre_canonicalize")
    se_stand = backup_and_source_paths(se_stand_out, V12_FRAMES / "MasterBackup_pre_canonicalize")

    sw_stand = load_figure(V12_FRAMES / "voss_idle_sw_00_chroma_v12.png")
    build_direction(
        label="SE",
        idle_paths=se_idle,
        stand_paths=se_stand,
        standing_endpoint=sw_stand,
        out_idle=se_idle_out,
        out_stand=se_stand_out,
    )
    print("Canonical seat masters ready for process_voss_desk_ne_v12 + SE desk chain.")


if __name__ == "__main__":
    main()
