"""Build the 2x-density smooth runtime key and an old/new scale preview."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV2/det_key_se_rgba_v02.png"
OUTPUT_DIR = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV2"
RUNTIME = OUTPUT_DIR / "det_key_se_runtime_2x_v02.png"
PREVIEW = OUTPUT_DIR / "preview_det_key_se_actual_scale_v02.png"
OLD_RUNTIME = ROOT / "ArtSource/Generated/StyleLock/style_detective_key_se_runtime_v02.png"

FRAME_SIZE = 512
BODY_HEIGHT = 200
FOOT_Y = 434


def premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    source[..., :3] *= source[..., 3:4]
    resized_channels = [
        np.asarray(
            Image.fromarray(np.round(source[..., channel] * 255).astype(np.uint8)).resize(
                size, Image.Resampling.LANCZOS
            ),
            dtype=np.float32,
        )
        / 255.0
        for channel in range(4)
    ]
    alpha = resized_channels[3]
    rgb = np.stack(resized_channels[:3], axis=2)
    np.divide(rgb, alpha[..., None], out=rgb, where=alpha[..., None] > 0)
    rgba = np.concatenate((np.clip(rgb, 0, 1), alpha[..., None]), axis=2)
    return Image.fromarray(np.round(rgba * 255).astype(np.uint8), "RGBA")


def build_runtime() -> Image.Image:
    source = Image.open(SOURCE).convert("RGBA")
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Generated source has no opaque subject")
    subject = source.crop(bbox)
    width = round(subject.width * BODY_HEIGHT / subject.height)
    subject = premultiplied_resize(subject, (width, BODY_HEIGHT))
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(subject, ((FRAME_SIZE - width) // 2, FOOT_Y - BODY_HEIGHT))
    return canvas


def build_preview(runtime: Image.Image) -> Image.Image:
    canvas = Image.new("RGB", (1024, 512), "#171b1f")
    draw = ImageDraw.Draw(canvas)
    old = Image.open(OLD_RUNTIME).convert("RGBA")
    new_at_world_scale = runtime.resize((256, 256), Image.Resampling.LANCZOS)
    canvas.paste(old, (128, 96), old)
    canvas.paste(new_at_world_scale, (640, 96), new_at_world_scale)
    draw.line((0, 313, 1024, 313), fill="#8c3f3f", width=1)
    draw.text((196, 390), "OLD: 1x / nearest", fill="#c8c8c8")
    draw.text((689, 390), "V2: 2x / linear", fill="#c8c8c8")
    draw.text((324, 438), "Same 100-world-unit body height", fill="#858b91")
    return canvas


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    runtime = build_runtime()
    runtime.save(RUNTIME, optimize=True)
    build_preview(runtime).save(PREVIEW, optimize=True)
    bbox = runtime.getchannel("A").getbbox()
    print(f"Wrote {RUNTIME.relative_to(ROOT)}")
    print(f"Wrote {PREVIEW.relative_to(ROOT)}")
    print(f"Runtime alpha bounds: {bbox}")


if __name__ == "__main__":
    main()
