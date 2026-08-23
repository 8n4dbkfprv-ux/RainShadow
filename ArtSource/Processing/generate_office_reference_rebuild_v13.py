#!/usr/bin/env python3
"""Build the V13 office architecture with an ImageGen-painted window pair.

V12 remains the projection, room silhouette, material and fireplace authority.
One ImageGen edit reconstructs the plaster beneath the two V12 windows; a second
precise-object edit paints the final, taller period casements in place.  Only
two small registered neighbourhoods from that second edit are admitted, so the
camera, silhouette, floor, fireplace and all other pixels remain deterministic.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import generate_office_reference_rebuild_v12 as v12


ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "ArtSource/Generated/Office/BGEEReferenceV13"
V12_SOURCE = (
    ROOT
    / "ArtSource/Generated/Office/BGEEReferenceV12"
    / "office_reference_rebuild_source_v12.png"
)
WINDOWLESS_SOURCE = STAGE / "office_windowless_wall_source_v13.png"
IMAGEGEN_WINDOW_EDIT = STAGE / "office_windows_imagegen_edit_v13.png"
SOURCE = STAGE / "office_reference_rebuild_source_v13.png"

FILENAMES = {
    "plate": "office_reference_rebuild_plate_v13.png",
    "architectureMask": "office_reference_rebuild_architecture_mask_v13.png",
    "glassMask": "office_window_glass_mask_v13.png",
    "nearHover": "office_window_near_hover_overlay_v13.png",
    "metrics": "office_reference_rebuild_metrics_v13.json",
}

# The final windows were painted together by ImageGen on the locked V13 source.
# Their centres retain the evenly distributed V13 bays, while their frames are
# taller and have naturally varied weathering instead of being pixel-identical
# copies.  The far frame is one wall-axis translation from the near frame.
NW_WALL_X0 = min(point[0] for point in v12.SOURCE_PLANES["NW"])
NW_WALL_X1 = max(point[0] for point in v12.SOURCE_PLANES["NW"])
WINDOW_TRANSLATIONS = {"near": (0.0, 0.0), "far": (182.0, -136.5)}
WINDOW_FRAME_POLYGONS = {
    "near": [[491.0, 382.0], [562.0, 329.0], [562.0, 415.0], [491.0, 465.0]],
    "far": [[673.0, 245.5], [744.0, 192.5], [744.0, 278.5], [673.0, 328.5]],
}
WINDOW_EDIT_POLYGONS = [
    [[484.0, 381.0], [570.0, 317.0], [570.0, 431.0], [484.0, 495.0]],
    [[666.0, 244.5], [752.0, 180.0], [752.0, 294.0], [666.0, 358.5]],
]
WINDOW_CLEAR_GAPS = [
    min(point[0] for point in WINDOW_FRAME_POLYGONS["near"]) - NW_WALL_X0,
    min(point[0] for point in WINDOW_FRAME_POLYGONS["far"])
    - max(point[0] for point in WINDOW_FRAME_POLYGONS["near"]),
    NW_WALL_X1 - max(point[0] for point in WINDOW_FRAME_POLYGONS["far"]),
]

# Full repair envelopes for the two V12 windows.  They include each old frame,
# sill and local shadow; admitted cleanup remains clipped to the measured room.
OLD_WINDOW_REPAIR_POLYGONS = [
    [[386.0, 452.0], [452.0, 407.0], [452.0, 477.0], [386.0, 517.0]],
    [[655.0, 271.0], [727.0, 219.0], [727.0, 292.0], [655.0, 339.0]],
]


def _shifted(points: list[list[float]], dx: float, dy: float) -> list[list[float]]:
    return [[x + dx, y + dy] for x, y in points]


NEAR_APERTURE = [[503.0, 378.0], [551.0, 342.0], [551.0, 408.0], [503.0, 444.0]]
NEAR_GLASS = [
    [[506.0, 380.0], [526.0, 365.0], [526.0, 381.0], [506.0, 396.0]],
    [[506.0, 400.0], [526.0, 385.0], [526.0, 401.0], [506.0, 416.0]],
    [[506.0, 420.0], [526.0, 405.0], [526.0, 421.0], [506.0, 436.0]],
    [[530.0, 362.0], [549.0, 348.0], [549.0, 364.0], [530.0, 378.0]],
    [[530.0, 382.0], [549.0, 368.0], [549.0, 384.0], [530.0, 398.0]],
    [[530.0, 402.0], [549.0, 388.0], [549.0, 404.0], [530.0, 418.0]],
]


SOURCE_WINDOWS = [
    {
        "id": "far",
        "aperture": _shifted(NEAR_APERTURE, *WINDOW_TRANSLATIONS["far"]),
        "glass": [
            _shifted(pane, *WINDOW_TRANSLATIONS["far"]) for pane in NEAR_GLASS
        ],
    },
    {"id": "near", "aperture": NEAR_APERTURE, "glass": NEAR_GLASS},
]


def _polygon_mask(
    size: tuple[int, int],
    polygons: list[list[list[float]]],
    *,
    blur: float = 0.0,
) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon([tuple(point) for point in polygon], fill=255)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(radius=blur))
    return mask


def _padded_windowless_source() -> Image.Image:
    image = Image.open(WINDOWLESS_SOURCE).convert("RGB")
    if image.size == (1671, 941):
        padded = Image.new("RGB", (1672, 941), (0, 0, 0))
        padded.paste(image, (0, 0))
        return padded
    if image.size != (1672, 941):
        raise RuntimeError(
            "V13 windowless source must be the frozen 1671x941 edit "
            f"(or its 1672x941 padded form), got {image.size}"
        )
    return image


def prepare_source() -> Path:
    base = Image.open(V12_SOURCE).convert("RGB")
    cleanup = _padded_windowless_source()
    imagegen_windows = Image.open(IMAGEGEN_WINDOW_EDIT).convert("RGB")
    if base.size != (1672, 941):
        raise RuntimeError("V13 base must be the frozen 1672x941 V12 frame")
    if imagegen_windows.size != base.size:
        raise RuntimeError(
            "V13 ImageGen window edit must preserve the 1672x941 source canvas"
        )

    nw_wall = _polygon_mask(base.size, [v12.SOURCE_PLANES["NW"]])
    room = _polygon_mask(base.size, list(v12.SOURCE_PLANES.values()))
    repair_envelope = _polygon_mask(
        base.size,
        OLD_WINDOW_REPAIR_POLYGONS,
        blur=0.8,
    )

    # The generated source is a purpose-built windowless wall.  Admit its whole
    # NW face, clipped to the measured wall polygon, instead of feathering two
    # rectangular patches into V12 plaster.  That keeps the wall texture
    # continuous while V12 still owns every other plane.  Only the narrow local
    # sill/shadow residue below the old windows uses the smaller room envelope.
    repaired = Image.composite(cleanup, base, nw_wall)
    floor = _polygon_mask(base.size, [v12.SOURCE_PLANES["floor"]])
    floor_repair = ImageChops.multiply(repair_envelope, floor)
    repaired = Image.composite(cleanup, repaired, floor_repair)

    # Pixels outside the measured room are explicitly black, so neither an old
    # protruding frame nor the generated edit can nick or enlarge the silhouette.
    exterior_repair = ImageChops.subtract(repair_envelope, room)
    repaired = Image.composite(
        Image.new("RGB", base.size, (0, 0, 0)),
        repaired,
        exterior_repair,
    )

    # Admit only the two ImageGen-painted window neighbourhoods.  The edit was
    # made against this exact source, but ImageGen still introduces low-level
    # drift across a full frame.  This mask makes every unrelated source pixel
    # bit-identical while keeping the generated reveals, sills and shadows.
    window_edit_mask = _polygon_mask(
        base.size, WINDOW_EDIT_POLYGONS, blur=1.1
    )
    window_edit_mask = ImageChops.multiply(window_edit_mask, room)
    source = Image.composite(imagegen_windows, repaired, window_edit_mask)

    STAGE.mkdir(parents=True, exist_ok=True)
    source.save(SOURCE, format="PNG", optimize=False)
    return SOURCE


def build_assets() -> dict[str, Image.Image | dict[str, object]]:
    prepare_source()
    v12.SOURCE = SOURCE
    v12.SOURCE_WINDOWS = SOURCE_WINDOWS
    assets = v12.build_assets()
    metrics = assets["metrics"]
    assert isinstance(metrics, dict)
    metrics["version"] = "BGEEReferenceV13"
    metrics["geometryAuthority"] = str(metrics["geometryAuthority"]).replace(
        "V12 registered source", "V13 registered source"
    )
    registration = metrics["registration"]
    assert isinstance(registration, dict)
    for key in ("visualSilhouetteAuthority", "navigationGeometryAuthority"):
        registration[key] = str(registration[key]).replace("V12", "V13")
    metrics["windowPair"] = {
        "interactiveWindow": "near",
        "decorativeWindow": "far",
        "sourceTranslations": {key: list(value) for key, value in WINDOW_TRANSLATIONS.items()},
        "wallAxisSlope": -0.75,
        "usableWallSpanX": [NW_WALL_X0, NW_WALL_X1],
        "framePolygons": WINDOW_FRAME_POLYGONS,
        "clearGapsAlongSourceX": WINDOW_CLEAR_GAPS,
        "placementRule": "even wall-axis bays with natural ImageGen frame variation",
        "geometry": "two jointly painted six-pane period casements",
        "nearHoverWindowIds": ["near"],
        "rainMaskWindowIds": ["near", "far"],
    }
    metrics["wallRepair"] = {
        "source": str(WINDOWLESS_SOURCE.relative_to(ROOT)),
        "sourceSha256": v12.sha256(WINDOWLESS_SOURCE),
        "sourceSize": list(Image.open(WINDOWLESS_SOURCE).size),
        "admission": "complete measured NW wall face plus former-sill floor envelopes",
        "windowInsertClip": "measured NW wall face",
        "exteriorPolicy": "pure black outside registered room polygons",
    }
    metrics["sourceProvenance"] = {
        "base": str(V12_SOURCE.relative_to(ROOT)),
        "baseSha256": v12.sha256(V12_SOURCE),
        "windowlessRepair": str(WINDOWLESS_SOURCE.relative_to(ROOT)),
        "windowlessRepairSha256": v12.sha256(WINDOWLESS_SOURCE),
        "repairAdmission": "complete measured NW wall face; local former-sill floor envelopes",
        "imagegenWindowEdit": str(IMAGEGEN_WINDOW_EDIT.relative_to(ROOT)),
        "imagegenWindowEditSha256": v12.sha256(IMAGEGEN_WINDOW_EDIT),
        "imagegenAdmission": "two feathered, room-clipped window neighbourhoods only",
    }
    source = metrics["source"]
    assert isinstance(source, dict)
    source["role"] = (
        "V12 architecture plus localized ImageGen plaster repair and two "
        "localized ImageGen-painted period casements"
    )
    return assets


def write_assets(output_dir: Path = STAGE) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    assets = build_assets()
    paths: dict[str, Path] = {}
    for key in ("plate", "architectureMask", "glassMask", "nearHover"):
        image = assets[key]
        assert isinstance(image, Image.Image)
        path = output_dir / FILENAMES[key]
        image.save(path, format="PNG", optimize=False)
        paths[key] = path
    metrics = assets["metrics"]
    assert isinstance(metrics, dict)
    metrics["outputHashes"] = {path.name: v12.sha256(path) for path in paths.values()}
    metrics_path = output_dir / FILENAMES["metrics"]
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    paths["metrics"] = metrics_path
    return paths


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=STAGE)
    args = parser.parse_args()
    for path in write_assets(args.output_dir.resolve()).values():
        try:
            label = path.relative_to(ROOT)
        except ValueError:
            label = path
        print(f"wrote {label}")


if __name__ == "__main__":
    main()
