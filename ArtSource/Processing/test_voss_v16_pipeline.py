#!/usr/bin/env python3
"""Focused, asset-independent tests for the V16 manifest and raster plumbing."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image, ImageDraw

PROCESSING_DIR = Path(__file__).resolve().parent
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v16 as v16


def synthetic_master() -> Image.Image:
    image = Image.new("RGB", (360, 520), (0, 255, 0))
    draw = ImageDraw.Draw(image)
    # One connected, 0.42-width/body-height Voss-like silhouette with all locked
    # materials represented.  Geometry is intentionally plain; these tests cover
    # raster invariants, not ImageGen quality.
    draw.ellipse((154, 60, 205, 115), fill=v16.crunch.WARDROBE["skin"])
    draw.rectangle((145, 92, 214, 135), fill=v16.crunch.WARDROBE["hair"])
    draw.polygon(((115, 120), (244, 120), (218, 325), (141, 325)), fill=v16.crunch.WARDROBE["coat"])
    draw.polygon(((145, 125), (214, 125), (205, 250), (154, 250)), fill=v16.crunch.WARDROBE["waistcoat"])
    draw.polygon(((164, 126), (195, 126), (190, 210), (169, 210)), fill=v16.crunch.WARDROBE["shirt"])
    draw.polygon(((176, 128), (184, 128), (187, 198), (179, 216), (172, 198)), fill=v16.crunch.WARDROBE["tie"])
    draw.rectangle((105, 130, 134, 305), fill=v16.crunch.WARDROBE["coat"])
    draw.rectangle((225, 130, 254, 305), fill=v16.crunch.WARDROBE["coat"])
    draw.rectangle((143, 315, 177, 445), fill=v16.crunch.WARDROBE["trousers"])
    draw.rectangle((182, 315, 216, 445), fill=v16.crunch.WARDROBE["trousers"])
    draw.rectangle((133, 435, 177, 460), fill=v16.crunch.WARDROBE["shoes"])
    draw.rectangle((182, 435, 226, 460), fill=v16.crunch.WARDROBE["shoes"])
    return image


class VossV16PipelineTests(unittest.TestCase):
    def test_manifest_expands_to_exact_contract(self) -> None:
        manifest = v16.load_manifest()
        specs = v16.master_specs(manifest)
        self.assertEqual(len(specs), 148)
        self.assertEqual(len({spec.filename for spec in specs}), 148)
        runtime = v16.expected_runtime_names()
        self.assertEqual({name: len(files) for name, files in runtime.items()}, manifest["runtime"])
        self.assertEqual(sum(map(len, runtime.values())), 208)
        self.assertEqual(sum(len(set(files)) for files in runtime.values()), 208)

    def test_manifest_requires_wardrobe_preservation(self) -> None:
        manifest = json.loads(v16.MANIFEST_PATH.read_text(encoding="utf-8"))
        manifest["processing"]["preserve_wardrobe"] = False
        with self.assertRaises(v16.V16ValidationError):
            v16.validate_manifest_contract(manifest)
        self.assertTrue(v16.crunch.PRESERVE_WARDROBE)

    def test_chroma_key_keeps_the_dark_green_tie(self) -> None:
        image = Image.new("RGB", (32, 32), (0, 255, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((13, 4, 18, 27), fill=v16.crunch.WARDROBE["tie"])
        keyed = np.asarray(v16.key_chroma(image))
        self.assertEqual(int(keyed[0, 0, 3]), 0)
        self.assertEqual(int(keyed[12, 15, 3]), 255)
        self.assertTupleEqual(tuple(int(value) for value in keyed[12, 15, :3]), (54, 70, 54))

    def test_v14_process_registers_hard_alpha_200px_body(self) -> None:
        cell = v16.process_figure(synthetic_master())
        self.assertEqual(cell.size, (512, 512))
        metrics = v16.frame_metrics(cell)
        self.assertIn(metrics.height, range(198, 203))
        self.assertEqual(metrics.foot_y, 433)
        self.assertLessEqual(abs(metrics.center_x - 255.5), 2.0)
        alpha = np.asarray(cell)[..., 3]
        self.assertSetEqual(set(np.unique(alpha).tolist()), {0, 1, 255})
        self.assertListEqual(
            [int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])],
            [1, 1, 1, 1],
        )
        colors = np.unique(np.asarray(cell)[..., :3][v16.visible_mask(cell)], axis=0)
        self.assertLessEqual(len(colors), 64)

    def test_ne_compatibility_split_preserves_full_silhouette_union(self) -> None:
        cell = v16.process_figure(synthetic_master())
        upper, lower = v16.split_upper_lower(cell)
        union = v16.visible_mask(upper) | v16.visible_mask(lower)
        self.assertTrue(np.array_equal(union, v16.visible_mask(cell)))
        for layer in (upper, lower):
            alpha = np.asarray(layer)[..., 3]
            self.assertFalse(set(np.unique(alpha).tolist()) - {0, 1, 255})

    def test_raster_validator_accepts_synthetic_cell(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "cell.png"
            v16.save_png(v16.process_figure(synthetic_master()), path)
            errors, metrics = v16._validate_raster_cell(path)
            self.assertEqual(errors, [])
            self.assertIsNotNone(metrics)


if __name__ == "__main__":
    unittest.main()
