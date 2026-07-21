#!/usr/bin/env python3
"""Build true alternating V5 walk cycles from paired camera-side renders."""

from pathlib import Path
import shutil

from PIL import Image

import process_pre_rendered_characters_v3 as raster


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/WalkGaitV5"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/GaitFixV5"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupGaitFixV5"


def figures(path: Path, count: int) -> list[Image.Image]:
    return raster.crop_components(path, count, 1)


def flipped(figure: Image.Image) -> Image.Image:
    return figure.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


def save_frame(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered = source_dir / "Registered_v05"
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
    southwest = figures(DETECTIVE_SOURCE / "det_walk_sw_source_rgba_v05.png", 4)[:2]
    southeast = figures(DETECTIVE_SOURCE / "det_walk_se_source_rgba_v05.png", 2)
    west = figures(DETECTIVE_SOURCE / "det_walk_w_source_rgba_v05.png", 2)
    east = figures(DETECTIVE_SOURCE / "det_walk_e_source_rgba_v05.png", 2)
    northwest = figures(DETECTIVE_SOURCE / "det_walk_nw_source_rgba_v05.png", 2)
    northeast = figures(DETECTIVE_SOURCE / "det_walk_ne_source_rgba_v05.png", 2)
    north = figures(DETECTIVE_SOURCE / "det_walk_n_source_rgba_v05.png", 2)
    return {
        "s": [*south, flipped(south[0]), flipped(south[1])],
        "sw": [*southwest, flipped(southeast[0]), flipped(southeast[1])],
        "w": [*west, flipped(east[0]), flipped(east[1])],
        "nw": [*northwest, flipped(northeast[0]), flipped(northeast[1])],
        "n": [*north, flipped(north[0]), flipped(north[1])],
    }


def client_cycles() -> tuple[list[Image.Image], list[Image.Image]]:
    southwest = figures(CLIENT_SOURCE / "client_arrival_sw_source_rgba_v05.png", 2)
    southeast = figures(CLIENT_SOURCE / "client_arrival_se_source_rgba_v05.png", 2)
    northeast = figures(CLIENT_SOURCE / "client_departure_ne_source_rgba_v05.png", 2)
    northwest = figures(CLIENT_SOURCE / "client_departure_nw_source_rgba_v05.png", 2)
    arrival = [*southwest, flipped(southeast[0]), flipped(southeast[1])]
    departure = [*northeast, flipped(northwest[0]), flipped(northwest[1])]
    return arrival, departure


def register_runtime() -> None:
    for direction, cycle in detective_cycles().items():
        for phase, figure in enumerate(cycle):
            save_frame(
                raster.register(figure),
                "DetectiveWalk.atlas",
                f"det_walk_{direction}_{phase:02d}.png",
                DETECTIVE_SOURCE,
            )

    arrival, departure = client_cycles()
    for phase, figure in enumerate(arrival):
        save_frame(
            raster.register(figure),
            "ClientArrival.atlas",
            f"client_arrival_sw_{phase:02d}.png",
            CLIENT_SOURCE,
        )
    for phase, figure in enumerate(departure):
        save_frame(
            raster.register(figure),
            "ClientArrival.atlas",
            f"client_departure_ne_{phase:02d}.png",
            CLIENT_SOURCE,
        )


def make_previews() -> None:
    directions = ("s", "sw", "w", "nw", "n")
    still = Image.new("RGBA", (512 * 4, 512 * 5), (24, 28, 31, 255))
    for row, direction in enumerate(directions):
        for phase in range(4):
            frame = Image.open(ATLASES / "DetectiveWalk.atlas" / f"det_walk_{direction}_{phase:02d}.png").convert("RGBA")
            still.alpha_composite(frame, (phase * 512, row * 512))
    still.save(DETECTIVE_SOURCE / "preview_detective_gait_v05.png", optimize=True)

    client = Image.new("RGBA", (512 * 4, 512 * 2), (24, 28, 31, 255))
    for row, prefix in enumerate(("client_arrival_sw", "client_departure_ne")):
        for phase in range(4):
            frame = Image.open(ATLASES / "ClientArrival.atlas" / f"{prefix}_{phase:02d}.png").convert("RGBA")
            client.alpha_composite(frame, (phase * 512, row * 512))
    client.save(CLIENT_SOURCE / "preview_client_gait_v05.png", optimize=True)

    detective_animation: list[Image.Image] = []
    for phase in range(4):
        strip = Image.new("RGBA", (256 * 5, 256), (24, 28, 31, 255))
        for column, direction in enumerate(directions):
            frame = Image.open(ATLASES / "DetectiveWalk.atlas" / f"det_walk_{direction}_{phase:02d}.png").convert("RGBA")
            strip.alpha_composite(frame.resize((256, 256), Image.Resampling.NEAREST), (column * 256, 0))
        detective_animation.append(strip.convert("RGB"))
    detective_animation[0].save(
        DETECTIVE_SOURCE / "preview_detective_gait_v05.gif",
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
        CLIENT_SOURCE / "preview_client_gait_v05.gif",
        save_all=True,
        append_images=client_animation[1:],
        duration=145,
        loop=0,
        optimize=False,
    )


def main() -> None:
    backup_runtime()
    register_runtime()
    make_previews()
    print("Registered 28 V5 walk cells with true near/far leg alternation")


if __name__ == "__main__":
    main()
