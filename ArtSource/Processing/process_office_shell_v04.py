"""Deprecated V4 patch-composite shell builder.

V4 local recess/doorway pastes produced black-box artifacts and are rejected.
Shipping shells must be one-shot Image Generator plates (see V5), then resized here.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "ArtSource" / "Generated" / "Office" / "office_shell_base_v06.png"
RUNTIME = (
    ROOT
    / "RainShadow Shared"
    / "Resources"
    / "Art"
    / "Areas"
    / "DetectiveOffice"
    / "office_shell_base.png"
)


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(f"Missing approved master: {MASTER}")
    master = Image.open(MASTER).convert("RGB")
    if master.size != (3840, 2160):
        master = master.resize((3840, 2160), Image.Resampling.LANCZOS)
        master.save(MASTER)
    runtime = master.resize((4096, 2304), Image.Resampling.LANCZOS)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(RUNTIME)
    print("exported", RUNTIME, runtime.size)
    print("NOTE: do not patch-composite openings into the shell.")


if __name__ == "__main__":
    main()
