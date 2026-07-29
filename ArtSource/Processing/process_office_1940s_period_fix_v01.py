"""Key 1940s period-correct office prop remasters into runtime sprites.

Fixes anachronisms found in the detective office prop pass:
  - desk ashtray: unfiltered cigarette stubs (no cork/filter tips)
  - waiting ashtray: derived cool recolor of the desk ashtray
  - wastebasket: crumpled paper only (no packing peanuts)
  - case board: pinned photos/notes without red-string web
  - washbasin: period dual cross-handle taps on the backsplash

Usage:
    python3 ArtSource/Processing/process_office_1940s_period_fix_v01.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/Props/Office"
GEN = ROOT / "ArtSource/Generated/Office/Props"
DESK_ITEMS = GEN / "DeskItems"
ASSETS = Path.home() / ".cursor/projects/Users-laurensvanoorschot-Desktop-RainShadow/assets"

# (asset master, retained chroma name, runtime name, canvas, target content h)
JOBS = (
    (
        "office_desk_ashtray_1940s_chroma_v05.png",
        "office_desk_ashtray_1940s_chroma_v05.png",
        "office_desk_ashtray.png",
        (115, 85),
        73,
        DESK_ITEMS,
    ),
    (
        "office_wastebasket_1940s_chroma_v03.png",
        "office_wastebasket_1940s_chroma_v03.png",
        "office_wastebasket.png",
        (256, 256),
        None,
        GEN,
    ),
    (
        "office_case_board_1940s_chroma_v02.png",
        "office_case_board_1940s_chroma_v02.png",
        "office_case_board.png",
        (320, 280),
        None,
        GEN,
    ),
    (
        "office_personal_washbasin_1940s_chroma_v02.png",
        "office_personal_washbasin_1940s_chroma_v02.png",
        "office_personal_washbasin.png",
        (280, 300),
        210,
        GEN,
    ),
)


def key_chroma(path: Path, spill: float = 1.0) -> np.ndarray:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - 8.0) / 46.0, 0.0, 1.0)
    ceiling = np.maximum(r, b) + 6.0
    over = np.maximum(g - ceiling, 0.0) * spill
    out = rgb.copy()
    out[..., 1] = g - over
    return np.dstack([out, alpha * 255.0])


def trim(rgba: np.ndarray, pad: int = 4, thresh: float = 24.0) -> np.ndarray:
    ys, xs = np.where(rgba[..., 3] > thresh)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + 1 + pad, rgba.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + 1 + pad, rgba.shape[1])
    return rgba[y0:y1, x0:x1]


def opaque_content_height(rgba: np.ndarray, thresh: float = 40.0) -> int:
    ys, _ = np.where(rgba[..., 3] > thresh)
    if len(ys) == 0:
        return 0
    return int(ys.max() - ys.min() + 1)


def fit_into_canvas(
    rgba: np.ndarray,
    canvas: tuple[int, int],
    target_content_h: int | None = None,
) -> Image.Image:
    cw, ch = canvas
    image = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
    if image.width == 0 or image.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    src_h = opaque_content_height(rgba) or image.height
    if target_content_h and src_h > 0:
        scale = (target_content_h / src_h) * 0.98
        scale = min(scale, (cw * 0.94) / image.width, (ch * 0.94) / image.height)
    else:
        scale = min(cw / image.width, ch / image.height) * 0.94
    nw = max(1, int(round(image.width * scale)))
    nh = max(1, int(round(image.height * scale)))
    resized = image.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = max(0, min(ch - nh, ch - nh - 2))
    out.alpha_composite(resized, (x, y))
    return out


def derive_waiting_ashtray(desk: Image.Image) -> Image.Image:
    arr = np.array(desk.convert("RGBA"), dtype=np.float32)
    arr[:, :, 0] = np.clip(arr[:, :, 0] * 0.92, 0, 255)
    arr[:, :, 2] = np.clip(arr[:, :, 2] * 1.08, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    GEN.mkdir(parents=True, exist_ok=True)
    DESK_ITEMS.mkdir(parents=True, exist_ok=True)

    desk_runtime: Image.Image | None = None
    for asset_name, chroma_name, runtime_name, canvas, target_h, retain_dir in JOBS:
        src = ASSETS / asset_name
        if not src.exists():
            raise FileNotFoundError(src)
        retain_dir.mkdir(parents=True, exist_ok=True)
        chroma_dest = retain_dir / chroma_name
        chroma_dest.write_bytes(src.read_bytes())

        rgba = trim(key_chroma(chroma_dest))
        rgba_master = Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")
        rgba_name = runtime_name.replace(".png", "_1940s_rgba_v01.png")
        if runtime_name == "office_desk_ashtray.png":
            rgba_master.save(DESK_ITEMS / "office_desk_ashtray_rgba_v03.png")
        else:
            rgba_master.save(retain_dir / rgba_name)

        out = fit_into_canvas(rgba, canvas, target_content_h=target_h)
        out.save(RUNTIME / runtime_name)
        a = np.asarray(out)[:, :, 3]
        print(
            f"wrote {runtime_name:36s} size={out.size} "
            f"opaque={(a > 20).sum():,} content_h={opaque_content_height(np.asarray(out))}"
        )
        if runtime_name == "office_desk_ashtray.png":
            desk_runtime = out

    assert desk_runtime is not None
    waiting = derive_waiting_ashtray(desk_runtime)
    waiting.save(RUNTIME / "office_waiting_ashtray.png")
    waiting.save(GEN / "office_waiting_ashtray_rgba_v02.png")
    print(f"wrote {'office_waiting_ashtray.png':36s} size={waiting.size} (derived)")


if __name__ == "__main__":
    main()
