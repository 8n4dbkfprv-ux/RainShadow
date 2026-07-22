# Anatomically tracked walk gait V8

Generated on 2026-07-22 with the built-in Image Generator.

## Defect

V7 made the second half visibly different with exaggerated knee and toe-off poses,
but this produced an unnatural cadence and still allowed the generator to lose
track of which anatomical leg owned a pose.

## Anatomical phase contract

Every affected four-frame cycle now follows explicit right/left ownership:

1. anatomical **right leg forward**, left leg back;
2. right leg supporting, **left leg passing**;
3. anatomical **left leg forward**, right leg back;
4. left leg supporting, **right leg passing**.

The right leg uses a consistent slightly warmer/lighter brown or skin-depth ramp;
the left leg uses a cooler/darker ramp. The processor enforces that identity after
generation so the model cannot silently relabel the legs between frames.

All four poses for a direction are generated together to keep stride length,
ground line, torso height, camera, and body proportions coherent. Passing feet
remain low and body bob is restrained; the V7 high-knee and rear-kick repair poses
are no longer used.

## Selected generator outputs

- Detective SW base cycle: `exec-fe21e01b-6364-4298-8c3c-05e47d799f38.png`
- Detective W base cycle: `exec-22cac6f7-13ff-4b6b-86f4-98665b137aaf.png`
- Detective NW base cycle: `exec-ab5a0a19-3752-4a8c-a5ec-8d2f04a9b2e8.png`
- Client arrival SW base cycle: `exec-dc401b79-8aa4-41f9-b0cb-cf1a4ea6314a.png`
- Client departure NE base cycle: `exec-a080e4fb-cc0d-4684-b441-0159c564d7e5.png`

## Final prompt pattern

> RED in the pose guide always means the character's anatomical RIGHT leg; BLUE
> always means anatomical LEFT. Frame 1: right forward / left back. Frame 2:
> right supporting / left passing low. Frame 3: left forward / right back. Frame
> 4: left supporting / right passing low. Preserve the exact locked camera,
> identity, outfit, body scale, common ground line, and restrained ordinary walk.
> No high knee, rear kick, idle phase, running pose, or duplicated leg ownership.

Sources, keyed RGBA sheets, registered frames, and previews live under
`Generated/Characters/Detective/WalkGaitV8/` and
`Generated/Characters/Client/GaitFixV8/`.
