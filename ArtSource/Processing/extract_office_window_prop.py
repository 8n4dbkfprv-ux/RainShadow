"""Deprecated crop-from-shell window extract.

V4 ships a true separate window assembly generated with the Image Generator.
This wrapper keeps older docs/commands working by delegating to
`process_office_window_door_v04.py`.
"""

from pathlib import Path
import runpy


if __name__ == "__main__":
    runpy.run_path(
        str(Path(__file__).with_name("process_office_window_door_v04.py")),
        run_name="__main__",
    )
