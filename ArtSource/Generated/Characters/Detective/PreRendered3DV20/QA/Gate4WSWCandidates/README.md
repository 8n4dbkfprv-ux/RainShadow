# Gate 4 WSW isolated candidates

These are unapproved built-in ImageGen outputs retained for manual and metric comparison.
They are not accepted masters, are not referenced by the V20 manifest, and must not be
staged or installed until a complete eight-frame WSW loop passes both strict validation
and manual strip/quarter-speed review.

| Candidate | Built-in call | Current role | Processed metrics |
|---|---|---|---|
| `wsw_left_contact_broad_candidate.png` | `exec-5fe0ec73-8ae8-48c3-96a4-a8c0332852c9` | strongest genuine left-leading contact | head 25, x 251, torso 83, lead L |
| `wsw_left_pass_candidate.png` | `exec-38de189d-cc14-4832-870f-9a8c5a2beccf` | strongest genuine left-leading passing pose | head 25, x 250, torso 71, lead L |
| `wsw_right_contact_candidate.png` | `exec-aded3da1-dacf-4546-ab68-994c7e57ee17` | stable right-leading family key | head 25, x 252, torso 75, lead R |
| `wsw_right_contact_matched_candidate.png` | `exec-a3da46d1-5b78-4496-8e67-13b1bb93e072` | genuine right-leading endpoint matched to the broad left family | head 25, x 251, torso 93, lead R |
| `wsw_right_pose_registration_outlier.png` | `exec-184aea6b-e76f-4cc9-aa8d-2eda0919fcc6` | genuine right-leading pose; reject until head registration is fixed | head 25, x 264, torso 75, lead R |
| `wsw_left_recoil_matched_candidate.png` | `exec-4e130db6-bdbb-4752-820b-9bc9280d4b62` | genuine left-leading recoil used in strict-pass WSW v2 checkpoint | head 25, x 250, torso 75, lead L |
| `wsw_left_pass_broad_matched_candidate.png` | `exec-821377df-8940-4d28-9ea5-76cec031ac70` | genuine left passing pose, matched head registration | head 25, x 252, torso 78, lead L |
| `wsw_left_up_alternate_candidate.png` | `exec-d8bd925c-13fa-4be9-8252-9e1537ce922e` | alternate genuine left-up beat used in strict-pass WSW v2 checkpoint | head 25, x 252, torso 86, lead L |
| `wsw_right_contact_profile_matched_candidate.png` | `exec-6648afc1-53c6-4e7b-b2fa-7b70edec63ea` | true WSW profile right contact replacing the frontal candidate | head 25, x 252, torso 86, lead R |
| `wsw_right_pass_matched_candidate.png` | `exec-7a84da71-3673-456c-8984-beeadfac2f4d` | compact right-half crossover; technically neutral foot lead | head 25, x 251, torso 75, lead = |
| `wsw_right_up_profile_matched_candidate.png` | `exec-9bbff4d9-667d-434e-99f5-653d71f432ad` | genuine strict-profile raised-knee beat | head 25, x 250, torso 75, lead = |
| `wsw_right_up_matched_candidate.png` | `exec-0c0c802f-c777-4e31-8c9b-9b0454d45907` | restrained right-half up beat | head 25, x 250, torso 75, lead L |

The earlier automated-passing R/L alternating set was manually rejected because its
processed strip collapsed into two repeated poses. Numerical uniqueness alone is not
sufficient for Gate 4 approval.

`qa_wsw_three_genuine_candidates_processed.png` is the current manual checkpoint. It
shows three visually compatible, genuinely distinct processed poses: left contact,
left passing, and right contact. The remaining left-up/right-pass/right-up timings are
still pending. Two consecutive built-in attempts at the left-up pose were rejected by
the image generator's output safety filter; no fallback was used.

## Current strict-pass checkpoint (not approved)

`qa_wsw_eight_candidate_loop_v2_processed.png` and
`qa_wsw_eight_candidate_loop_v2_quarter_speed.gif` contain the current complete
eight-frame candidate. It passes the automated gait measurements in processed form:

- eight unique frames;
- head jitter 2 px and head pulse 1.00x;
- torso pulse 1.147x;
- planted sequence `LLLLR==L`, containing both required leads with no four-cell
  repeated-lead failure;
- adjacent/closure IoU values `0.863, 0.693, 0.650, 0.699, 0.529, 0.585, 0.512,
  0.616`; closure floor `0.488`.

This checkpoint is deliberately **not** a Gate 4 approval candidate yet. Manual review
found that frames 05-07 become visibly narrower and more upright after the new profile
right-contact frame 04. Several built-in attempts to rebuild those frames with the
frame-04 upper body either moved the head outside the 2 px jitter gate or ignored the
requested head translation. Those attempts remain rejected; no local body repair,
runtime write, accepted-frame replacement, CLI, or non-Codex image generator was used.
