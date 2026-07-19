from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (
    ROOT
    / "ArtSource/Generated/UI/Dialogue/Scrollbar/dialogue_scroll_components_rgba_v01.png"
)
RUNTIME = ROOT / "RainShadow Shared/Resources/Art/UI/Dialogue"

# The generated study has large gutters by design. These boxes isolate only the
# four approved components before their runtime canvases are normalized.
COMPONENTS = {
    "dialogue_scroll_up_v01.png": ((218, 132, 520, 430), (96, 96)),
    "dialogue_scroll_down_v01.png": ((734, 132, 1038, 430), (96, 96)),
    "dialogue_scroll_track_v01.png": ((300, 542, 432, 1098), (64, 320)),
    "dialogue_scroll_thumb_v01.png": ((798, 542, 975, 1098), (72, 256)),
}


def premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    alpha = rgba[..., 3:4]
    premultiplied = np.concatenate((rgba[..., :3] * alpha, alpha), axis=2)

    channels = []
    for channel in range(4):
        source = Image.fromarray(
            np.clip(premultiplied[..., channel] * 255.0, 0, 255).astype(np.uint8),
            mode="L",
        )
        channels.append(
            np.asarray(source.resize(size, Image.Resampling.LANCZOS), dtype=np.float32)
            / 255.0
        )

    resized = np.stack(channels, axis=2)
    output_alpha = resized[..., 3:4]
    output_rgb = np.divide(
        resized[..., :3],
        output_alpha,
        out=np.zeros_like(resized[..., :3]),
        where=output_alpha > 0.001,
    )
    output = np.concatenate((output_rgb, output_alpha), axis=2)
    return Image.fromarray(
        np.clip(output * 255.0, 0, 255).astype(np.uint8),
        mode="RGBA",
    )


def alpha_crop(image: Image.Image, threshold: int = 12) -> Image.Image:
    alpha = np.asarray(image.getchannel("A"))
    ys, xs = np.nonzero(alpha > threshold)
    if not len(xs):
        raise RuntimeError("Component crop is empty")
    return image.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def fit_component(image: Image.Image, canvas_size: tuple[int, int]) -> Image.Image:
    image = alpha_crop(image)
    canvas_width, canvas_height = canvas_size
    scale = min(canvas_width / image.width, canvas_height / image.height)
    size = (
        max(1, round(image.width * scale)),
        max(1, round(image.height * scale)),
    )
    resized = premultiplied_resize(image, size)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((canvas_width - size[0]) // 2, (canvas_height - size[1]) // 2),
    )
    return canvas


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    RUNTIME.mkdir(parents=True, exist_ok=True)

    for filename, (crop_box, canvas_size) in COMPONENTS.items():
        component = fit_component(source.crop(crop_box), canvas_size)
        component.save(RUNTIME / filename, optimize=True)


if __name__ == "__main__":
    main()
