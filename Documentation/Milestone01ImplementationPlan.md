# RainShadow — Milestone 01 Implementation Plan

- Status: planning-mode execution plan
- Version: 0.1
- Milestone: M01 — The Office in the Rain

## 1. Milestone outcome

M01 delivers a polished opening slice on iOS/iPadOS and macOS:

1. launch into a dark apartment-building exterior;
2. play a 10–14 second skippable rain cinematic;
3. transition smoothly toward the lit office window and into the office;
4. reveal the detective seated behind his desk as a crude era-authentic 3D game mesh pre-rendered into small 2D frames;
5. allow the detective to stand, idle, and walk with 16-facing presentation;
6. allow the player to inspect the window, desk, telephone, case files, and door;
7. preserve correct depth and occlusion around the desk, chair, cabinet, door jamb, window sill, and foreground wall;
8. maintain the agreed composition, performance, audio, and accessibility baseline on both platforms.

This document orders the work. It does not begin production code or final asset generation by itself.

## 2. Delivery principles

- Prove projection, scale, input, depth, and transition with graybox assets before generating the full art set.
- Lock the character's actual play-scale raster look before producing 140 stored animation frames.
- Treat shell, props, shadows, light overlays, effects, and occluders as separate deliverables from the start.
- Keep every step runnable on iOS and macOS; do not postpone one platform until final QA.
- Put deterministic model/geometry behavior under tests and reserve human review for visual, audio, and feel decisions.
- A failed gate stops dependent production. It does not get papered over by adding more assets.

## 3. Ordered implementation phases

### Phase 0 — approve the baseline

#### Step 1: Review and freeze M01 scope

- Review the GDD, architecture, asset manifest, and project structure together.
- Confirm that the exterior is non-interactive and the office is the first playable scene.
- Confirm the five M01 hotspots and provisional observations.
- Record changes as document revisions before code starts.

Exit gate: no unresolved disagreement about the opening flow, separated-object rule, BG:EE avatar target, or M01 definition of done.

#### Step 2: Establish platform/build policy

- Verify installed Xcode/SDK compatibility.
- Replace template-only deployment target 27.0 values with the chosen product baseline; proposed starting point is iOS/iPadOS 18.0 and macOS 15.0.
- Lock iOS to landscape for the playable milestone.
- Give the iOS and macOS products distinct valid bundle identifiers.
- Keep the tvOS target outside M01 and remove shared M01 resource membership from it.
- Add a shared unit-test target.

Exit gate: clean Debug builds and empty test runs succeed for iOS Simulator and macOS.

#### Step 3: Capture the untouched template baseline

- Run the current stock scene on both platforms.
- Record current launch behavior and warnings.
- Note the template `GameScene.swift`, `GameScene.sks`, and `Actions.sks` removal/migration path.
- Keep the repository clean and avoid unrelated project-format churn.

Exit gate: any later regression can be separated from a pre-existing template issue.

### Phase 1 — build the application spine

#### Step 4: Add `GameBootstrap` and long-lived context

- Create `GameConfiguration`, `GameContext`, `GameSession`, `SettingsStore`, and `SaveStore` foundations.
- Move scene startup out of `GameScene.newGameScene()`.
- Keep platform controllers thin.

Exit gate: both app targets launch a programmatic placeholder scene from the same bootstrap path.

#### Step 5: Implement scene lifecycle and routing

- Add `BaseGameScene`, `SceneRoute`, `TransitionSpec`, and `SceneRouter`.
- Enforce a single active route transition and explicit input locking.
- Add a minimal `RecoveryScene` for critical load failure.
- Unit-test route re-entry and lifecycle order.

Exit gate: placeholder exterior and office scenes can transition in both targets without direct `presentScene` calls elsewhere.

#### Step 6: Implement asset catalog/preload services

- Add logical asset-bundle IDs and manifests.
- Preload atlases asynchronously and build nodes only on the main actor.
- Add debug reporting for resident bundles and load duration.
- Keep large background textures outside atlases.

Exit gate: a test bundle preloads, transitions, and releases without a main-thread decode spike on the cut.

#### Step 7: Implement persistent audio service

- Add weather, ambience, music, foley, dialogue, and UI buses.
- Prove a crossfade that survives scene replacement.
- Handle app interruption, backgrounding, and settings volume.

Exit gate: a placeholder exterior loop crossfades to an interior loop without restarting or doubling.

### Phase 2 — create the art and layout validation harness

#### Step 8: Build `AssetPreviewScene`

- Display one asset at 1:1, intended play scale, and common zoom bounds.
- Toggle warm/cool/white/black backgrounds to expose alpha fringes.
- Show frame canvas, ground pivot, crown-height guide, palette swatches, and animation speed controls.
- Add a 4:3/16:9/wide safe-frame overlay.

Exit gate: environment, prop, effect, and actor assets can be judged without assembling a gameplay scene.

#### Step 9: Generate the four style-lock tests

- Use the built-in Image Generator with the supplied screenshots as reference context and the prompt contracts in the asset manifest.
- Generate office corner, desk composite, detective SE key, and play-scale mockup.
- Retain original outputs and generation metadata.
- Do not generate animation batches yet.

Exit gate: the environment reads as a richly pre-rendered isometric area and the actor reads as a crude late-1990s textured 3D game mesh baked into 2D—not as pixel art, a painted detective, polished modern low-poly concept art, or a high-detail PBR character.

#### Step 10: Freeze the style lock

- Approve projection, actor body height, 512×512 2× frame canvas, doubled ground pivot, neutral sprite light rig, broad baked shading, and environment light direction.
- Create `art_style_lock.json` and master registration overlays.
- Test the 9% standing-height target on phone and macOS: about 104 pixels in a 1152-pixel-tall rendered view, with an acceptable 92–127 pixel (8–11%) band.

Exit gate: a reviewer can compare any later asset to measurable locked values.

### Phase 3 — prove the office in graybox

#### Step 11: Implement viewport and camera coordination

- Use `.resizeFill` and `SKCameraNode`.
- Fit a 911-unit reference world height so the 82-unit standing body occupies 9% of the playable view, while respecting 4:3 and wide aspect safety.
- Recalculate on orientation/window resize without stretching.
- Add camera-bounds debug display.

Exit gate: the graybox office keeps all critical content visible on the screenshot matrix.

#### Step 12: Implement the shared scene-layer contract

- Add background, floor effect, rear fixture, depth world, occlusion, weather, cinematic, HUD, and debug roots.
- Centralize z bands.
- Set `ignoresSiblingOrder` only after all nodes receive deterministic z positions.

Exit gate: a debug scene proves each band in the intended order.

#### Step 13: Implement isometric projection and navigation data

- Add `IsoProjection`, `NavCell`, `NavigationGrid`, A*, and path simplification.
- Decode `detective_office.nav.json`.
- Unit-test inverse projection, unreachable areas, blocked corners, and routes around desk/cabinet.

Exit gate: the placeholder actor reaches every M01 approach cell without entering blocked art.

#### Step 14: Implement depth sorting and split occlusion

- Add root-based ground pivots, stable depth keys, biases, and dynamic actor sorting.
- Graybox the desk base/front, chair, cabinet, door jamb, window sill, and foreground wall.
- Add depth-anchor/occluder debug overlay.

Exit gate: a moving placeholder passes correctly in front of and behind every required object from all reachable routes.

#### Step 15: Decode and assemble scene definitions

- Add versioned `SceneDefinition`, `PropDefinition`, `OccluderDefinition`, and placement decoding.
- Build `OfficeAssembler` with placeholder blocks using the same IDs as final art.
- Add schema failure diagnostics.

Exit gate: no office prop coordinate or depth bias is hard-coded in `DetectiveOfficeScene`.

### Phase 4 — prove the BG:EE-style detective pipeline

#### Step 16: Produce the locked character reference set

- Generate character sheet, nine source-orientation turnaround, 16-facing mirrored preview, and seated fit test.
- Keep features readable as large masses at final size: stubble block, hair shape, coat body, shirt/tie zone, hands, shoes.
- Remove small asymmetrical elements that would expose eastern mirroring.

Exit gate: all source directions clearly depict the same low-detail 3D maquette after 512×512 registration and 82-unit display scaling.

#### Step 17: Produce and test one walk cycle

- Generate the SW eight-frame source walk using a reference-edit chain.
- Align root motion, downsample in premultiplied-alpha space to the 100px native body, apply the restrained 96-color ramp, enlarge 2× with nearest sampling, and pack a test atlas.
- Play at 10 fps and 0.25× in the office graybox.

Exit gate: no foot slide, crown jitter, identity drift, smooth painted look, or alpha halo; body reads at 9% of playable height (8–11% acceptable).

#### Step 18: Implement animation playback and actor state

- Add `SpriteAnimationClip`, `SpriteAnimationLibrary`, `SpriteAnimationPlayer`, `ActorStateMachine`, and `ActorNode`.
- Support per-frame duration, loop, completion, and footstep/chair events.
- Add seated, standing-up, standing-idle, walking, and sitting-down states.
- Unit-test queued movement while seated and resume-delta clamping.

Exit gate: placeholder/test textures run the complete seated-to-walk-to-idle state flow deterministically.

#### Step 19: Complete the locomotion source orientations

- Generate the remaining eight walk source orientations and nine four-frame standing idles.
- Mirror to seven eastern-facing display bins at runtime.
- Review all 16 displayed facings, especially boundary transitions and coat/tie continuity.

Exit gate: direction selection is readable, stable, and stylistically consistent in every bin.

#### Step 20: Complete seated transitions

- Generate eight-frame seated idle, 12-frame stand-up, and 12-frame sit-down.
- Register against the actual chair and desk occluder.
- Time chair/cloth audio markers.

Exit gate: the actor never pops, floats, clips the desk front, or changes scale during the seat/stand sequence.

### Phase 5 — build the exterior cinematic

#### Step 21: Generate and assemble exterior layers

- Produce the base, foreground architecture, office-window glow, vignette, transition bloom, and P0 reflection overlays.
- Place all layers from `opening_exterior.scene.json`.
- Validate office-window position in narrow/wide safe views.

Exit gate: the still exterior reads as the intended establishing shot before live effects.

#### Step 22: Implement rain and wet-surface effects

- Add far/mid/near `SKEmitterNode` streaks.
- Add pooled street splashes in authored polygons.
- Add reflection/glow modulation and reduced-effects settings.
- Tune particle counts against performance budgets.

Exit gate: heavy rain feels layered, never falls inside the building mask, and holds 60 fps on target devices.

#### Step 23: Implement the exterior timeline

- Add deterministic cues for fade-in, camera move, window emphasis, audio, preload start, and transition request.
- Support first-run title if retained, skip after one second, and reduced-motion alternate.
- Make skip and natural completion converge on the same route state.

Exit gate: timeline is repeatable, skippable, and cannot double-trigger transition.

### Phase 6 — finish the cinematic transition

#### Step 24: Preload and build the office during the exterior

- Preload office plate, P0 props, seated/standing/walk atlases, definitions, and audio.
- Decode images off the transition-critical frame and create SpriteKit nodes on the main actor before the cut.
- Instrument timings and transition peak memory.

Exit gate: the office is ready before the exterior reaches the match cue under normal and simulated-slow loads.

#### Step 25: Implement the window match and audio crossfade

- Push toward the warm office window.
- Raise the registered bloom/shadow overlay.
- Present the prepared office through the router.
- Crossfade exterior rain/city into rain-on-glass/room tone while preserving one perceptual rain continuum.

Exit gate: no white flash, empty frame, frozen emitter, doubled rain, audio restart, or main-thread hitch.

#### Step 26: Implement skip/reduced-motion transition variants

- Skip uses a shorter fade but the same preload and lifecycle path.
- Reduced motion removes the large camera push and uses a stable dissolve.
- Both preserve audio and restore input only in the office.

Exit gate: all variants arrive in byte-for-byte equivalent gameplay state aside from presentation preferences.

### Phase 7 — assemble final office art and effects

#### Step 27: Generate the empty shell and registered P0 assemblies

- Generate shell first and lock the registration grid.
- Generate desk, chair, door, window, cabinet, radiator, and their shadows/occluders using the approved shell as reference.
- Reject any shell with baked interactive objects.
- Export the flattened QA reference.

Exit gate: runtime assembly matches the approved flattened composite while every P0 object can still be hidden independently.

#### Step 28: Add remaining props and depth anchors

- Add P1 desk objects and room clutter in priority order.
- Give each floor prop a ground anchor and explicit bias only when necessary.
- Keep visual clutter out of navigation and caption zones.

Exit gate: the room feels lived-in at full view and remains readable at phone scale.

#### Step 29: Add office lighting and window rain

- Add warm lamp pool, cool window spill, registered vignette, and subtle actor tint integration.
- Clip glass flow, droplets, and impacts with `office_window_glass_mask`.
- Add reduced-rain and reduced-motion behavior.

Exit gate: the detective reads as a low-detail pre-rendered 3D avatar grounded inside a coherent painterly room; rain never crosses the glass bounds.

### Phase 8 — implement playable interaction

#### Step 30: Add common input and platform bridges

- Implement `GameInputEvent` and `InputRouter`.
- Add iOS touch/gesture and macOS mouse/hover/keyboard bridges.
- Verify view-to-scene conversion under resize and camera zoom.

Exit gate: equivalent touch and mouse actions produce the same world command in tests.

#### Step 31: Add hotspot resolution and approach commands

- Decode five hotspot polygons, priorities, reach cells, facing, predicates, and mutations.
- Resolve hotspot before floor navigation.
- Queue stand, path, face, and inspect as one command.
- Permit cancel/replacement outside non-interruptible frames.

Exit gate: every hotspot is reachable and fires exactly once per confirmed interaction.

#### Step 32: Add observation presentation and first-run hint

- Add localized names and provisional observation copy.
- Add hover label, touch target generosity, observation panel, first-run hint, and focus reveal.
- Keep UI clear of safe areas and actor/prop focal points.

Exit gate: M01 is understandable with touch only and mouse only without permanent hotspot outlines.

#### Step 33: Persist milestone state

- Autosave after office entry and hotspot mutations.
- Restore into a safe normalized office pose.
- Persist opening-seen, hint, focus, reduced-motion, and rain settings.

Exit gate: relaunch does not repeat one-time hint state or restore the actor inside furniture.

### Phase 9 — polish and release-candidate gate

#### Step 34: Audio and foley pass

- Replace temporary loops/one-shots with approved M01 audio.
- Mix exterior/interior buses, footsteps, chair, cloth, door, paper, and phone.
- Test speakers/headphones and app interruption.

Exit gate: ambience repeats are not obvious and observation text remains readable/audible in the mix context.

#### Step 35: Art integration pass

- Inspect alpha edges, palette consistency, prop registration, mirrored facings, foot contact, occlusion, and actor/environment scale.
- Compare runtime office against flattened reference.
- Reject any actor frame that becomes smooth, over-detailed, or proportionally delicate.

Exit gate: art director signs off at native play scale, not only while zoomed into source images.

#### Step 36: Accessibility/usability pass

- Verify text scale presets, captions, focus reveal, reduced motion, reduced rain, safe targets, and keyboard navigation where applicable.
- Test first-time input comprehension without developer guidance.

Exit gate: the complete M01 flow is operable by touch only and mouse only with no progression-critical pixel hunt.

#### Step 37: Performance and lifecycle pass

- Run Instruments for allocations, leaks, frame pacing, and texture residency.
- Test transition peak, app background/foreground, orientation/window resize, and repeated restart/skip cycles.
- Tune emitters and texture bundles without changing the art direction.

Exit gate: performance budgets in the architecture document pass or are explicitly revised with evidence.

#### Step 38: Cross-platform release-candidate verification

- Run automated tests.
- Run the full manual device/window matrix.
- Disable debug performance overlays in Release.
- Verify release resources do not include masters, prompts, registration overlays, or tvOS-only assets.

Exit gate: the definition of done below passes with no open P0/P1 defect.

## 4. Required test matrix

| Surface | Required checks |
|---|---|
| 4:3 iPad landscape | Narrow safe composition, touch targets, caption placement, camera bounds. |
| 16:9 iPhone/Simulator landscape | Reference framing, actor near 9% of playable height, transition alignment. |
| Wide iPhone landscape | Overscan quality, no excessive vertical crop, safe-area controls. |
| macOS 16:9 window | Mouse hover, cursor states, keyboard cancel/focus, audio. |
| macOS resized 4:3 and wide | Live camera relayout, no stretched art, labels stay attached. |
| Reduced motion/rain | Alternate transition, particle reduction, identical game state. |
| Background/resume | No delta jump, doubled emitter/audio, lost input, or corrupt save. |
| Natural/skip opening | Same prepared office and state, no route re-entry. |

## 5. Risk register

| Risk | Early signal | Mitigation | Gate owner |
|---|---|---|---|
| Generated detective looks like smooth concept art or modern PBR | Fine pores, strand hair, painted brushwork, dense cloth response | Enforce faceted low-detail geometry, low-resolution diffuse maps, broad baked light, 512×512 2× registration, and a play-scale style gate | Character art |
| Identity drift across 140 stored frames | Face/coat/hair changes in first test cycle | Reference-edit chain, one source direction at a time, reject on first drift, use animation harness | Character art |
| Mirroring exposes asymmetry/light reversal | Lapel/prop swaps or glaring highlight flip | Near-bilateral sprite design, neutral baked sprite light, preview all 16 facings before locomotion batch | Art + engineering |
| Props do not register to shell | Floating legs, mismatched projection, double shadows | Generate as edits against locked shell, full-canvas registered QA, flattened difference comparison | Environment art |
| Shell contains baked objects | Duplicate prop after runtime placement | Strict forbidden-object prompt and shell acceptance gate; do not paint over after prop production begins | Environment art |
| Actor is too large relative to the room | Detective dominates desk/door at reference view | Lock the 9% body-to-playable-height target in Batch 0 and reject results outside the 8–11% band | Art direction |
| Transition hitches | First office frame stalls or black hold grows | Preload/build before cue, instrument decode, split bundles, retain audio curtain fallback | Engineering |
| Rain overwhelms fill rate/visibility | Frame drops or office shapes disappear | Three bounded quality tiers, particle caps, painted wetness carries look at lower rate | VFX + engineering |
| Depth artifacts | Actor flickers or clips around desk/jamb | Root anchors, stable tie-breaks, authored split occluders, debug overlay route sweep | Engineering + art |
| Platform input diverges | Touch works but hover/cancel or resize fails | Common event model, injected integration tests, validate each phase on both targets | Engineering |
| Aspect ratio destroys composition | Door/window/hotspot leaves narrow view | Central 1481×1111 world-unit safety from style mock onward, overscan outside it | Art + UI |
| Template target settings block users | App requires only the newest beta OS | Decide minimums in Phase 0 and test deployment before content work | Build engineering |

## 6. M01 definition of done

### Functional

- Exterior launches, completes, and skips correctly.
- Transition enters a prepared office with no exposed loading state.
- Detective runs seated idle, stand-up, 16-facing standing/walk, and sit-down states.
- Tap/click floor movement works around all obstacles.
- Five hotspots inspect correctly and persist their flags.
- Touch, mouse, hover, cancel, focus reveal, and relevant keyboard commands behave as specified.

### Visual

- Environment meets the approved pre-rendered painterly isometric quality bar.
- Detective uses the confirmed classic production technique—low-detail 3D source rendered into directional 2D frames—with a controlled 100px native raster, restrained palette, 2× storage, and no hand-authored pixel-art pass.
- Office shell contains no duplicated interactive prop.
- Props, door, actor, light overlays, rain, and occluders are separate and registered.
- Depth/occlusion passes every authored route.
- No alpha halo, stretched asset, mask leak, obvious generation artifact, or aspect-critical crop remains.

### Audio

- Exterior and interior rain feel continuous across the transition.
- Required ambience and foley play without double-triggering or audible loop seams.
- Mix honors settings and lifecycle interruptions.

### Performance and quality

- Automated unit/integration tests pass.
- Target devices hold the agreed frame-rate and memory budgets.
- Release build disables debug overlays and excludes source/QA assets.
- Background/resume, resize, repeated skip, and save/restore pass.
- No open severity-1 or severity-2 issue; any lower issue is recorded with owner and decision.

## 7. Work explicitly deferred after M01

- Branching dialogue graph and voice-over beyond the implemented Lila March case-opening exchange. Prioritized follow-up plan: [Dialogue System Roadmap](DialogueSystemRoadmap.md) (state → triggers → actions → journal-on-transition → multi-graph).
- Evidence journal and deduction board UI.
- Trait/strain progression.
- NPC navigation and crowd avoidance.
- Multiple-area streaming and portals beyond the locked office door.
- Cloud save, achievements, analytics, controller/tvOS support.
- Combat, chase, stealth, or procedural investigation systems.
