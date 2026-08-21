#!/usr/bin/env python3
"""Measure native humanoid craft directly from an Infinity Engine BAM V1/BAMC.

The parser intentionally uses only the Python standard library. It follows the
IESDP BAM V1 field layout and GemRB's RLE rule. Supply a BAM resource; no
external reference BAM is stored in this repository.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import statistics
import struct
import zlib


def _unpack_bamc(data: bytes) -> bytes:
    if data[:8] != b"BAMCV1  ":
        return data
    if len(data) < 12:
        raise ValueError("truncated BAMC header")
    expected_size = struct.unpack_from("<I", data, 8)[0]
    unpacked = zlib.decompress(data[12:])
    if len(unpacked) != expected_size:
        raise ValueError(
            f"BAMC size mismatch: header says {expected_size}, decoded {len(unpacked)}"
        )
    return unpacked


def _decode_rle(data: bytes, offset: int, count: int, compressed_index: int) -> bytes:
    output = bytearray()
    cursor = offset
    while len(output) < count:
        if cursor >= len(data):
            raise ValueError("truncated BAM RLE frame")
        value = data[cursor]
        cursor += 1
        if value != compressed_index:
            output.append(value)
            continue
        if cursor >= len(data):
            raise ValueError("truncated BAM RLE run")
        run = data[cursor] + 1
        cursor += 1
        output.extend([compressed_index] * run)
    if len(output) != count:
        raise ValueError("BAM RLE run exceeds frame dimensions")
    return bytes(output)


def measure(path: Path, transparent_override: int | None = None) -> dict[str, object]:
    data = _unpack_bamc(path.read_bytes())
    if data[:8] != b"BAM V1  ":
        raise ValueError("expected BAM V1 or BAMCV1")

    frame_count, cycle_count, compressed_index = struct.unpack_from("<HBB", data, 8)
    frames_offset, palette_offset, lookup_offset = struct.unpack_from("<III", data, 12)
    if palette_offset + 1024 > len(data):
        raise ValueError("truncated BAM palette")

    palette = [struct.unpack_from("<BBBB", data, palette_offset + i * 4) for i in range(256)]
    green_indices = [i for i, (b, g, r, _a) in enumerate(palette) if (r, g, b) == (0, 255, 0)]
    transparent_index = (
        transparent_override
        if transparent_override is not None
        else (green_indices[0] if green_indices else 0)
    )

    frames: list[dict[str, object]] = []
    clip_indices: set[int] = set()
    for index in range(frame_count):
        entry = frames_offset + index * 12
        width, height, center_x, center_y, encoded_offset = struct.unpack_from(
            "<HHhhI", data, entry
        )
        data_offset = encoded_offset & 0x7FFF_FFFF
        pixel_count = width * height
        if encoded_offset & 0x8000_0000:
            pixels = data[data_offset : data_offset + pixel_count]
            if len(pixels) != pixel_count:
                raise ValueError(f"frame {index}: truncated uncompressed pixels")
        else:
            pixels = _decode_rle(data, data_offset, pixel_count, compressed_index)

        visible_positions = [pos for pos, value in enumerate(pixels) if value != transparent_index]
        used = {pixels[pos] for pos in visible_positions}
        clip_indices.update(used)
        if visible_positions:
            ys = [pos // width for pos in visible_positions]
            bbox_height = max(ys) - min(ys) + 1
            crown_to_pivot = center_y - min(ys)
        else:
            bbox_height = 0
            crown_to_pivot = 0
        frames.append(
            {
                "index": index,
                "stored_size": [width, height],
                "center": [center_x, center_y],
                "visible_bbox_height": bbox_height,
                "crown_to_pivot": crown_to_pivot,
                "used_nontransparent_indices": len(used),
            }
        )

    def summary(field: str) -> dict[str, float]:
        values = [float(frame[field]) for frame in frames]
        return {
            "minimum": min(values, default=0),
            "median": statistics.median(values) if values else 0,
            "maximum": max(values, default=0),
        }

    return {
        "path": str(path),
        "format": "BAM V1",
        "frame_count": frame_count,
        "cycle_count": cycle_count,
        "compressed_index": compressed_index,
        "transparent_index": transparent_index,
        "stored_sizes": sorted({tuple(frame["stored_size"]) for frame in frames}),
        "visible_bbox_height": summary("visible_bbox_height"),
        "crown_to_pivot": summary("crown_to_pivot"),
        "used_nontransparent_indices_per_frame": summary("used_nontransparent_indices"),
        "used_nontransparent_indices_clip": len(clip_indices),
        "frames": frames,
        "lookup_offset": lookup_offset,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bam", type=Path)
    parser.add_argument("--transparent-index", type=int, choices=range(256))
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = measure(args.bam, args.transparent_index)
    if args.json:
        print(json.dumps(result, indent=2))
        return

    print(f"{result['path']}: {result['frame_count']} frames, {result['cycle_count']} cycles")
    print(f"stored sizes: {result['stored_sizes']}")
    for label in (
        "visible_bbox_height",
        "crown_to_pivot",
        "used_nontransparent_indices_per_frame",
    ):
        values = result[label]
        print(
            f"{label}: {values['minimum']:g}...{values['maximum']:g} "
            f"(median {values['median']:g})"
        )
    print(f"used_nontransparent_indices_clip: {result['used_nontransparent_indices_clip']}")


if __name__ == "__main__":
    main()
