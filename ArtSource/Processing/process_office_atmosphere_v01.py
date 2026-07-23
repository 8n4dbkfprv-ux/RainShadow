"""Normalize atmosphere overlays + wall props for the detective office."""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(
    "/Users/laurensvanoorschot/.cursor/projects/"
    "Users-laurensvanoorschot-Desktop-RainShadow/assets"
)
GEN = ROOT / "ArtSource" / "Generated" / "Office" / "Props"
RUNTIME = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Props" / "Office"
AREA = ROOT / "RainShadow Shared" / "Resources" / "Art" / "Areas" / "DetectiveOffice"


def chroma_key(im: Image.Image, key=(0, 255, 0), tol=48.0, soft=20.0) -> Image.Image:
    rgba = np.array(im.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3]
    dist = np.linalg.norm(rgb - np.array(key, dtype=np.float32), axis=2)
    alpha = np.clip((dist - tol) / soft * 255.0, 0, 255)
    g, r, b = rgb[:, :, 1], rgb[:, :, 0], rgb[:, :, 2]
    greenish = (g > r + 18) & (g > b + 18) & (g > 40)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    green_dom = (g == mx) & ((g - mn) > 20) & (g > 35)
    alpha = np.where(greenish | green_dom, 0, alpha)
    spill = np.clip(1.0 - dist / (tol + soft + 40.0), 0, 1)
    lum = rgb.mean(axis=2, keepdims=True)
    rgb = rgb * (1.0 - spill[..., None] * 0.85) + lum * (spill[..., None] * 0.85)
    rgb = np.where(alpha[..., None] < 8, 0, rgb)
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def trim_alpha(im: Image.Image, threshold: int = 20, pad: int = 4) -> Image.Image:
    a = np.array(im.split()[-1])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return im
    return im.crop(
        (
            max(0, int(xs.min()) - pad),
            max(0, int(ys.min()) - pad),
            min(im.width, int(xs.max()) + 1 + pad),
            min(im.height, int(ys.max()) + 1 + pad),
        )
    )


def fit_into_canvas(im: Image.Image, canvas: tuple[int, int], bottom_bias: bool = True) -> Image.Image:
    cw, ch = canvas
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", canvas, (0, 0, 0, 0))
    scale = min(cw / im.width, ch / im.height) * 0.94
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (cw - nw) // 2
    y = (ch - nh - 4) if bottom_bias else (ch - nh) // 2
    y = max(0, min(ch - nh, y))
    out.alpha_composite(resized, (x, y))
    return out


def make_vignette(size: tuple[int, int] = (3072, 2048)) -> Image.Image:
    """Soft cool-black edge vignette with clear center (straight alpha)."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    # Elliptical radius normalized so corners are ~1.15
    nx = (xx - cx) / (w * 0.52)
    ny = (yy - cy) / (h * 0.48)
    r = np.sqrt(nx * nx + ny * ny)
    # Transparent center, darken edges. Alpha = darkness amount.
    edge = np.clip((r - 0.42) / 0.78, 0, 1)
    edge = edge * edge * (3 - 2 * edge)  # smoothstep
    alpha = (edge * 175).astype(np.uint8)  # max ~0.69 opacity at corners
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    rgb[:, :, 0] = 8
    rgb[:, :, 1] = 10
    rgb[:, :, 2] = 16
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def glow_from_chroma(path: Path, warm: bool) -> Image.Image:
    """Key green and keep emissive glow; boost alpha from luminance."""
    keyed = chroma_key(Image.open(path), tol=55, soft=24)
    arr = np.array(keyed, dtype=np.float32)
    rgb, a = arr[:, :, :3], arr[:, :, 3]
    lum = rgb.mean(axis=2)
    # Rebuild alpha from brightness so residual green field dies.
    if warm:
        score = 0.15 * rgb[:, :, 0] + 0.55 * rgb[:, :, 1] * 0 + 0.85 * rgb[:, :, 0] + 0.35 * rgb[:, :, 1]
        score = np.maximum(rgb[:, :, 0] * 0.9 + rgb[:, :, 1] * 0.45 - rgb[:, :, 2] * 0.2, 0)
    else:
        score = np.maximum(rgb[:, :, 2] * 0.95 + rgb[:, :, 1] * 0.35 - rgb[:, :, 0] * 0.25, 0)
    alpha = np.clip(np.maximum(a, score * 1.1), 0, 255)
    # Kill near-green leftovers
    g, r, b = rgb[:, :, 1], rgb[:, :, 0], rgb[:, :, 2]
    greenish = (g > r + 15) & (g > b + 15)
    alpha = np.where(greenish, 0, alpha)
    rgb = np.where(alpha[..., None] < 6, 0, rgb)
    out = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    return trim_alpha(out, threshold=12, pad=8)


def copy_if_present(name: str) -> Path | None:
    src = ASSETS / name
    if not src.exists():
        return None
    dest = GEN / name
    shutil.copy(src, dest)
    return dest


def main() -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    AREA.mkdir(parents=True, exist_ok=True)

    # --- Vignette (procedural; AI room paint is not a clean overlay) ---
    vignette = make_vignette((3072, 2048))
    vignette.save(GEN / "office_shadow_vignette_rgba_v01.png")
    vignette.save(AREA / "office_shadow_vignette.png")
    print("vignette", vignette.size)

    # --- Lamp pool / window spill ---
    lamp_src = copy_if_present("office_light_lamp_pool_v01.png")
    if lamp_src:
        lamp = fit_into_canvas(glow_from_chroma(lamp_src, warm=True), (1536, 1024), bottom_bias=False)
        lamp.save(GEN / "office_light_lamp_pool_rgba_v01.png")
        lamp.save(RUNTIME / "office_light_lamp_pool.png")
        print("lamp pool", lamp.size, "opaque", np.mean(np.array(lamp)[:, :, 3] > 20))

    spill_src = copy_if_present("office_light_window_spill_v01.png")
    if spill_src:
        spill = fit_into_canvas(glow_from_chroma(spill_src, warm=False), (1536, 1024), bottom_bias=False)
        spill.save(GEN / "office_light_window_spill_rgba_v01.png")
        spill.save(RUNTIME / "office_light_window_spill.png")
        print("window spill", spill.size, "opaque", np.mean(np.array(spill)[:, :, 3] > 20))

    # --- Floor wear ---
    wear_src = copy_if_present("office_floor_wear_decal_v01.png")
    if wear_src:
        wear = trim_alpha(chroma_key(Image.open(wear_src), tol=52, soft=22))
        wear = fit_into_canvas(wear, (2048, 1024), bottom_bias=False)
        # Soften overall alpha so it doesn't dominate the shell boards.
        arr = np.array(wear, dtype=np.float32)
        arr[:, :, 3] *= 0.55
        wear = Image.fromarray(arr.astype(np.uint8), "RGBA")
        wear.save(GEN / "office_floor_wear_decal_rgba_v01.png")
        wear.save(RUNTIME / "office_floor_wear_decal.png")
        print("floor wear", wear.size)

    # --- Contact shadows sheet ---
    shadow_src = copy_if_present("office_contact_shadows_sheet_v01.png")
    if shadow_src:
        sheet = chroma_key(Image.open(shadow_src), tol=50, soft=20)
        w, h = sheet.size
        left = trim_alpha(sheet.crop((0, 0, w // 2, h)))
        right = trim_alpha(sheet.crop((w // 2, 0, w, h)))
        desk_shadow = fit_into_canvas(left, (1024, 512), bottom_bias=False)
        cab_shadow = fit_into_canvas(right, (512, 384), bottom_bias=False)
        desk_shadow.save(RUNTIME / "office_desk_floor_shadow.png")
        cab_shadow.save(RUNTIME / "office_cabinet_floor_shadow.png")
        desk_shadow.save(GEN / "office_desk_floor_shadow_rgba_v01.png")
        cab_shadow.save(GEN / "office_cabinet_floor_shadow_rgba_v01.png")
        print("desk shadow", desk_shadow.size, "cabinet shadow", cab_shadow.size)

    # --- Wall props sheet: bookshelf | archive stack ---
    wall_src = copy_if_present("office_wall_props_sheet_v01.png")
    if wall_src:
        sheet = Image.open(wall_src)
        w, h = sheet.size
        inset = 0.04
        left = sheet.crop((int(w * inset), int(h * inset), int(w * 0.5 - w * inset), int(h * (1 - inset))))
        right = sheet.crop((int(w * 0.5 + w * inset), int(h * inset), int(w * (1 - inset)), int(h * (1 - inset))))
        shelf = fit_into_canvas(trim_alpha(chroma_key(left)), (512, 768), bottom_bias=True)
        stack = fit_into_canvas(trim_alpha(chroma_key(right)), (384, 384), bottom_bias=True)
        shelf.save(RUNTIME / "office_bookshelf.png")
        stack.save(RUNTIME / "office_archive_stack.png")
        shelf.save(GEN / "office_bookshelf_rgba_v01.png")
        stack.save(GEN / "office_archive_stack_rgba_v01.png")
        print("bookshelf", shelf.size, "archive stack", stack.size)


if __name__ == "__main__":
    main()
