#!/usr/bin/env python3
"""Seat a close-up portal painting back into the one city plate.

Infinity Engine outdoor doors are tiles of the same area art. Whole-block
generates cannot hold a 1.15× adult opening, so this pass edits a tight
neighbourhood of each portal and feathers that painting into the plate —
still one image, no overlay sprite and no procedural wood stamp.

    python3 ArtSource/Processing/compose_city_portal_paintovers.py --extract
    python3 ArtSource/Processing/compose_city_portal_paintovers.py --seat --install
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_city_ward_rebuild_v01 as ward
import qa_area_door_scale as qa
import qa_plate_projection as projection

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ArtSource/Generated/CityDistrict/V2/PortalPaint"
STAGE = ROOT / "ArtSource/Generated/CityDistrict/V2/UnifiedPlates"
ART = ROOT / "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2"
AREAS = ROOT / "RainShadow Shared/Resources/Areas"
MAPS = ROOT / "RainShadow Shared/Resources/Art/UI/Map"
SPRITE = (
    ROOT
    / "RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas/voss_standing_idle_s_00.png"
)

JIG_WIDTH = 1024
HALF_W_ADULTS = 1.65
UP_ADULTS = 3.6
DOWN_ADULTS = 0.55
DOOR_HALF_W_ADULTS = 0.24
TARGET = qa.TARGET


def install_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        destination.unlink()
    shutil.copy2(source, destination)


def portal_dir(slug: str, door_id: str) -> Path:
    return OUT / slug / door_id.replace(".", "_")


def crop_box(width: int, height: int, cx: float, cy: float) -> tuple[int, int, int, int]:
    adult = qa.adult_px(width)
    left = int(round(cx - adult * HALF_W_ADULTS))
    right = int(round(cx + adult * HALF_W_ADULTS))
    top = int(round(cy - adult * UP_ADULTS))
    bottom = int(round(cy + adult * DOWN_ADULTS))
    left = max(0, left)
    top = max(0, top)
    right = min(width, right)
    bottom = min(height, bottom)
    return left, top, right, bottom


def silhouette(target_height: int) -> Image.Image:
    source = Image.open(SPRITE).convert("RGBA")
    alpha = np.asarray(source.split()[-1])
    rows = np.where(alpha.max(axis=1) > 24)[0]
    cols = np.where(alpha.max(axis=0) > 24)[0]
    cropped = source.crop((int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1))
    scale = target_height / cropped.height
    size = (
        max(1, int(round(cropped.width * scale))),
        max(1, int(round(cropped.height * scale))),
    )
    figure = cropped.resize(size, Image.Resampling.LANCZOS)
    pixels = np.asarray(figure).copy()
    visible = pixels[:, :, 3] > 24
    pixels[visible, 0] = 40
    pixels[visible, 1] = 255
    pixels[visible, 2] = 90
    pixels[visible, 3] = 220
    return Image.fromarray(pixels, "RGBA")


def draw_jig(crop: Image.Image, local_cx: float, local_cy: float, plate_w: int) -> Image.Image:
    """Upscale the neighbourhood and mark adult height plus the 1.15× door box."""
    scale = JIG_WIDTH / crop.width
    jig = crop.resize(
        (JIG_WIDTH, max(1, int(round(crop.height * scale)))),
        Image.Resampling.LANCZOS,
    ).convert("RGBA")
    adult = qa.adult_px(plate_w) * scale
    cx = local_cx * scale
    cy = local_cy * scale
    door_h = adult * TARGET
    half_w = adult * DOOR_HALF_W_ADULTS
    overlay = Image.new("RGBA", jig.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    box = (cx - half_w, cy - door_h, cx + half_w, cy)
    draw.rectangle(box, fill=(255, 210, 0, 70), outline=(255, 220, 0, 255), width=4)
    jig.alpha_composite(overlay)
    figure = silhouette(int(round(adult)))
    fx = int(round(cx - half_w - figure.width - 6))
    fy = int(round(cy - figure.height))
    jig.alpha_composite(figure, (max(4, fx), max(0, fy)))
    return jig.convert("RGB")


def extract_one(slug: str, door: dict, plate: Image.Image, area: dict) -> dict:
    wx, wy = qa.door_anchor(area, door)
    cx, cy = qa.world_to_plate(wx, wy, plate.width, plate.height)
    box = crop_box(plate.width, plate.height, cx, cy)
    crop = plate.crop(box).convert("RGB")
    local_cx = cx - box[0]
    local_cy = cy - box[1]
    dest = portal_dir(slug, door["id"])
    dest.mkdir(parents=True, exist_ok=True)
    source_path = dest / "source.png"
    jig_path = dest / "jig.png"
    crop.save(source_path, compress_level=3)
    draw_jig(crop, local_cx, local_cy, plate.width).save(jig_path, compress_level=3)
    measured = qa.measure_opening(plate, cx, cy)
    record = {
        "slug": slug,
        "door": door["id"],
        "world": [wx, wy],
        "thresholdPx": [cx, cy],
        "crop": list(box),
        "localThreshold": [local_cx, local_cy],
        "plate": [plate.width, plate.height],
        "adultPx": qa.adult_px(plate.width),
        "sourceMultiple": (measured["heightPx"] * qa.WORLD[0] / plate.width) / qa.ADULT_WU,
        "sourceHeightPx": measured["heightPx"],
        "source": str(source_path.relative_to(ROOT)),
        "jig": str(jig_path.relative_to(ROOT)),
    }
    (dest / "meta.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


def plate_image(slug: str, from_staged: bool) -> Image.Image:
    area = qa.load_area(slug)
    staged = STAGE / slug / f"city_{slug}_area_v02.png"
    if from_staged and staged.exists():
        return Image.open(staged).convert("RGB")
    return Image.open(qa.plate_path(area)).convert("RGB")


def extract(slugs: list[str], from_staged: bool = False) -> list[dict]:
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for slug in slugs:
        area = qa.load_area(slug)
        plate = plate_image(slug, from_staged)
        for door in area.get("doors", []):
            record = extract_one(slug, door, plate, area)
            records.append(record)
            print(
                f"{slug:16} {door['id']:28} crop {record['crop']}  "
                f"{record['sourceMultiple']:.2f}x"
            )
    (OUT / "extract.json").write_text(json.dumps(records, indent=2) + "\n")
    return records


def plate_for_seating(slug: str, from_staged: bool) -> tuple[Image.Image, Path]:
    """Patch the plate `--extract` measured.

    Default is the installed play plate. `--from-staged` continues a previous
    neighbourhood pass already written to UnifiedPlates.
    """
    area = qa.load_area(slug)
    installed = qa.plate_path(area)
    backup = STAGE / slug / f"city_{slug}_area_v02.pre_portal.png"
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(installed, backup)
    return plate_image(slug, from_staged), installed


def load_meta(slug: str, door_id: str) -> dict:
    path = portal_dir(slug, door_id) / "meta.json"
    if not path.exists():
        raise FileNotFoundError(f"missing extract meta: {path}")
    return json.loads(path.read_text())


def take_path(slug: str, door_id: str) -> Path | None:
    dest = portal_dir(slug, door_id)
    for name in ("take.png", "take.jpg"):
        path = dest / name
        if path.exists():
            return path
    return None


def feather_mask(size: tuple[int, int], local_cx: float, local_cy: float, adult: float) -> Image.Image:
    """Fade before the crop edge so the neighbourhood still reads as one painting."""
    del local_cx, local_cy, adult
    width, height = size
    mask = Image.new("L", size, 0)
    inset_x = max(18, width // 14)
    inset_y = max(16, height // 16)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset_x, inset_y, width - inset_x, height - inset_y),
        radius=max(16, width // 18),
        fill=255,
    )
    return mask.filter(ImageFilter.GaussianBlur(max(12, width // 28)))


def register_take(take: Image.Image, width: int, height: int, local_cy: float) -> Image.Image:
    """Scale the 3:4 take to the neighbourhood without shearing the camera.

    Width-matched, then cropped to the crop height from the bottom so the
    threshold row (near the jig foot) survives.
    """
    del local_cy
    take = take.convert("RGB")
    scaled = take.resize(
        (width, max(1, int(round(take.height * (width / take.width))))),
        Image.Resampling.LANCZOS,
    )
    if scaled.height >= height:
        top = max(0, int(round((scaled.height - height) * 0.42)))
        top = min(top, scaled.height - height)
        return scaled.crop((0, top, width, top + height))
    canvas = Image.new("RGB", (width, height))
    canvas.paste(scaled, (0, height - scaled.height))
    return canvas


def seat_take(plate: Image.Image, meta: dict, take: Image.Image) -> Image.Image:
    left, top, right, bottom = (int(v) for v in meta["crop"])
    width, height = right - left, bottom - top
    region = plate.crop((left, top, right, bottom)).convert("RGB")
    local_cx, local_cy = meta["localThreshold"]
    patch = register_take(take, width, height, local_cy)
    mask = feather_mask((width, height), local_cx, local_cy, float(meta["adultPx"]))
    seated = Image.composite(patch, region, mask)
    out = plate.copy()
    out.paste(seated, (left, top))
    return out


def seat(slugs: list[str], install: bool, from_staged: bool) -> int:
    failed = 0
    for slug in slugs:
        area = qa.load_area(slug)
        plate, installed = plate_for_seating(slug, from_staged)
        seated_any = False
        for door in area.get("doors", []):
            take = take_path(slug, door["id"])
            if take is None:
                print(f"  skip {slug} {door['id']}: no take.png")
                continue
            meta = load_meta(slug, door["id"])
            plate = seat_take(plate, meta, Image.open(take))
            left, top, right, bottom = (int(v) for v in meta["crop"])
            seated_crop = plate.crop((left, top, right, bottom))
            seated_crop.save(portal_dir(slug, door["id"]) / "seated.png", compress_level=3)
            wx, wy = qa.door_anchor(area, door)
            cx, cy = qa.world_to_plate(wx, wy, plate.width, plate.height)
            measured = qa.grade_door(area, door, plate, qa.measure_opening(plate, cx, cy))
            print(
                f"  seated {slug} {door['id']}: "
                f"{measured['multiple']:.2f}x adult "
                f"{'PASS' if measured['passes'] else 'FAIL'}"
            )
            seated_any = True
        if not seated_any:
            continue
        staged = STAGE / slug / f"city_{slug}_area_v02.png"
        staged.parent.mkdir(parents=True, exist_ok=True)
        plate.save(staged, compress_level=3)
        plate.resize((2048, 1536), Image.Resampling.LANCZOS).save(
            STAGE / slug / f"city_{slug}_area_v02_preview.png"
        )
        grade = projection.grade(staged)
        print(
            f"{slug}: projection {grade['peak_pos']:+.2f}/{grade['peak_neg']:+.2f} "
            f"Δ{grade['worst_delta']:.2f}°"
        )
        if grade["worst_delta"] > projection.TOLERANCE_DEG:
            print(f"  REJECT {slug}: off lock")
            failed += 1
            continue
        spec = ward.DISTRICTS[slug]
        light_path = STAGE / slug / f"{spec['area']}.lm.png"
        map_path = STAGE / slug / spec["map"]
        ward.bake_light(plate).save(light_path)
        ward.hud_map(plate).save(map_path)
        if install:
            install_copy(staged, installed)
            install_copy(light_path, AREAS / f"{spec['area']}.lm.png")
            install_copy(map_path, MAPS / spec["map"])
            print(f"  installed {installed.name}")
    return failed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("districts", nargs="*", default=list(qa.DISTRICTS))
    parser.add_argument("--extract", action="store_true")
    parser.add_argument("--seat", action="store_true")
    parser.add_argument("--install", action="store_true")
    parser.add_argument(
        "--from-staged",
        action="store_true",
        help="extract/seat against UnifiedPlates instead of the installed play plate",
    )
    args = parser.parse_args()
    if args.extract:
        extract(args.districts, args.from_staged)
    if args.seat:
        failed = seat(args.districts, args.install, args.from_staged)
        if failed:
            return 1
    if not args.extract and not args.seat:
        parser.error("pass --extract and/or --seat")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
