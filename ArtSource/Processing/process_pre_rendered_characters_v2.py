#!/usr/bin/env python3
"""Register V2 low-detail 3D renders as smooth 2x-density runtime atlases."""

from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
DETECTIVE_SOURCE = ROOT / "ArtSource/Generated/Characters/Detective/PreRendered3DV2"
CLIENT_SOURCE = ROOT / "ArtSource/Generated/Characters/Client/PreRendered3DV2"
ATLASES = ROOT / "RainShadow Shared/Resources/Art/Atlases"
BACKUP = ROOT / "ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV2"

FRAME_SIZE = 512
BODY_HEIGHT = 200
FOOT_Y = 434


def premultiplied_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    channels = []
    for channel in range(4):
        source = Image.fromarray(np.round(rgba[..., channel] * 255).astype(np.uint8), "L")
        channels.append(
            np.asarray(source.resize(size, Image.Resampling.LANCZOS), dtype=np.float32) / 255.0
        )
    alpha = channels[3]
    rgb = np.stack(channels[:3], axis=2)
    np.divide(rgb, alpha[..., None], out=rgb, where=alpha[..., None] > 0)
    result = np.concatenate((np.clip(rgb, 0, 1), alpha[..., None]), axis=2)
    return Image.fromarray(np.round(result * 255).astype(np.uint8), "RGBA")


def crop_grid(path: Path, columns: int, rows: int) -> list[Image.Image]:
    sheet = Image.open(path).convert("RGBA")
    frames: list[Image.Image] = []
    for row in range(rows):
        top = round(row * sheet.height / rows)
        bottom = round((row + 1) * sheet.height / rows)
        for column in range(columns):
            left = round(column * sheet.width / columns)
            right = round((column + 1) * sheet.width / columns)
            cell = sheet.crop((left, top, right, bottom))
            bbox = cell.getchannel("A").getbbox()
            if bbox is None:
                raise RuntimeError(f"Empty cell {row},{column} in {path}")
            frames.append(cell.crop(bbox))
    return frames


def crop_components(path: Path, columns: int, rows: int) -> list[Image.Image]:
    """Extract figures that extend beyond nominal grid-cell boundaries."""
    sheet = Image.open(path).convert("RGBA")
    alpha = np.asarray(sheet)[..., 3]
    labels, _ = ndimage.label(alpha >= 16, structure=np.ones((3, 3), dtype=np.uint8))
    components: list[tuple[int, int, int, int]] = []
    for label_index, slices in enumerate(ndimage.find_objects(labels), start=1):
        if slices is None:
            continue
        area = int(np.count_nonzero(labels[slices] == label_index))
        if area < 500:
            continue
        y_slice, x_slice = slices
        components.append((x_slice.start, y_slice.start, x_slice.stop, y_slice.stop))
    expected = columns * rows
    if len(components) != expected:
        raise RuntimeError(f"Expected {expected} figures in {path}, found {len(components)}")

    def grid_position(box: tuple[int, int, int, int]) -> tuple[int, int]:
        left, top, _, bottom = box
        row = min(rows - 1, int(((top + bottom) / 2) * rows / sheet.height))
        return row, left

    frames: list[Image.Image] = []
    for left, top, right, bottom in sorted(components, key=grid_position):
        crop = sheet.crop((max(0, left - 2), max(0, top - 2), min(sheet.width, right + 2), min(sheet.height, bottom + 2)))
        frames.append(crop)
    return frames


def register(figure: Image.Image) -> Image.Image:
    width = max(1, round(figure.width * BODY_HEIGHT / figure.height))
    figure = premultiplied_resize(figure, (width, BODY_HEIGHT))
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    canvas.alpha_composite(figure, ((FRAME_SIZE - width) // 2, FOOT_Y - BODY_HEIGHT))
    return canvas


def arm_layer(figure: Image.Image) -> Image.Image:
    """Select both complete forearms/hands for the desk foreground pass."""
    mask = Image.new("L", figure.size, 0)
    draw = ImageDraw.Draw(mask)
    w, h = figure.size
    draw.polygon(
        [(0.02*w, 0.20*h), (0.38*w, 0.25*h), (0.51*w, 0.53*h),
         (0.35*w, 0.58*h), (0.12*w, 0.49*h)], fill=255
    )
    draw.polygon(
        [(0.55*w, 0.22*h), (0.98*w, 0.20*h), (0.90*w, 0.51*h),
         (0.64*w, 0.56*h), (0.50*w, 0.43*h)], fill=255
    )
    pixels = np.asarray(figure.convert("RGBA")).copy()
    pixels[np.asarray(mask) == 0] = 0
    return Image.fromarray(pixels, "RGBA")


def save_frame(frame: Image.Image, atlas_name: str, filename: str, source_dir: Path) -> None:
    registered_dir = source_dir / "Registered_v02"
    registered_dir.mkdir(parents=True, exist_ok=True)
    atlas = ATLASES / atlas_name
    atlas.mkdir(parents=True, exist_ok=True)
    path = registered_dir / filename
    frame.save(path, optimize=True)
    shutil.copy2(path, atlas / filename)


def backup_runtime() -> None:
    if BACKUP.exists():
        return
    BACKUP.mkdir(parents=True)
    for atlas_name in (
        "DetectiveWalk.atlas", "DetectiveIdle.atlas", "DetectiveSeatedIdle.atlas",
        "DetectiveSeatedArms.atlas", "DetectiveStandUp.atlas", "ClientArrival.atlas",
    ):
        source = ATLASES / atlas_name
        destination = BACKUP / atlas_name
        destination.mkdir()
        for path in source.glob("*.png"):
            shutil.copy2(path, destination / path.name)


def process_detective() -> None:
    directions = ["s", "sw", "w", "nw", "n"]
    walk = crop_components(DETECTIVE_SOURCE / "det_walk_5dir_4frame_rgba_v02.png", 4, 5)
    for direction_index, direction in enumerate(directions):
        for phase in range(4):
            frame = register(walk[direction_index * 4 + phase])
            save_frame(frame, "DetectiveWalk.atlas", f"det_walk_{direction}_{phase:02d}.png", DETECTIVE_SOURCE)

    idle = crop_grid(DETECTIVE_SOURCE / "det_standing_idle_5dir_rgba_v02.png", 5, 1)
    registered_idle: dict[str, Image.Image] = {}
    for direction, figure in zip(directions, idle):
        frame = register(figure)
        registered_idle[direction] = frame
        save_frame(frame, "DetectiveIdle.atlas", f"det_standing_idle_{direction}_00.png", DETECTIVE_SOURCE)
    south_east = registered_idle["sw"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    save_frame(south_east, "DetectiveIdle.atlas", "det_standing_idle_se_00.png", DETECTIVE_SOURCE)

    seated = crop_grid(DETECTIVE_SOURCE / "det_seated_idle_strip_rgba_v02.png", 4, 1)
    for index, figure in enumerate(seated):
        body = register(figure)
        arms = register(arm_layer(figure))
        save_frame(body, "DetectiveSeatedIdle.atlas", f"det_seated_idle_se_{index:02d}.png", DETECTIVE_SOURCE)
        save_frame(arms, "DetectiveSeatedArms.atlas", f"det_seated_arms_se_{index:02d}.png", DETECTIVE_SOURCE)

    stand_up = crop_components(DETECTIVE_SOURCE / "det_stand_up_sheet_rgba_v02.png", 4, 3)
    for index, figure in enumerate(stand_up):
        save_frame(register(figure), "DetectiveStandUp.atlas", f"det_stand_up_se_{index:02d}.png", DETECTIVE_SOURCE)


def process_client() -> None:
    arrival = crop_grid(CLIENT_SOURCE / "client_arrival_sw_strip_rgba_v02.png", 5, 1)
    for index, figure in enumerate(arrival):
        save_frame(register(figure), "ClientArrival.atlas", f"client_arrival_sw_{index:02d}.png", CLIENT_SOURCE)
    departure = crop_grid(CLIENT_SOURCE / "client_departure_ne_strip_rgba_v02.png", 4, 1)
    for index, figure in enumerate(departure):
        save_frame(register(figure), "ClientArrival.atlas", f"client_departure_ne_{index:02d}.png", CLIENT_SOURCE)


def make_previews() -> None:
    specs = [
        (DETECTIVE_SOURCE, "preview_walk_v02.png", "DetectiveWalk.atlas", [f"det_walk_{d}_{i:02d}.png" for d in ("s", "sw", "w", "nw", "n") for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_idle_v02.png", "DetectiveIdle.atlas", [f"det_standing_idle_{d}_00.png" for d in ("s", "sw", "w", "nw", "n")], 5),
        (DETECTIVE_SOURCE, "preview_seated_v02.png", "DetectiveSeatedIdle.atlas", [f"det_seated_idle_se_{i:02d}.png" for i in range(4)], 4),
        (DETECTIVE_SOURCE, "preview_stand_up_v02.png", "DetectiveStandUp.atlas", [f"det_stand_up_se_{i:02d}.png" for i in range(12)], 6),
        (CLIENT_SOURCE, "preview_client_v02.png", "ClientArrival.atlas", [f"client_arrival_sw_{i:02d}.png" for i in range(5)] + [f"client_departure_ne_{i:02d}.png" for i in range(4)], 5),
    ]
    for source_dir, filename, atlas_name, names, columns in specs:
        rows = (len(names) + columns - 1) // columns
        preview = Image.new("RGBA", (FRAME_SIZE * columns, FRAME_SIZE * rows), (24, 28, 31, 255))
        for index, name in enumerate(names):
            frame = Image.open(ATLASES / atlas_name / name).convert("RGBA")
            preview.alpha_composite(frame, ((index % columns) * FRAME_SIZE, (index // columns) * FRAME_SIZE))
        preview.save(source_dir / filename, optimize=True)

    office_path = ROOT / "ArtSource/References/UI/Map/office_runtime_clean_v02.png"
    office = Image.open(office_path).convert("RGBA")
    actors = [
        (790, 800, ATLASES / "DetectiveIdle.atlas/det_standing_idle_se_00.png", 54, 20),
        (1450, 800, ATLASES / "ClientArrival.atlas/client_arrival_sw_04.png", 44, 15),
    ]
    shadow_layer = Image.new("RGBA", office.size)
    shadow_draw = ImageDraw.Draw(shadow_layer)
    for root_x, root_y, _, shadow_w, shadow_h in actors:
        shadow_draw.ellipse(
            (root_x - shadow_w // 2, root_y - shadow_h // 2,
             root_x + shadow_w // 2, root_y + shadow_h // 2),
            fill=(0, 0, 0, 88),
        )
    office.alpha_composite(shadow_layer)
    for root_x, root_y, path, _, _ in actors:
        frame = Image.open(path).convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
        office.alpha_composite(frame, (root_x - 128, root_y - 217))
    office.convert("RGB").save(
        ROOT / "ArtSource/Generated/Characters/preview_characters_in_office_v02.png",
        optimize=True,
    )


def main() -> None:
    backup_runtime()
    process_detective()
    process_client()
    make_previews()
    print("Registered 2x-density V2 character atlases and previews")


if __name__ == "__main__":
    main()
