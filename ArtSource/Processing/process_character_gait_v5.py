#!/usr/bin/env python3
"""Build V8 walk cycles with anatomically tracked right/left legs."""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image

import process_pre_rendered_characters_v3 as raster


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/WalkGaitV5"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/GaitFixV5"
DETECTIVE_OUTPUT = ROOT / "ArtSource/Generated/Characters/Detective/WalkGaitV8"
CLIENT_OUTPUT = ROOT / "ArtSource/Generated/Characters/Client/GaitFixV8"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupGaitFixV5"


def figures(path: Path, count: int) -> list[Image.Image]:
    return raster.crop_components(path, count, 1)


def flipped(figure: Image.Image) -> Image.Image:
    return figure.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


def track_anatomical_legs(
    cycle: list[Image.Image],
    *,
    travel: str,
    character: str,
) -> list[Image.Image]:
    """Keep right/left leg ownership readable through all four gait phases.

    The anatomical right leg uses the warmer/lighter depth ramp.  In leftward
    views it occupies the screen-left limb in phases 0 and 3, and the
    screen-right limb in phases 1 and 2.  Rightward travel uses the inverse map.
    """
    tracked: list[Image.Image] = []
    for phase, figure in enumerate(cycle):
        pixels = np.asarray(figure.convert("RGBA")).copy()
        rgb = pixels[..., :3].astype(np.float32)
        alpha = pixels[..., 3]
        height, width = alpha.shape
        y, x = np.indices((height, width))
        red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]

        if character == "detective":
            lower = y >= round(height * 0.52)
            limb_color = (red > blue * 1.20) & (green > blue * 1.08)
        elif character == "client":
            lower = y >= round(height * 0.60)
            skin = (
                (red > 95)
                & (green > 45)
                & (red > green * 1.10)
                & (green > blue * 1.04)
            )
            shoes = (y >= round(height * 0.78)) & (red > blue * 1.18)
            limb_color = skin | shoes
        else:
            raise ValueError(f"Unknown character: {character}")

        limb = lower & limb_color & (alpha > 24)
        xs = x[limb]
        if xs.size < 20:
            raise RuntimeError(f"Could not isolate both {character} legs in phase {phase}")

        left_center, right_center = np.percentile(xs, [25, 75])
        for _ in range(8):
            split = (left_center + right_center) / 2
            left_values = xs[xs <= split]
            right_values = xs[xs > split]
            if left_values.size == 0 or right_values.size == 0:
                break
            left_center = float(left_values.mean())
            right_center = float(right_values.mean())
        split = (left_center + right_center) / 2
        left_leg = limb & (x <= split)
        right_leg = limb & (x > split)

        warm_is_left = phase in (0, 3)
        if travel == "right":
            warm_is_left = not warm_is_left
        elif travel != "left":
            raise ValueError(f"Unknown travel direction: {travel}")
        warm_leg, cool_leg = (left_leg, right_leg) if warm_is_left else (right_leg, left_leg)

        rgb[warm_leg] *= np.array([1.20, 1.12, 1.02], dtype=np.float32)
        rgb[cool_leg] *= np.array([0.62, 0.68, 0.78], dtype=np.float32)
        pixels[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        tracked.append(Image.fromarray(pixels, "RGBA"))
    return tracked


def remove_green_screen(source: Path, destination: Path) -> None:
    """Key the generated flat-green source while retaining soft edge alpha."""
    pixels = np.asarray(Image.open(source).convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.float32)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    other = np.maximum(red, blue)
    dominance = green - other
    key = np.clip((dominance - 20.0) / 90.0, 0.0, 1.0)
    key *= (green > 80) & (green > other * 1.18)
    pixels[..., 3] = np.clip(pixels[..., 3].astype(np.float32) * (1.0 - key), 0, 255).astype(np.uint8)
    spill = key > 0
    pixels[..., 1][spill] = np.minimum(
        pixels[..., 1][spill],
        np.clip(other[spill] * 1.06, 0, 255).astype(np.uint8),
    )
    pixels[pixels[..., 3] < 4] = 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels, "RGBA").save(destination, optimize=True)


def prepare_chroma_sources() -> None:
    for directory in (DETECTIVE_OUTPUT, CLIENT_OUTPUT):
        for source in directory.glob("*_chroma_v08.png"):
            destination = source.with_name(source.name.replace("_chroma_v08", "_rgba_v08"))
            remove_green_screen(source, destination)


def save_frame(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered = source_dir / "Registered_v08"
    registered.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in ("DetectiveWalk.atlas", "ClientArrival.atlas"):
        destination = BACKUP / atlas_name
        destination.mkdir()
        for path in (ATLASES / atlas_name).glob("*.png"):
            shutil.copy2(path, destination / path.name)


def detective_cycles() -> dict[str, list[Image.Image]]:
    south = figures(DETECTIVE_SOURCE / "det_walk_s_source_rgba_v05.png", 4)[:2]
    southwest = track_anatomical_legs(
        figures(DETECTIVE_OUTPUT / "det_walk_sw_cycle_rgba_v08.png", 4),
        travel="left",
        character="detective",
    )
    west = track_anatomical_legs(
        figures(DETECTIVE_OUTPUT / "det_walk_w_cycle_rgba_v08.png", 4),
        travel="left",
        character="detective",
    )
    northwest = track_anatomical_legs(
        figures(DETECTIVE_OUTPUT / "det_walk_nw_cycle_rgba_v08.png", 4),
        travel="left",
        character="detective",
    )
    north = figures(DETECTIVE_SOURCE / "det_walk_n_source_rgba_v05.png", 2)
    return {
        "s": [*south, flipped(south[0]), flipped(south[1])],
        "sw": southwest,
        "w": west,
        "nw": northwest,
        "n": [*north, flipped(north[0]), flipped(north[1])],
    }


def client_cycles() -> tuple[list[Image.Image], list[Image.Image]]:
    arrival = track_anatomical_legs(
        figures(CLIENT_OUTPUT / "client_arrival_sw_cycle_rgba_v08.png", 4),
        travel="left",
        character="client",
    )
    departure = track_anatomical_legs(
        figures(CLIENT_OUTPUT / "client_departure_ne_cycle_rgba_v08.png", 4),
        travel="right",
        character="client",
    )
    return arrival, departure


def register_runtime() -> None:
    for direction, cycle in detective_cycles().items():
        for phase, figure in enumerate(cycle):
            save_frame(
                raster.register(figure),
                "DetectiveWalk.atlas",
                f"det_walk_{direction}_{phase:02d}.png",
                DETECTIVE_OUTPUT,
            )

    arrival, departure = client_cycles()
    for phase, figure in enumerate(arrival):
        save_frame(
            raster.register(figure),
            "ClientArrival.atlas",
            f"client_arrival_sw_{phase:02d}.png",
            CLIENT_OUTPUT,
        )
    for phase, figure in enumerate(departure):
        save_frame(
            raster.register(figure),
            "ClientArrival.atlas",
            f"client_departure_ne_{phase:02d}.png",
            CLIENT_OUTPUT,
        )


def make_previews() -> None:
    directions = ("s", "sw", "w", "nw", "n")
    still = Image.new("RGBA", (512 * 4, 512 * 5), (24, 28, 31, 255))
    for row, direction in enumerate(directions):
        for phase in range(4):
            frame = Image.open(ATLASES / "DetectiveWalk.atlas" / f"det_walk_{direction}_{phase:02d}.png").convert("RGBA")
            still.alpha_composite(frame, (phase * 512, row * 512))
    still.save(DETECTIVE_OUTPUT / "preview_detective_gait_v08.png", optimize=True)

    client = Image.new("RGBA", (512 * 4, 512 * 2), (24, 28, 31, 255))
    for row, prefix in enumerate(("client_arrival_sw", "client_departure_ne")):
        for phase in range(4):
            frame = Image.open(ATLASES / "ClientArrival.atlas" / f"{prefix}_{phase:02d}.png").convert("RGBA")
            client.alpha_composite(frame, (phase * 512, row * 512))
    client.save(CLIENT_OUTPUT / "preview_client_gait_v08.png", optimize=True)

    detective_animation: list[Image.Image] = []
    for phase in range(4):
        strip = Image.new("RGBA", (256 * 5, 256), (24, 28, 31, 255))
        for column, direction in enumerate(directions):
            frame = Image.open(ATLASES / "DetectiveWalk.atlas" / f"det_walk_{direction}_{phase:02d}.png").convert("RGBA")
            strip.alpha_composite(frame.resize((256, 256), Image.Resampling.NEAREST), (column * 256, 0))
        detective_animation.append(strip.convert("RGB"))
    detective_animation[0].save(
        DETECTIVE_OUTPUT / "preview_detective_gait_v08.gif",
        save_all=True,
        append_images=detective_animation[1:],
        duration=145,
        loop=0,
        optimize=False,
    )

    client_animation: list[Image.Image] = []
    for phase in range(4):
        strip = Image.new("RGBA", (512, 256), (24, 28, 31, 255))
        for column, prefix in enumerate(("client_arrival_sw", "client_departure_ne")):
            frame = Image.open(ATLASES / "ClientArrival.atlas" / f"{prefix}_{phase:02d}.png").convert("RGBA")
            strip.alpha_composite(frame.resize((256, 256), Image.Resampling.NEAREST), (column * 256, 0))
        client_animation.append(strip.convert("RGB"))
    client_animation[0].save(
        CLIENT_OUTPUT / "preview_client_gait_v08.gif",
        save_all=True,
        append_images=client_animation[1:],
        duration=145,
        loop=0,
        optimize=False,
    )


def main() -> None:
    backup_runtime()
    prepare_chroma_sources()
    register_runtime()
    make_previews()
    print("Registered 28 V8 walk cells with anatomically tracked right/left legs")


if __name__ == "__main__":
    main()
