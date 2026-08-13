#!/usr/bin/env python3
"""Asset-independent tests for the strict V20 processing and swap contract."""

from __future__ import annotations

import ast
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

import numpy as np
from PIL import Image, ImageDraw


PROCESSING_DIR = Path(__file__).resolve().parent
if str(PROCESSING_DIR) not in sys.path:
    sys.path.insert(0, str(PROCESSING_DIR))

import install_voss_v20 as v20
import qa_voss_v20 as qa20


def manifest_scaffold() -> dict:
    return json.loads(v20.MANIFEST_PATH.read_text(encoding="utf-8"))


def synthetic_master() -> Image.Image:
    image = Image.new("RGB", (360, 520), (0, 255, 0))
    draw = ImageDraw.Draw(image)
    wardrobe = v20.V20_WARDROBE
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


class VossV20PipelineTests(unittest.TestCase):
    def test_gate2_facing_order_uses_exact_east_mirrors(self) -> None:
        western: dict[str, Image.Image] = {}
        for index, direction in enumerate(v20.WESTERN_DIRECTIONS):
            pixels = np.zeros((12, 14, 4), dtype=np.uint8)
            pixels[2 + index % 5, 1 + index, :] = (20 + index, 40, 60, 255)
            western[direction] = Image.fromarray(pixels, "RGBA")
        facings = qa20.displayed_facings_from_western(western)
        self.assertEqual(
            [name for name, _ in facings],
            ["s", "sse", "se", "ese", "e", "ene", "ne", "nne", "n", "nnw", "nw", "wnw", "w", "wsw", "sw", "ssw"],
        )
        by_name = dict(facings)
        mirrors = {
            "sse": "ssw",
            "se": "sw",
            "ese": "wsw",
            "e": "w",
            "ene": "wnw",
            "ne": "nw",
            "nne": "nnw",
        }
        for east, west in mirrors.items():
            expected = np.asarray(western[west])[:, ::-1]
            self.assertTrue(np.array_equal(np.asarray(by_name[east]), expected), east)

    def test_gate2_helper_writes_only_stable_named_review_sheets(self) -> None:
        manifest = manifest_scaffold()
        for alias in manifest["key_aliases"].values():
            manifest["master_inventory"][alias]["sha256"] = None
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            keys, qa = root / "Keys", root / "QA"
            keys.mkdir()
            for index, direction in enumerate(v20.WESTERN_DIRECTIONS):
                image = synthetic_master()
                ImageDraw.Draw(image).point((178 + index % 3, 180 + index), fill=(80 + index, 44, 30))
                image.save(keys / f"voss_key_{direction}_chroma_v20.png", format="PNG")
            first = qa20.make_gate2_facing_sheets(manifest, qa=qa, keys_root=keys)
            first_hashes = {path.name: v20.sha256(path) for path in first}
            second = qa20.make_gate2_facing_sheets(manifest, qa=qa, keys_root=keys)
            self.assertEqual(first_hashes, {path.name: v20.sha256(path) for path in second})
            self.assertEqual(
                set(first_hashes),
                {qa20.GATE2_LABELLED_FILENAME, qa20.GATE2_UNLABELLED_FILENAME},
            )
            self.assertNotEqual(
                first_hashes[qa20.GATE2_LABELLED_FILENAME],
                first_hashes[qa20.GATE2_UNLABELLED_FILENAME],
            )
            self.assertEqual({path.name for path in qa.iterdir()}, set(first_hashes))

    def test_manifest_expands_to_exact_authored_and_runtime_contract(self) -> None:
        manifest = manifest_scaffold()
        specs = v20.master_specs(manifest)
        self.assertEqual(len(specs), 148)
        self.assertEqual(len({spec.filename for spec in specs}), 148)
        self.assertTrue(all(spec.filename.endswith("_chroma_v20.png") for spec in specs))
        runtime = v20.expected_runtime_names()
        self.assertEqual({name: len(files) for name, files in runtime.items()}, manifest["runtime"])
        self.assertEqual(sum(map(len, runtime.values())), 208)

    def test_manifest_structural_contract_accepts_mixed_completed_and_pending_masters(self) -> None:
        manifest = manifest_scaffold()
        v20.validate_manifest_contract(manifest)
        digests = [value["sha256"] for value in manifest["master_inventory"].values()]
        completed = [digest for digest in digests if digest is not None]
        pending = [digest for digest in digests if digest is None]
        self.assertEqual(len(completed) + len(pending), 148)
        self.assertTrue(all(v20._valid_digest(digest) for digest in completed))

    def test_v20_runtime_registration_is_whole_cell_and_nw_only(self) -> None:
        manifest = manifest_scaffold()
        self.assertEqual(
            manifest["processing"]["runtime_registration_offsets"],
            {"walk:nw:04": [2, 0], "walk:nw:07": [1, 0]},
        )
        pixels = np.zeros((16, 16, 4), dtype=np.uint8)
        pixels[5:9, 6:10] = (101, 59, 38, 255)
        source = Image.fromarray(pixels, "RGBA")
        shifted = v20.register_runtime_cell(
            source, manifest, group="walk", direction="nw", phase=4
        )
        source_body = np.asarray(source)[..., 3] == 255
        shifted_body = np.asarray(shifted)[..., 3] == 255
        self.assertTrue(np.array_equal(shifted_body[:, 2:], source_body[:, :-2]))
        self.assertFalse(shifted_body[:, :2].any())
        self.assertEqual(set(np.unique(np.asarray(shifted)[..., 3])), {0, 1, 255})
        untouched = v20.register_runtime_cell(
            source, manifest, group="walk", direction="nw", phase=3
        )
        self.assertTrue(np.array_equal(np.asarray(untouched), np.asarray(source)))

    def test_seated_scale_normalization_is_uniform_and_manifest_declared(self) -> None:
        manifest = manifest_scaffold()
        self.assertEqual(
            manifest["processing"]["seated_idle_scale_authority"],
            "phase_00_opaque_height_minus_one",
        )
        self.assertEqual(
            manifest["processing"]["stand_up_scale_authority"],
            "linear_endpoint_opaque_height",
        )
        pixels = np.zeros((20, 30, 4), dtype=np.uint8)
        pixels[3:13, 7:22] = (101, 59, 38, 255)
        source = Image.fromarray(pixels, "RGBA")
        result = v20.normalise_keyed_opaque_height(source, 20)
        self.assertEqual(result.height, 20)
        self.assertEqual(result.width, 30)
        self.assertEqual(set(np.unique(np.asarray(result)[..., 3])), {255})

    def test_processed_scale_is_authoritative_not_raw_head_boxes(self) -> None:
        source = Path(v20.__file__).read_text(encoding="utf-8")
        self.assertNotIn("core._source_sequence_scale_errors(", source)
        self.assertIn("validate_staging(staging, manifest)", source)
        self.assertIn("linear_endpoint_opaque_height", source)

    def test_approved_coherent_pose_authorities_are_byte_locked_and_use_both_leads(self) -> None:
        manifest = manifest_scaffold()
        replacements = manifest["pose_authorities"]["replacements"]
        self.assertEqual(set(replacements), v20.COHERENT_AUTHORITY_PATHS)
        for direction in v20.COHERENT_AUTHORITY_DIRECTIONS:
            leads = ""
            for phase in range(8):
                relative = f"PoseAuthorities/walk_{direction}_{phase:02d}_pose_v17.png"
                replacement = replacements[relative]
                authority = v20.V20_ROOT / relative
                raw_source = v20.V20_ROOT / replacement["raw_source"]
                self.assertEqual(replacement["generator"], "codex-imagegen")
                self.assertEqual(v20.sha256(raw_source), replacement["raw_sha256"])
                self.assertEqual(v20.sha256(authority), replacement["authority_sha256"])
                with Image.open(authority) as image:
                    self.assertEqual(image.size, (1024, 1024))
                    self.assertEqual(image.mode, "RGB")
                leads += v20.core.foot_lead(v20.core.process_figure(v20.core.load_source(authority)))
            self.assertIn("L", leads, direction)
            self.assertIn("R", leads, direction)
            self.assertNotIn("LLLL", leads, direction)
            self.assertNotIn("RRRR", leads, direction)

    def test_manifest_rejects_unrecorded_pose_authority_replacement(self) -> None:
        manifest = manifest_scaffold()
        manifest["pose_authorities"]["replacements"].pop(
            "PoseAuthorities/walk_wsw_00_pose_v17.png"
        )
        with self.assertRaisesRegex(v20.V20ValidationError, "35 approved"):
            v20.validate_manifest_contract(manifest)

    def test_gate2_sources_and_key_aliases_hash_match_without_approval(self) -> None:
        manifest = manifest_scaffold()
        expected_directions: set[str] = set()
        for key_relative, frame_relative in manifest["key_aliases"].items():
            key = v20.V20_ROOT / key_relative
            frame = v20.V20_ROOT / frame_relative
            declared = manifest["master_inventory"][frame_relative]["sha256"]
            self.assertTrue(v20._valid_digest(declared), frame_relative)
            self.assertTrue(key.is_file(), key_relative)
            self.assertTrue(frame.is_file(), frame_relative)
            self.assertEqual(v20.sha256(key), declared)
            self.assertEqual(v20.sha256(frame), declared)
            expected_directions.add(Path(key_relative).stem.removeprefix("voss_key_").removesuffix("_chroma_v20"))
        processed = qa20.load_gate2_processed_keys(manifest)
        self.assertEqual(set(processed), expected_directions)
        self.assertEqual(expected_directions, set(v20.WESTERN_DIRECTIONS))

    def test_manifest_rejects_v19_and_a_mutable_portrait(self) -> None:
        manifest = manifest_scaffold()
        manifest["asset_version"] = "v19"
        manifest["ui_outputs"]["portrait"]["install"] = True
        with self.assertRaises(v20.V20ValidationError) as caught:
            v20.validate_manifest_contract(manifest)
        self.assertIn("asset_version=v20", str(caught.exception))
        self.assertIn("immutable", str(caught.exception))

    def test_shipping_portrait_is_byte_locked(self) -> None:
        manifest = manifest_scaffold()
        hashes = v20.validate_portrait_authority(manifest)
        self.assertEqual(hashes, {"runtime": v20.PORTRAIT_SHA256, "reference": v20.PORTRAIT_SHA256})

    def test_v14_registration_is_200px_hard_alpha(self) -> None:
        source = synthetic_master()
        self.assertEqual(v20._significant_subject_components(v20.key_chroma(source)), 1)
        cell = v20.process_figure(source)
        metrics = v20.frame_metrics(cell)
        self.assertIn(metrics.height, range(198, 203))
        self.assertEqual(metrics.foot_y, 433)
        self.assertLessEqual(abs(metrics.center_x - 255.5), 2.0)
        self.assertSetEqual(set(np.unique(np.asarray(cell)[..., 3]).tolist()), {0, 1, 255})

    def test_local_derivations_are_pixel_exact(self) -> None:
        stand = [Image.new("RGBA", (4, 4), (phase, 0, 0, 255)) for phase in range(12)]
        sit = v20.derive_sit_down(stand)
        for phase, cell in enumerate(sit):
            self.assertTrue(np.array_equal(np.asarray(cell), np.asarray(stand[11 - phase])))
        actor = v20.process_figure(synthetic_master())
        upper, lower = v20.split_upper_lower(actor)
        self.assertTrue(
            np.array_equal(v20.visible_mask(upper) | v20.visible_mask(lower), v20.visible_mask(actor))
        )

    def test_rear_reference_route_rejects_portrait_and_front_authority(self) -> None:
        manifest = manifest_scaffold()
        output = "Frames/voss_idle_nw_01_chroma_v20.png"
        spec = next(spec for spec in v20.master_specs(manifest) if f"Frames/{spec.filename}" == output)
        declared = manifest["master_inventory"][output]["references"]
        self.assertEqual(v20._reference_route_errors(spec, declared, declared=declared), [])
        tampered = [*declared, v20.PORTRAIT_REFERENCE, v20.ANCHOR_PATHS["front"]]
        errors = v20._reference_route_errors(spec, tampered, declared=declared)
        self.assertTrue(any("illegally uses" in error for error in errors))
        self.assertTrue(any("rear view" in error for error in errors))

    def test_later_idle_route_requires_direction_phase_zero_key(self) -> None:
        manifest = manifest_scaffold()
        output = "Frames/voss_idle_sw_03_chroma_v20.png"
        spec = next(spec for spec in v20.master_specs(manifest) if f"Frames/{spec.filename}" == output)
        route = [
            v20._expected_pose_path(spec),
            v20.PORTRAIT_REFERENCE,
            v20.ANCHOR_PATHS["dimetric_sw"],
        ]
        errors = v20._reference_route_errors(spec, route)
        self.assertTrue(any("Keys/voss_key_sw_chroma_v20.png" in error for error in errors))

    def test_current_v19_stage_is_explicitly_rejected(self) -> None:
        v19_stage = (
            v20.ROOT
            / "ArtSource/Generated/Characters/Detective/PreRendered3DV19/Staging"
        )
        self.assertTrue(v19_stage.is_dir())
        with self.assertRaisesRegex(v20.V20ValidationError, "not a V20 stage"):
            v20.validate_staging(v19_stage, manifest_scaffold())

    def test_six_payload_enumeration_never_contains_portrait(self) -> None:
        replacements = v20._payload_replacements(Path("/tmp/v20-stage"))
        self.assertEqual(len(replacements), 6)
        destinations = {destination.as_posix() for _, destination in replacements}
        self.assertTrue(any(value.endswith(v20.PAPERDOLL_RELATIVE.as_posix()) for value in destinations))
        self.assertFalse(any(value.endswith(v20.PORTRAIT_RELATIVE.as_posix()) for value in destinations))

    def test_transaction_rolls_back_deliberate_mid_swap_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old_a, old_b = root / "runtime-atlas", root / "runtime-paper.png"
            new_a, new_b = root / "stage-atlas", root / "stage-paper.png"
            old_a.mkdir()
            new_a.mkdir()
            (old_a / "cell.png").write_bytes(b"old-atlas")
            (new_a / "cell.png").write_bytes(b"new-atlas")
            old_b.write_bytes(b"old-paper")
            new_b.write_bytes(b"new-paper")
            with self.assertRaisesRegex(RuntimeError, "deliberate V20"):
                v20._swap_payload_transaction(((new_a, old_a), (new_b, old_b)), fail_after=1)
            self.assertEqual((old_a / "cell.png").read_bytes(), b"old-atlas")
            self.assertEqual(old_b.read_bytes(), b"old-paper")

    def test_transaction_rolls_back_a_failed_post_install_check(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old, new = root / "runtime.png", root / "stage.png"
            old.write_bytes(b"old")
            new.write_bytes(b"new")

            def fail_check() -> None:
                self.assertEqual(old.read_bytes(), b"new")
                raise RuntimeError("post-install gate failed")

            with self.assertRaisesRegex(RuntimeError, "post-install"):
                v20._swap_payload_transaction(((new, old),), post_swap_check=fail_check)
            self.assertEqual(old.read_bytes(), b"old")

    def test_default_post_install_gate_runs_full_suite_and_canonical_builds(self) -> None:
        completed = v20.subprocess.CompletedProcess(args=[], returncode=0, stdout="ok")
        with mock.patch.object(v20.subprocess, "run", return_value=completed) as run:
            with mock.patch.dict(
                v20.os.environ,
                {"RAINSHADOW_VOSS_ATLAS_ROOT": "/tmp/forbidden-staging-override"},
            ):
                v20.run_post_install_verification()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[0][:3], ["swift", "test", "--scratch-path"])
        self.assertIn("RainShadow iOS", commands[1])
        self.assertIn("RainShadow macOS", commands[2])
        self.assertTrue(
            all("RAINSHADOW_VOSS_ATLAS_ROOT" not in call.kwargs["env"] for call in run.call_args_list)
        )

    def test_backup_manifest_requires_five_atlases_paperdoll_and_portrait_lock(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            snapshot = Path(temporary)
            hashes: dict[str, str] = {}
            for atlas, names in v20.expected_runtime_names().items():
                for name in names:
                    path = snapshot / "Atlases" / atlas / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(f"{atlas}/{name}".encode())
                    hashes[f"Atlases/{atlas}/{name}"] = v20.sha256(path)
            paper = snapshot / "UI" / v20.PAPERDOLL_RELATIVE
            paper.parent.mkdir(parents=True, exist_ok=True)
            paper.write_bytes(b"paper")
            hashes[f"UI/{v20.PAPERDOLL_RELATIVE.as_posix()}"] = v20.sha256(paper)
            (snapshot / "backup_manifest.json").write_text(
                json.dumps(
                    {
                        "backup_format": "v20-six-payload",
                        "portrait_sha256": v20.PORTRAIT_SHA256,
                        "files": hashes,
                    }
                ),
                encoding="utf-8",
            )
            _, validated = v20._read_backup_manifest(snapshot)
            self.assertEqual(validated, hashes)

    def test_v19_repair_passes_are_never_called(self) -> None:
        tree = ast.parse(Path(v20.__file__).read_text(encoding="utf-8"))
        called: set[str] = set()
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            if isinstance(node.func, ast.Name):
                called.add(node.func.id)
            elif isinstance(node.func, ast.Attribute):
                called.add(node.func.attr)
        self.assertTrue("build_stage_contents" in called)
        self.assertTrue(
            {
                "_stabilise_walk_upper_bodies",
                "_enforce_foot_lead",
                "_reinforce_front_wardrobe",
                "_recenter_stage_cells",
            }.isdisjoint(called)
        )


if __name__ == "__main__":
    unittest.main()
