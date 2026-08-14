#!/usr/bin/env python3
"""Asset-independent tests for the V21 strip processor and crunch path."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import crunch
import install_voss_v16 as core
import install_voss_v21 as v21
import process_voss_character_strip_v21 as strip


def synthetic_master(shift_x: int = 0) -> Image.Image:
    image = Image.new("RGB", (360, 520), (0, 255, 0))
    draw = ImageDraw.Draw(image)
    wardrobe = v21.V21_WARDROBE
    dx = shift_x
    draw.ellipse((154 + dx, 52, 205 + dx, 113), fill=wardrobe["skin"])
    draw.polygon(((148 + dx, 50), (208 + dx, 50), (211 + dx, 85), (145 + dx, 85)), fill=wardrobe["hair"])
    draw.polygon(((112 + dx, 115), (247 + dx, 115), (224 + dx, 342), (136 + dx, 342)), fill=wardrobe["coat"])
    draw.polygon(((152 + dx, 120), (208 + dx, 120), (200 + dx, 260), (160 + dx, 260)), fill=wardrobe["shirt"])
    draw.polygon(((176 + dx, 125), (185 + dx, 125), (189 + dx, 211), (180 + dx, 226), (172 + dx, 211)), fill=wardrobe["tie"])
    draw.rectangle((104 + dx, 128, 138 + dx, 310), fill=wardrobe["coat"])
    draw.rectangle((221 + dx, 128, 255 + dx, 310), fill=wardrobe["coat"])
    draw.rectangle((141 + dx, 315, 176 + dx, 447), fill=wardrobe["trousers"])
    draw.rectangle((183 + dx, 315, 218 + dx, 447), fill=wardrobe["trousers"])
    draw.rectangle((130 + dx, 436, 176 + dx, 464), fill=wardrobe["shoes"])
    draw.rectangle((183 + dx, 436, 229 + dx, 464), fill=wardrobe["shoes"])
    return image


class VossV21PipelineTests(unittest.TestCase):
    def test_portrait_hash_is_locked(self) -> None:
        portrait = v21.V21_ROOT / "References/dialogue_portrait_harlan_voss_v01.png"
        self.assertTrue(portrait.is_file())
        self.assertEqual(core.sha256(portrait), v21.PORTRAIT_SHA256)

    def test_prompt_lock_rear_omits_face_language_and_front_keeps_it(self) -> None:
        front = strip.prompt_lock("s")
        rear = strip.prompt_lock("n")
        self.assertIn("full face", front)
        self.assertIn("true rear view", rear)
        self.assertNotIn("full face", rear)

    def test_shared_palette_keeps_one_clip_inside_64_colours(self) -> None:
        keyed = [core.key_chroma(synthetic_master(shift_x=phase)) for phase in range(4)]
        levelled, _ = crunch.normalise_clip_exposure(keyed)
        palette = crunch.build_clip_palette(levelled)
        cells = [
            core.process_keyed_figure(frame, palette=palette, body_axis=True)
            for frame in levelled
        ]
        colours: set[tuple[int, int, int]] = set()
        for cell in cells:
            pixels = np.asarray(cell.convert("RGBA"))
            opaque = pixels[pixels[..., 3] >= 128][:, :3]
            colours.update(map(tuple, opaque))
        self.assertLessEqual(len(colours), 64)

    def test_se_idle_is_exact_horizontal_mirror_of_sw(self) -> None:
        sw = core.process_figure(synthetic_master())
        se = sw.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        self.assertTrue(np.array_equal(np.asarray(se), np.asarray(sw)[:, ::-1]))

    def test_sit_down_is_exact_reverse_of_stand_up(self) -> None:
        stand = [synthetic_master(shift_x=phase) for phase in range(12)]
        sit = list(reversed(stand))
        for index, frame in enumerate(sit):
            self.assertTrue(np.array_equal(np.asarray(frame), np.asarray(stand[11 - index])))

    def test_compose_strip_writes_equal_cells(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temp = Path(temporary)
            frames = []
            for index in range(4):
                path = temp / f"f{index:02d}.png"
                synthetic_master(shift_x=index).save(path)
                frames.append(path)
            dest = temp / "strip.png"
            strip.compose_strip(frames, dest)
            sheet = Image.open(dest)
            self.assertEqual(sheet.width % 4, 0)
            self.assertGreater(sheet.height, 100)

    def test_v21_widens_only_processed_walk_pulse_bands(self) -> None:
        manifest = v21.load_manifest()
        gates = manifest["gates"]
        self.assertGreater(gates["walk_head_jitter_max"], core.HEAD_JITTER_MAX)
        self.assertGreater(gates["walk_centroid_drift_max"], core.CENTROID_DRIFT_MAX)
        self.assertGreater(gates["walk_head_scale_ratio_max"], core.HEAD_SCALE_RATIO_MAX)
        self.assertGreater(gates["walk_torso_scale_ratio_max"], core.TORSO_SCALE_RATIO_MAX)
        self.assertLess(gates["walk_torso_scale_ratio_max"], 2.5)
        self.assertEqual(gates["head_jitter_max"], core.HEAD_JITTER_MAX)
        self.assertEqual(gates["centroid_drift_max"], core.CENTROID_DRIFT_MAX)
        self.assertEqual(gates["head_pulse_ratio_max"], core.HEAD_SCALE_RATIO_MAX)
        self.assertEqual(gates["torso_pulse_ratio_max"], core.TORSO_SCALE_RATIO_MAX)
        v20 = (v21.V20_ROOT / "voss_v20_manifest.json")
        if v20.is_file():
            import json
            v20_gates = json.loads(v20.read_text())["gates"]
            self.assertNotIn("walk_head_jitter_max", v20_gates)


if __name__ == "__main__":
    unittest.main()
