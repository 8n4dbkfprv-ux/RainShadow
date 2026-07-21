# Character walk gait V5 correction

Generated on 2026-07-21 with the built-in Image Generator.

## Defect

The V4 sheets varied the body pose but did not reliably exchange the planted and swinging legs. One leg appeared to perform the whole cycle in every direction.

## Corrected construction

Each direction is built from explicit contact/pass pairs instead of asking for an entire ambiguous walk cycle at once:

1. near/camera-side leg contact, far leg behind;
2. near leg bearing weight, far knee and foot swinging forward;
3. far leg contact, near leg behind;
4. far leg bearing weight, near knee and foot swinging forward.

For non-frontal directions, phases three and four come from a separately generated opposite-camera contact/pass pair that is horizontally mirrored back to the target direction. This forces near/far limb layering to exchange instead of allowing the generator to repeat one leading leg. South and north use mirrored first-half poses because those views remain directionally valid under horizontal reflection. Arms reverse in counter-swing.

The shared visual contract remains V4: crude 1998-era textured 3D video-game meshes, hundreds of triangles, tiny diffuse maps, broad planes, primitive Gouraud/vertex light, and no modern PBR or fine surface detail.

## Generator outputs

| Source pair | Output |
|---|---|
| Elias south source | `exec-acbb9900-c006-4d0e-8253-f9def031847b.png` |
| Elias southwest source | `exec-0757275e-e3c9-4c82-8579-a26d8f124088.png` |
| Elias southeast counterpart | `exec-df9da3f1-0b08-402f-9648-1c4094a8348e.png` |
| Elias west source | `exec-2e75228a-5317-4a7a-b25c-0d44f285efa1.png` |
| Elias east counterpart | `exec-c7bce3e9-9985-49b3-b209-65e06232f8db.png` |
| Elias northwest source | `exec-5756c581-36e5-474d-b649-26cf35539317.png` |
| Elias northeast counterpart | `exec-65e1d43a-2aa4-46b0-9598-b71f2f91c847.png` |
| Elias north source | `exec-219cfc10-b749-43bc-accd-836fd18bb065.png` |
| Vivian southwest arrival source | `exec-81f2a4b1-9634-402e-a4d9-e0e8d22f6fd2.png` |
| Vivian southeast arrival counterpart | `exec-fd613a32-0cc5-4ac9-8434-d7ec2d1f7333.png` |
| Vivian northeast departure source | `exec-a8a25b9d-652b-407e-9c6e-4a8ea5ba2626.png` |
| Vivian northwest departure counterpart | `exec-a03bde4b-d353-404e-9739-a47877a62663.png` |

Chroma and RGBA masters live under `Generated/Characters/Detective/WalkGaitV5/` and `Generated/Characters/Client/GaitFixV5/`. `process_character_gait_v5.py` composes, mirrors, registers, and installs 28 corrected walk cells while retaining the 100px native-body, 96-color, 2× nearest-storage V4 runtime contract. The pre-fix walk atlases are preserved under `Generated/Characters/RuntimeBackupGaitFixV5/`.
