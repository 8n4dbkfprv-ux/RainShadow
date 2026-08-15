# City ground underlay — texture density V4

- Generated: 2026-08-15
- Mode: built-in Image Generator only
- Intent: Regenerate the six Act I district **ground underlays** at a resolution
  that survives play zoom. The V3 camera lock is unchanged and is not in
  question — it passed (0.79°–3.90°). Only the pixel density changes.
- Supersedes: the "District ground underlay" row of
  `city_perspective_lock_v03.md` (2048×1152 / one plate pixel per world unit)

## Why

`qa_plate_density.py` measures art pixels per world unit. A plate is drawn to a
fixed world size, so this is locked at install and no camera setting can
recover it:

| | px/unit | vs the actor | magnified at play zoom |
|---|---|---|---|
| Voss (512 px canvas over 180 units) | 2.84 | — | 1.28× |
| office suite plate | 2.53 | 0.89× | 1.43× |
| every `city_*_ground_v02` | **1.00** | **0.35×** | **3.63×** |

The ground is the only asset in the scene being magnified. The geometry is
already correct — setts measure 0.12–0.19 m (real granite), streets 7–10 m, and
one screen shows the same ground depth as BG1 — and the detail contrast matches
the office floorboards (53% vs 42% of local mean). Nothing is painted too
coarsely. It is a fine texture blown up 3.6×, and the fix is more pixels.

The shipped 2048×1152 is itself an upscale of a 1536×1024 candidate, so true
source density is **0.75 px/unit** and real detail is magnified **4.2×**.

## The ask, in one line

**Output each district ground at 4096×2304 or larger.** Everything else in
`city_perspective_lock_v03.md` stays exactly as it is.

## Acceptance

```bash
python3 ArtSource/Processing/qa_plate_projection.py <ground.png>   # camera, must stay PASS
python3 ArtSource/Processing/qa_plate_density.py                   # >= 2.00 px/unit
```

`process_city_districts_v02.PLATE_SIZE` must be raised to `(4096, 2304)` in the
same change, or every installer will downscale the new master straight back to
1.00 px/unit. The runtime needs no change: `CityDistrictScene` draws the texture
at `worldArtSize`, so world size, navigation and camera are untouched.

## Scale, expressed in output pixels

At 4096×2304 covering the same 2048×1152 world units:

| Feature | Real size | Pixels in the output |
|---|---|---|
| granite road sett | 0.12–0.19 m | **13–20 px** across |
| pavement flagstone | 0.45–0.60 m | 48–64 px |
| kerb height (upright) | ~0.15 m | 12 px |
| street width, kerb to kerb | 7–10 m | 750–1075 px |
| a standing adult, for reference | 1.75 m | 141 px tall |

One metre along the ground is **107 px**; one metre upright is **80 px**. Those
differ because the ground is foreshortened by 0.75 and uprights by 0.661 — that
is the projection, not an error.

## Prompt block

Paste the shared constraints from `city_perspective_lock_v03.md` unchanged,
then add:

```text
Output resolution: 4096x2304 minimum. This is a ground underlay only — wet cobbled carriageway, kerbs, pavement, drain covers, tram or cart ruts, puddles, gutter debris. No buildings, no facades, no props, no people, no vehicles; those ship as separate sprites.
Stonework density: individual granite setts about 15 pixels across in the output, laid in the usual fan or coursed pattern; pavement flagstones about 50 pixels. Setts must read as fine street texture at a glance, not as slabs you could trip on. Keep the joints soft and worn — this is a wet night surface photographed from far above, not a close-up masonry study.
Fill the frame edge to edge with ground: no black margin, no vignette, no horizon, no sky. The camera lock, materials, lighting and palette are unchanged from the V3 district lock.
```

## If the generator cannot output 4096 wide

Then this cannot be fixed by prompting, and the options are, best first:

1. **Generate a separate seamless paving texture** at maximum resolution and
   composite it onto the carriageway and pavement of the existing 1536 master as
   a fine detail layer. The macro layout — junction shape, kerb runs, lighting —
   is already right at 1536; only the high-frequency stonework is short. This
   keeps the passing camera grade untouched.
2. **Generate in overlapping quadrants** at maximum resolution and composite.
   The ground is a flat continuous surface, so it seams far more forgivingly
   than a facade, but kerb runs must be made to line up across the joins.
3. **Super-resolution upscale** of the 1536 master. Last resort: it invents
   plausible detail rather than recovering real detail, and it will not move
   `qa_plate_density.py` honestly — the tool measures pixels, and pixels are
   what an upscale adds.

## Installed (2026-08-15)

The generator capped at 1536×1024, so this shipped as option 1 — not a new
4096 master and not an upscale. `composite_city_ground_density_v04.py` keeps
the V3 macro via `fit_to_aspect` and paints running-bond stonework on the
BG:EE axes (sett 16 px, flag 56 px, soft joints). Water / specular puddles
from the master are left alone. `PLATE_SIZE` is (4096, 2304).

| District | Axes | Worst | vs naked Lanczos |
|---|---|---|---|
| riverside | +35.96 / −37.11 | 0.91° | overlay kept |
| wharf_ladder | +35.08 / −36.21 | 1.79° | overlay kept |
| lila_street | +39.08 / −37.20 | 2.21° | overlay kept |
| sable_row | +39.19 / −36.83 | 2.32° | overlay kept |
| harborpoint_pd | +34.07 / −33.73 | 3.14° | overlay kept |
| civic_records | +32.98 / −32.95 | 3.92° | overlay kept |

`qa_plate_density.py`: office 2/2 PASS, city 6/6 PASS at 2.00 px/unit.
`qa_plate_projection.py`: 6/6 PASS. Civic is 0.08° inside the 4.0° band.

Install: `python3 ArtSource/Processing/install_city_grounds_density_v04.py`
The installer refuses a plate whose mean-abs RGB vs a naked Lanczos of the
same master is under 1.0.
