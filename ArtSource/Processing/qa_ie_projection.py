#!/usr/bin/env python3
"""QA: projection constants, and that the pipeline agrees with the active camera.

Two separate things are checked:

1. The BG:EE camera is described correctly (a fact, independent of what is
   currently active).
2. Every pipeline module derives its geometry from `ie_projection.ACTIVE`, so
   flipping one constant moves the whole pipeline together rather than leaving
   the nav grid fitted to a plate the painting does not have.

Run: python3 ArtSource/Processing/qa_ie_projection.py
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ie_projection as ie
import office_room_plan as rp
import office_layout_plan as ol
import process_ui_selection_rings as rings
import process_ui_move_markers as markers


# Axis fit of the installed legacy plate. Held here so a silent edit to
# office_room_plan shows up as a failure rather than as drifted furniture.
INSTALLED_AXIS_NW = (-555.54, 311.86)
INSTALLED_AXIS_NE = (812.23, 386.20)
INSTALLED_REAR = (1932.1, 752.4)


def check_bgee_spec() -> list[str]:
    """The target camera, whether or not it is active."""
    errors = []
    b = ie.BGEE
    if abs(b.ground_foreshorten - 0.75) > 1e-15:
        errors.append("BGEE ground foreshortening should be 0.75")
    if abs(b.height_foreshorten - math.sqrt(1 - 0.75**2)) > 1e-12:
        errors.append("BGEE height foreshortening")
    if abs(b.elevation_deg - 48.5903778907) > 1e-6:
        errors.append("BGEE elevation should be asin(0.75)")
    if abs(b.ground_axis_deg - 36.8698976458) > 1e-6:
        errors.append("BGEE ground axis should be atan(0.75)")
    if abs(b.ellipse_ratio - ie.ELLIPSE_A / ie.ELLIPSE_B) > 1e-12:
        errors.append("BGEE ground circle should be a 16:12 ellipse")
    if b.diamond != (128, 96) or b.half_step != (64, 48):
        errors.append("BGEE diamond should be 128x96")
    # The diamond must tile the runtime search grid exactly.
    if b.diamond[0] / ie.ELLIPSE_A != 8 or b.diamond[1] / ie.ELLIPSE_B != 8:
        errors.append("BGEE diamond should span exactly 8x8 SearchMap cells")
    return errors


def check_active_consistency() -> list[str]:
    """Every module must follow ACTIVE, and the room plan must match the art."""
    errors = []
    a = ie.ACTIVE

    if (ie.DIAMOND_W, ie.DIAMOND_H) != a.diamond:
        errors.append("module diamond aliases drifted from ACTIVE")
    if ol.CELL_RECT != a.cell_rect:
        errors.append("layout CELL_RECT drifted from ACTIVE")
    if ol.PARTITION_CELL_RECT != a.partition_cell_rect:
        errors.append("layout PARTITION_CELL_RECT drifted from ACTIVE")
    if rings.RING_SIZE != a.ring_size:
        errors.append("selection ring canvas drifted from ACTIVE")
    if markers.MARKER_SIZE != a.ring_size or markers.PIP_SIZE != a.pip_size:
        errors.append("move marker canvases drifted from ACTIVE")
    if abs(ie.GRAYBOX_SKEW - a.graybox_skew) > 1e-12:
        errors.append("graybox skew alias drifted from ACTIVE")
    if abs(ie.FG_WALL_SKEW - a.fg_wall_skew) > 1e-12:
        errors.append("foreground wall skew alias drifted from ACTIVE")
    if abs(ie.BOX_DEPTH_FRAC - a.box_depth_frac) > 1e-12:
        errors.append("iso box depth fraction drifted from ACTIVE")
    if abs(ie.ground_shear_for_height(100.0) - 100.0 * a.graybox_skew) > 1e-9:
        errors.append("ground_shear_for_height does not follow ACTIVE")

    # Cell round-trip on the active diamond.
    for c, r in ((0, 0), (1, 0), (0, 1), (3, 5), (-2, 4)):
        p = ie.cell_to_authored(c, r, origin_y=100.0)
        if ie.authored_to_cell(*p, origin_y=100.0) != (c, r):
            errors.append(f"cell round-trip failed for {(c, r)}")

    # The room plan is a measurement of the installed plate. Its axes may only
    # move to the BG:EE slopes when ACTIVE says the art moved too.
    if a is ie.BGEE:
        for name, axis in (("AXIS_NW", rp.AXIS_NW), ("AXIS_NE", rp.AXIS_NE)):
            slope = abs(axis[1] / axis[0])
            if abs(slope - ie.BGEE.ground_slope) > 1e-9:
                errors.append(
                    f"ACTIVE is BGEE but room plan {name} slope is {slope:.4f}, "
                    "not 0.75 — re-fit the room plan to the new plate"
                )
    else:
        if rp.AXIS_NW != INSTALLED_AXIS_NW or rp.AXIS_NE != INSTALLED_AXIS_NE:
            errors.append(
                "room plan axes no longer match the installed plate fit; "
                "adopting BG:EE slopes here without new art moves the floor "
                "diamond off the painting"
            )
        if rp.REAR != INSTALLED_REAR:
            errors.append("room plan REAR no longer matches the installed plate fit")
    return errors


def main() -> int:
    errors = check_bgee_spec() + check_active_consistency()

    print(f"active camera: {ie.ACTIVE.name}")
    print(
        f"  ground axes +-{ie.GROUND_AXIS_DEG:.2f} deg, diamond "
        f"{ie.DIAMOND_W}x{ie.DIAMOND_H}, ground circle "
        f"{ie.ACTIVE.ellipse_ratio:.3f}:1"
    )
    print(f"target camera: {ie.BGEE.name}")
    print(
        f"  ground axes +-{ie.BGEE.ground_axis_deg:.2f} deg, diamond "
        f"{ie.BGEE.diamond[0]}x{ie.BGEE.diamond[1]}, ground circle "
        f"{ie.BGEE.ellipse_ratio:.3f}:1"
    )
    if ie.ACTIVE is not ie.BGEE:
        print(
            "  adoption pending: flip ie_projection.ACTIVE to BGEE together "
            "with on-lock masters"
        )
    print()

    if not ol.report():
        errors.append("office_layout_plan.report() failed")

    if errors:
        print("\nFAIL:")
        for e in errors:
            print(" ", e)
        return 1
    print("\nqa_ie_projection PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
