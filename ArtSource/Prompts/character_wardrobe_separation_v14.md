# Character wardrobe separation V14 (Voss material hue lock)

Generated 2026-08-07. Scope: **Harlan Voss** locomotion + seat masters only. Lila
is marginal on the same metric but far less severe, and is deferred. Craft, camera, pose, and naming contracts are
unchanged from [`character_prerendered_3d_v11.md`](character_prerendered_3d_v11.md) and
[`character_locomotion_match_seated_v13.md`](character_locomotion_match_seated_v13.md);
this lock changes **colour only**.

## Review finding

Voss reads in-game as a single tan mass — a gingerbread man — where a BG:EE avatar
reads as a person wearing separate things. Measured across every band of the
shipped sprite, red:green:blue sits at **1 : 0.68 : 0.39 everywhere**: head, torso,
legs and feet are the *same hue* at different brightnesses.

This is not the crunch and not the wardrobe lock. It is in the source art:

| source | G/R across all bands |
|---|---|
| paperdoll v11 | 0.66 – 0.76 |
| seated NE00 (pipeline colour authority) | 0.65 – 0.74 |
| `voss_idle_s_seatedmatch_v5_gen` master | 0.58 – 0.65 |
| shipped sprite (V14 crunch) | 0.67 – 0.70 |
| shipped sprite (V7 crunch, for comparison) | 0.65 – 0.73 |

The V11 lock already *names* the wardrobe — "mustard waistcoat, cream shirt,
loosened dark green tie, charcoal trousers, scuffed brown shoes". The generator
produced brown-on-brown anyway, because a list of garment nouns sitting under a
style nucleus that stresses "muted", "matte" and "broad planar masses" reads as
permission to unify the palette. So this lock states colour as a **contract with
numbers and a value ladder**, not as adjectives.

### The measurable target

Cluster a figure's colours and compare the cluster centroids. Two numbers matter:

| | value spread | **hue spread** |
|---|---|---|
| BG:EE `mage_circle_robes` | 90 | 1.966 |
| BG:EE `red_tunic_fighter` | 129 | 0.948 |
| BG:EE `townsfolk_yellow_red` | 37 | 0.485 |
| BG:EE `dark_vest_fighter` | 148 | 0.189 |
| BG:EE `green_robe` *(one-robe monk — the floor)* | 34 | 0.178 |
| **Voss standing, shipped** | 66 – 113 ✔ | **0.040 – 0.052** ✘ |
| Voss seated NE, shipped | 128 ✔ | 0.428 ✔ |
| Lila, shipped | 128 ✔ | 0.165 ✘ |

Voss's *value* range is already correct. He is roughly **4× below even the weakest
BG reference** on hue, and that single number is the whole defect.
`qa_wardrobe_separation_check.py` measures it: **floor 0.18, target 0.45** — the
level of a character who is actually wearing several different things.

Lila lands at 0.165, marginally under the floor too. Her dress and skin do
separate, but less than a BG avatar; she is lower priority than Voss and out of
scope for this lock.

---

## Paste this into the generator

Everything between the rules is the request. It assumes the V11 style nucleus is
already in force; if the generator has no memory of it, prepend the "Shared
generation contract" paragraph from `character_prerendered_3d_v11.md` first.

---

> Harlan Voss wears six separate garments and they must read as six separate
> materials, not one brown mass at six brightnesses. Give each its own hue
> family. Two garments differing only in lightness is a failure.
>
> Wardrobe, lightest to darkest — this is also the value ladder, keep it in this
> order:
>
> - **cream shirt** — old-paper off-white, `#CEC3AA`. The lightest thing on the
>   figure apart from skin highlights. Visible as a V at the open collar and a
>   sliver down the chest.
> - **skin** — warm mid tan, `#AC7E60`. Face, neck, hands.
> - **mustard waistcoat** — dull ochre gold, `#9C7730`. Clearly yellow against the
>   coat, not a lighter brown. Visible between the open coat fronts.
> - **olive-brown overcoat** — desaturated olive-khaki, `#705E3C`. Green-leaning
>   brown, belted, mid-calf, rumpled and rain-stained. The largest mass, so it
>   sets the mid value; everything else reads against it.
> - **charcoal trousers** — neutral cool grey, `#3A383E`. Grey, with no warmth in
>   it at all — this is the strongest hue contrast on the figure and it must not
>   drift brown.
> - **dark green tie** — muted forest, `#364636`. Loosened, sitting on the cream
>   shirt.
> - **scuffed brown shoes** — dark leather, `#4E3725`.
> - **hair** — dark cool brown, `#3A2D25`. Solid shell, no strands.
>
> The overcoat hangs **open** so shirt, tie and waistcoat are visible on the chest
> in every facing that shows the front. On rear facings only the coat, trousers,
> shoes and hair are visible — do not paint a shirt on his back.
>
> Keep the baked upper-left key light and the soft planar shading exactly as
> before. Apply the light **per material**: a shadowed fold of the cream shirt is
> still cream, and a lit fold of the charcoal trousers is still grey. Do not glaze
> a single warm brown or a single amber lamp wash over the whole figure — the
> scene applies its own grade at runtime, so the master must stay neutrally lit
> and materially separate.
>
> At gameplay size each garment is only a handful of pixels, so the separation has
> to be bold at source: judge it by squinting until the figure is a few pixels
> tall, and if it collapses into one colour, push the hues further apart.

---

## Status: SE key approved

`voss_key_se_chroma_v13d_review.png` measures **hue spread 0.481** — above the 0.45
target, between BG's `townsfolk` (0.485) and `red_tunic` (0.948). It is the wardrobe
authority. Two findings from reviewing it:

- The **previous** key (`v13c`) measures **0.155 — below the floor**. It looks
  wardrobed to the eye because the tie and waistcoat are visible, but those are
  small; the materials that cover the figure were still one hue. Trust the metric
  over the thumbnail here.
- v13d carries **~28% more micro-contrast** than v13c (3.82 → 4.88 mean gradient):
  visible hatching on the coat and waistcoat, crisper than the "1998 textured mesh
  rendered offline" contract. It survives the crunch, so it does not block, but the
  batch should not drift further.

## The real batch risk: inconsistency

The masters that actually feed the shipped sheets vary wildly:

| master | hue spread |
|---|---|
| `voss_idle_s_seatedmatch_v5_gen` | 0.402 |
| `voss_idle_nw_seatedmatch_v5_gen` | 0.158 |
| `voss_walk_sw_r_seatedmatch_v6_gen` | 0.141 |

So this was never only a "the generator ignored the wardrobe" problem — some
directions had separation and others did not, and the locks then flattened all of
them to match. **Gate every sheet, not just the key.**

## Order of work

1. ~~Regenerate the SE key~~ — done, `v13d` approved.
2. Run `python3 ArtSource/Processing/qa_wardrobe_separation_check.py <path>`.
   It prints the cluster ladder and passes/fails hue spread against 0.18
   (target 0.45).
3. Eyeball it at play scale against `ArtSource/References/BGEE/bgee_avatar_red_tunic_fighter.png` —
   that reference is the closest analogue: one figure, several materials, dark
   boots, light skin, a saturated garment.
4. Only then regenerate the 9×4 standing idle and 9×8 walk sheets, and the 20
   chairless seat cells, holding pose and craft to the V13 masters.

## Hard rejects

| Reject | Require |
|---|---|
| Whole figure one hue at different brightnesses | Six distinguishable hue families |
| Brown or warm-tinted trousers | Neutral cool grey `#3A383E`, no warmth |
| Waistcoat as "lighter brown" | Clearly yellow ochre against the coat |
| Global amber/lamp wash over the master | Neutral baked key light; the scene grades at runtime |
| Shirt or waistcoat visible on rear facings | Coat, trousers, shoes, hair only from behind |
| Closed/buttoned overcoat hiding the chest | Open coat, chest layers readable |
| Craft drift — smoother, glossier, more modern | V13 masters remain the craft authority |

## After the masters land — done, but disarmed

The colour locks would have flattened whatever the new art brings in. They are now
gated behind **`crunch.PRESERVE_WARDROBE`**, which is **off by default**. Flip it
when the separated masters land:

```bash
RAINSHADOW_PRESERVE_WARDROBE=1 python3 install_voss_idle_walk_seated_match_v02.py
```

or set `PRESERVE_WARDROBE = True` in `crunch.py` for good.

Armed, a frame is measured individually — a rear facing that is legitimately all
coat and trousers still gets held to the seated grade, because there is nothing to
preserve. Only frames above the hue-spread floor skip the flattening passes.

What the gate disables, and what each would have done to the wardrobe:

| pass | on a wardrobe |
|---|---|
| `_stamp_seated_coat_chroma` over the 10–86% band | every torso material becomes the coat's hue |
| global olive kill, `G ≤ R × 0.68` | olive coat and green tie turn brown |
| `yellow` clamp forcing `B = R × 0.367` | destroys the mustard waistcoat |
| `still = g > r+5 & g > b+5; a = 0` | **deletes** a `#364636` tie outright |
| `fringe = edge & g > r+6` | clips green wardrobe at the silhouette |
| navy pants stamp | overrides authored trouser colour |
| `_match_region` per-channel on geometric ROIs | a torso band contains tie and waistcoat, and drags both onto the coat |

That last one is why `_match_region` gained a `luminance_only` mode: armed, the
locks still match each region's *brightness* between clips — which is the drift
they were built to fix — without imposing its hue.

**Verification.** `qa_wardrobe_lock_preservation.py` synthesises a separated figure,
runs it through both locks armed and unarmed, and checks per-material survival and
hue drift. Currently: tie, waistcoat and trousers all survive at 100% armed, with
drift strictly lower than unarmed. With the flag off the whole pipeline is
bit-identical — 233/233 atlas cells unchanged, 352 tests passing.

### The crunch needed a change after all

The first real master proved the original claim wrong. `_coat_mask` was written for
a monochrome Voss and is broad enough to claim **87% of a wardrobed figure** — coat,
waistcoat, shirt, tie *and* trousers — so a single 12-step ramp fitted to that mass
was dominated by the coat and dragged every other garment onto its hue. Measured on
`voss_key_se_chroma_v13d`: hue spread 0.460 down to 0.201 in that one step.

`crunch._quantise_material_clusters` replaces the mask heuristics with k-means over
the figure's own colours when preservation is armed, so each material gets its own
ramp whatever the character is wearing. That is closer to the Infinity Engine model
anyway — a BAM carries one gradient per material *slot*, not one palette fitted to
the whole avatar. It also means Lila benefits without any Lila-specific masks.

### Measured chain on the first real master

| stage | hue spread |
|---|---|
| master as generated | 0.493 |
| after soften + crunch | 0.345 |
| after `seated_authority_lock` | 0.194 |
| after `identity_wardrobe_lock` + `finalise` | **0.202** |

Above the 0.18 floor, and the wardrobe is visibly intact at play scale. The loss
through the locks is their luminance matching pulling everything toward the seated
grade; that is the consistency mechanism working as intended, and it is worth
re-checking once all nine directions exist.
