# Area short codes — September 28, 2026

Every registered area now has a permanent six-character resref. `AreaResourceID`
(in `Core/Persistence/SaveStore.swift`) owns the mapping; never recycle a code or
assign codes from catalog order. `AreaID` normalizes registered aliases and case
on construction and decoding, and encodes the canonical code. Unknown IDs remain
intact for test fixtures and future custom content; `GLOBAL` stays a script scope.

| Exterior | Code | Interior | Code |
|---|---|---|---|
| Opening exterior | RS0000 | — | — |
| Sable Row | RS0100 | Voss’s office | RS0101 |
| Wharf Ladder | RS0200 | Shipping office | RS0201 |
| Riverside | RS0300 | Riverside Rooms | RS0301 |
| Lamp Ward | RS0400 | Lamphouse | RS0401 |
| Lila’s Street | RS0500 | Lila Street Rooms | RS0501 |
| Civic Records | RS0600 | Records Annex | RS0601 |
| Legacy Harborpoint PD | RS0700 | Legacy police station | RS0701 |
| Sable Court playtest | RS9900 | — | — |
| Sable Noir source | RS9901 | — | — |

Legacy PD records keep their own identities; the current world-map PD destination
continues to route to Lamp Ward. Display names and entrance names are independent
of area codes. No artwork, navigation geometry, or character bundles change.

Authored JSON IDs and travel destinations use codes. The loader binds codes to
the existing descriptive `.area.json` basenames. Inferred light/height maps and
adapter-generated search-map names also use that resource binding, so changing an
ID cannot silently drop a lighting map. Historical generators may still emit old
aliases: loading their output canonicalizes it through the same registry.

On save load, all area-keyed exploration, ground piles, door overrides, unlocked
doors, spent triggers, and the area prefix of scoped variables migrate. The
original envelope is backed up once as `<save key>.BeforeAreaCodesV1`. Existing
layout migrations still run first and accept either spelling. Repeated loads are
idempotent. If a save contains both spellings, ground stacks concatenate, sets
union, equal-size fog masks OR, and canonical keys win conflicting variables,
door values, or incompatible fog grids. Unrelated progress and unknown IDs survive.

Regression coverage: `AreaCodeTests` loads all 17 codes and their travel targets,
checks aliases/resource binding, and exercises collision handling, backup, and
repeat-load persistence. Existing city/office restoration tests retain legacy
input while checking canonical saved output.

Validation: 76 focused tests across nine suites pass; macOS Debug and iOS
simulator Debug builds pass; all 35 live city travel/lifecycle checks pass with
short-code destinations. A broader area sweep was stopped after exposing stale
restoration-era expectations (old props, walls, lighting and plate names) and
missing opening-exterior page manifests. Those unrelated content issues remain;
the focused run includes current restoration, routing, persistence and ID tests.
