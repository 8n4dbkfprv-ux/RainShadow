#!/usr/bin/env python3
"""Asset-independent tests for the V18 portrait-first Imagine contract."""

from __future__ import annotations

import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image, ImageDraw

PROCESSING_DIR = Path(__file__).resolve().parent
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v18 as v18


def synthetic_master() -> Image.Image:
    image = Image.new("RGB", (360, 520), (0, 255, 0))
    draw = ImageDraw.Draw(image)
    wardrobe = v18.V18_WARDROBE
    draw.ellipse((154, 52, 205, 113), fill=wardrobe["skin"])
    draw.polygon(((148, 50), (208, 50), (211, 85), (145, 85)), fill=wardrobe["hair"])
    draw.polygon(((112, 115), (247, 115), (224, 342), (136, 342)), fill=wardrobe["coat"])
    draw.polygon(((152, 120), (208, 120), (200, 260), (160, 260)), fill=wardrobe["shirt"])
    draw.polygon(((176, 125), (185, 125), (189, 211), (180, 226), (172, 211)), fill=wardrobe["tie"])
    draw.rectangle((104, 128, 138, 310), fill=wardrobe["coat"])
    draw.rectangle((221, 128, 255, 310), fill=wardrobe["coat"])
    draw.rectangle((141, 315, 176, 447), fill=wardrobe["trousers"])
    draw.rectangle((183, 315, 218, 447), fill=wardrobe["trousers"])
    draw.rectangle((130, 436, 176, 464), fill=wardrobe["shoes"])
    draw.rectangle((183, 436, 229, 464), fill=wardrobe["shoes"])
    return image


class VossV18PipelineTests(unittest.TestCase):
    def test_manifest_expands_to_exact_runtime_contract(self) -> None:
        manifest = v18.load_manifest()
        specs = v18.master_specs(manifest)
        self.assertEqual(len(specs), 148)
        self.assertEqual(len({spec.filename for spec in specs}), 148)
        runtime = v18.expected_runtime_names()
        self.assertEqual({name: len(files) for name, files in runtime.items()}, manifest["runtime"])
        self.assertEqual(sum(map(len, runtime.values())), 208)
        self.assertTrue(all("_v18.png" in spec.filename for spec in specs))

    def test_reference_hashes_include_portrait_authority(self) -> None:
        hashes = v18.validate_references(v18.load_manifest())
        self.assertEqual(len(hashes), 4)
        self.assertIn("References/dialogue_portrait_harlan_voss_v01.png", hashes)
        self.assertTrue(all(len(value) == 64 for value in hashes.values()))

    def test_material_targets_are_lab_and_luminance_separated(self) -> None:
        manifest = v18.load_manifest()
        report = v18.material_separation_report(v18.key_chroma(synthetic_master()), manifest)
        self.assertGreaterEqual(
            report["minimum_target_delta_e"], manifest["material_gates"]["minimum_target_delta_e"]
        )
        self.assertLessEqual(
            max(report["delta_e_05_percentile"].values()),
            manifest["material_gates"]["maximum_delta_e"],
        )

    def test_chroma_key_keeps_black_tie_and_removes_green(self) -> None:
        image = Image.new("RGB", (32, 32), (0, 255, 0))
        ImageDraw.Draw(image).rectangle((13, 4, 18, 27), fill=v18.V18_WARDROBE["tie"])
        keyed = np.asarray(v18.key_chroma(image))
        self.assertEqual(int(keyed[0, 0, 3]), 0)
        self.assertEqual(int(keyed[12, 15, 3]), 255)

    def test_v14_registration_is_200px_hard_alpha(self) -> None:
        cell = v18.process_figure(synthetic_master())
        metrics = v18.frame_metrics(cell)
        self.assertIn(metrics.height, range(198, 203))
        self.assertEqual(metrics.foot_y, 433)
        self.assertLessEqual(abs(metrics.center_x - 255.5), 2.0)
        self.assertSetEqual(set(np.unique(np.asarray(cell)[..., 3]).tolist()), {0, 1, 255})

    def test_sit_down_is_exact_stand_up_reversal(self) -> None:
        stand = [Image.new("RGBA", (4, 4), (phase, 0, 0, 255)) for phase in range(12)]
        sit = v18.derive_sit_down(stand)
        for phase, cell in enumerate(sit):
            self.assertTrue(np.array_equal(np.asarray(cell), np.asarray(stand[11 - phase])))

    def test_compatibility_layer_union_is_exact(self) -> None:
        cell = v18.process_figure(synthetic_master())
        upper, lower = v18.split_upper_lower(cell)
        union = v18.visible_mask(upper) | v18.visible_mask(lower)
        self.assertTrue(np.array_equal(union, v18.visible_mask(cell)))

    def test_ui_dimensions_and_modes(self) -> None:
        hashes = v18.validate_ui_sources(v18.load_manifest())
        self.assertEqual(len(hashes), 2)

    def test_transaction_rolls_back_deliberate_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old_a, old_b = root / "runtime-atlas", root / "runtime-ui.png"
            new_a, new_b = root / "stage-atlas", root / "stage-ui.png"
            old_a.mkdir()
            new_a.mkdir()
            (old_a / "cell.png").write_bytes(b"old-atlas")
            (new_a / "cell.png").write_bytes(b"new-atlas")
            old_b.write_bytes(b"old-b")
            new_b.write_bytes(b"new-b")
            with self.assertRaisesRegex(RuntimeError, "deliberate V18"):
                v18._swap_payload_transaction(
                    ((new_a, old_a), (new_b, old_b)), fail_after=1
                )
            self.assertEqual((old_a / "cell.png").read_bytes(), b"old-atlas")
            self.assertEqual(old_b.read_bytes(), b"old-b")

    @unittest.skipUnless(hasattr(os, "chflags"), "filesystem flags are a macOS contract")
    def test_transaction_clears_hidden_flag_from_installed_png(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, destination = root / "stage.png", root / "runtime.png"
            source.write_bytes(b"new")
            destination.write_bytes(b"old")
            os.chflags(source, source.stat().st_flags | stat.UF_HIDDEN)
            v18._swap_payload_transaction(((source, destination),))
            self.assertFalse(destination.stat().st_flags & stat.UF_HIDDEN)

    def test_manifest_rejects_old_mustard_identity(self) -> None:
        manifest = json.loads(v18.MANIFEST_PATH.read_text(encoding="utf-8"))
        manifest["wardrobe"]["waistcoat"] = "#9C7730"
        with self.assertRaises(v18.V18ValidationError):
            v18.validate_manifest_contract(manifest)

    def test_manifest_requires_portrait_reference(self) -> None:
        manifest = json.loads(v18.MANIFEST_PATH.read_text(encoding="utf-8"))
        del manifest["references"]["dialogue_portrait_harlan_voss_v01.png"]
        with self.assertRaises(v18.V18ValidationError):
            v18.validate_manifest_contract(manifest)

    def test_v18_root_is_isolated_from_v17(self) -> None:
        self.assertIn("PreRendered3DV18", str(v18.V18_ROOT))
        self.assertNotIn("PreRendered3DV17", str(v18.V18_ROOT))
        self.assertTrue((v18.V18_ROOT / "References" / "dialogue_portrait_harlan_voss_v01.png").is_file())


if __name__ == "__main__":
    unittest.main()
