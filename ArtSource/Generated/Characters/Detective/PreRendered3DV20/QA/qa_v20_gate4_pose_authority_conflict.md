# V20 Gate 4 pose-authority conflict

Status: resolved by explicit user decision; Gate 4 production may resume.

The hash-locked V17 walk pose authorities were processed read-only through the
same V14 figure pipeline used by V20, then classified with the strict V20
`foot_lead` gate. Several direction sets do not contain both planted-foot leads:

| Direction | V17 authority lead sequence |
|---|---|
| S | `=RRRRRRR` |
| SSW | `RRRRRRRR` |
| SW | `LRRLRLRL` |
| WSW | `RRRRRRRR` |
| W | `LLL=LLL=` |
| WNW | `LLLLLLLL` |
| NW | `RRRRR=RR` |
| NNW | `RRRRLRRR` |
| N | `=R==LLRL` |

This conflicts with two simultaneous V20 requirements:

1. each generated frame must preserve its exact V17 pose, including both foot
   positions; and
2. every processed eight-frame direction must contain both `L` and `R` planted
   leads.

The first WSW ImageGen pass reproduced the authority pattern as `RRRRRRRR`.
Prompting an opposite lead either remained `R`/`=` or visibly changed the
mandated pose, so those attempts are rejected. No pixel repair, foot rewriting,
waiver, alternate generator, or runtime installation was used.

The user selected replacement of the affected authorities. The 32 WSW/W/WNW/NW
files are separate built-in ImageGen outputs authored from the approved SW or N
V20 gait proof, the fixed direction key, and the permitted matching V20 anchors.
After the completed NNW loop still classified as `RRRR=RRR`, NNW phase 03 was
also replaced by a separate built-in ImageGen output with a strict left planted
lead; phase 05 was subsequently re-registered to the same stable loop band,
phase 04 was subsequently re-authored to close the final half-pixel registration
outlier, bringing the replacement set to 35. Rear calls omit portrait/front
references and forbid face, shirt, tie, lapels, and front-coat construction.
Each authority is normalized onto a 1024×1024 flat-green canvas without altering
its accepted pose.

The manifest and `pose_authority_provenance_v20.json` bind every call ID,
prompt, ordered reference hash, raw output hash, normalized authority hash,
superseded V17 hash, and rejected interim stage-derived hash. Original V17
authorities remain archived under `PoseAuthorities/ReplacedIncoherentV17/`;
the interim stage-derived replacements remain under
`PoseAuthorities/RejectedStageDerived/`. S, SSW, SW, and N remain unchanged;
NNW phases 03, 04, and 05 are the only additional replacements required by the
final Gate 4 loop audit.
