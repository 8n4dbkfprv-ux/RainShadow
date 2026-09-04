# Native outdoor detail masters

Sable Row and the opening exterior use retained, native-resolution Image
Generator edits rather than enlargements of their old plates. The old art is an
immutable registration and composition guide only; none of its enlarged pixels
are blended into a finished master.

`ArtSource/Processing/build_native_outdoor_detail.py` owns preparation,
validation, assembly, and crop-only installation. Its two current authorities
are:

- `ArtSource/Generated/CityDistrict/V2/IENativeDetailV16`: 64 overlapping
  1448×1086 Sable Row source windows, assembled to a 10240×7680 master over the
  existing 5120×3840 world extent.
- `ArtSource/Generated/Exterior/NativeDetailV02`: 16 overlapping opening
  exterior source windows, assembled to a 6144×3456 master over the existing
  3072×1728 cinematic extent.

Every accepted window retains the exact generated PNG, SHA-256, uniform source
crop, world-space coverage, prompt, edit target hash, and measured registration
scores. `adopt` rejects a source that would need enlargement, exceeds 15 RGB
levels of blurred layout error, or falls below 0.90 layout correlation. Do not
relax these thresholds to admit a take; regenerate the take.

Assembly requires the complete inventory. It uses complementary cosine weights
only inside overlaps and performs no sharpening, noise synthesis, upscaling, or
fallback fill. Sable Row must also pass the existing 1.5° BGEE projection lock.
The opening retains its authored cinematic camera rather than being forced onto
the playable-area projection.

Installation is deliberately crop-only and unlink-first. Sable Row becomes 25
2048×1536 JPEG 4:4:4 pages; the opening becomes four 3072×1728 pages. Their page
manifests bind the runtime files to the retained native-source provenance so
`qa_plate_density.py` measures real source pixels per world unit rather than the
dimensions of an enlarged runtime canvas.

Typical verification:

```sh
python3 -m unittest ArtSource/Processing/test_build_native_outdoor_detail.py
python3 -m unittest ArtSource/Processing/test_qa_plate_density.py
python3 ArtSource/Processing/qa_plate_projection.py --shipped
python3 ArtSource/Processing/qa_plate_composition.py
python3 ArtSource/Processing/qa_plate_density.py
```

The density command intentionally reports unrelated existing failures in other
area sources. Do not weaken the gate or substitute runtime dimensions for source
provenance to make that aggregate result green.
