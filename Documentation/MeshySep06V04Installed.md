# Approved Meshy V04 character

The user approved the new candidate ("That's better. Let's use the new
candidate."). V04 is installed in all five Voss runtime atlases and the native
indexed bundle. `voss_masters.ACTIVE_VERSION` and `ie_avatar.VOSS` select its
masters and palette together.

The body is 58 native rows. The compatibility canvas remains 512×512 with a
200-pixel registered body, but bundle display size is 163.125 rather than 180:
`180 * 58 / 64`. This changes physical presentation as well as source sampling;
reducing source rows alone would have enlarged the body back to its old size.
Navigation, clearance and camera constants are unchanged.

Materials retain the approved bounded coat-texture luminance and directional
lighting. The cast shadow comes from evaluated pose geometry projected along
the key direction. It uses material-mask label 8 and palette index 1. The saved
Blender source has a Geometry Nodes projection driven by the evaluated rig, so
its shadow follows animation during live review. No Super xBR is used in this
candidate's atlases, derived layers or presentation previews.

The indexed loader applies the existing `translucentShadowColor` operation to
embedded-shadow palettes, including recolored variants. The detective hides
the fallback contact oval for such bundles independently of seat actions that
animate its alpha. No blitter arithmetic was changed.

## Files and verification

All source, stage, preview and backup files are under
`ArtSource/Generated/Characters/Detective/MeshySep06V04/`:

- `meshy_v04.blend`: approved material/light source with animated shadow projection.
- `Renders/`, `Frames/`, `Materials/`: 168 rendered poses and 204 master pairs
  after reverse transitions are derived.
- `Staging/`: 248 runtime cells and indexed bundle.
- `install_receipt.json`: installed hashes and explicit review limitations.
- `RuntimeBackupBeforeV04/`: previous five atlases and indexed bundle.
- `game_standing.png`: isolated macOS camera capture of the candidate at 100%.

Build succeeded. The three targeted installed-asset tests passed: inventory and
palette metadata, declared shadow ownership, and native body/shadow pixels under
recoloring. The latter checks all standing/walking frames are 58 body rows and
that index 1 resolves to alpha 128 while body pixels remain opaque.

**The legacy full asset suite is not passing.** Its earlier V04 run reported
603 issues, including old size/palette/no-shadow assumptions, measurements that
include the new cast shadow in the body, missing V04 projection metadata, and
the previously documented gait/rear-color problems. The explicit inventory and
shadow expectations were updated for the approved asset; geometric thresholds
were not relaxed. Remaining body-only measurement migration and pose defects
are unfinished work, not a claim that V04 passed all historical asset gates.

Rebuild this stage with
`python3 ArtSource/Processing/stage_meshy_sep06_v04.py`. Do not use the V14 or
V22 installers to regenerate this candidate; they intentionally reproduce their
historical versions. Reinstallation must preserve the five atlases and indexed
bundle together and retain a rollback backup.
