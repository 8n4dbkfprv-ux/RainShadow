# Character pre-rendered 3D V4 style lock

Generated on 2026-07-21 with the built-in Image Generator.

## Review finding

V3 was directionally correct but its source masters still read as polished contemporary low-poly character art. V4 describes the period rendering technology rather than relying on a broad “classic video game 3D” style label. The approved target is a crude 1998-era textured 3D game mesh captured from an old engine and baked into directional sprites.

## Shared generation contract

> Create a genuinely crude 1998-era textured 3D VIDEO GAME MODEL captured from an old engine and baked into a sprite—not polished low-poly concept art, a modern stylized render, or realism. The mesh should plausibly use only 500–900 triangles. Build the face from a few broad planar wedges; make hair a solid angular shell; use mitten-like hands, blunt blocky shoes, and clothing made from broad rigid planes. Simulate tiny 32×32 to 64×64 diffuse texture maps with flat painted color, primitive vertex/Gouraud shading, one neutral directional light, and modest baked occlusion. Use a fixed elevated orthographic/dimetric gameplay camera. No PBR, normal, roughness, or specular maps; no pores, wrinkles, individual hair strands, fine cloth weave, delicate seams, tiny buttons, cinematic rim light, depth of field, floor, cast shadow, scenery, text, UI, or watermark. Place every complete figure on a perfectly flat uniform `#00ff00` chroma field.

Elias keeps his compact broad build, receding dark hair, square bearded face, charcoal coat, cream shirt, loose red tie, brown trousers, and blunt brown shoes. Vivian keeps her burgundy hat and dress, dark waved hair, charcoal raincoat, compact brown handbag on her anatomical left, and brown heels. Sheet prompts change only direction, pose, and phase while retaining this shared contract and the matching V4 identity key.

The words **VIDEO GAME MODEL**, the approximate triangle budget, deliberately tiny diffuse maps, and explicit Gouraud/vertex lighting were decisive. “Low-poly” by itself encouraged a polished modern illustration aesthetic and was therefore insufficient.

## Runtime treatment

`process_pre_rendered_characters_v4.py` removes the chroma key, slices the production sheets, reduces each figure in premultiplied-alpha space to a 100-pixel native body, limits it to 96 colors without dithering, enlarges it 2× with nearest sampling on a 512×512 registered frame, and writes all 55 gameplay cells. SpriteKit displays those cells at 256 points with nearest filtering. The intentionally crude source mesh supplies the period character construction; the raster pass only restores the small native display texture.

## Outputs

| Asset | Generator output | Retained chroma master |
|---|---|---|
| Elias southeast key | `exec-d27c1824-4b5a-45a3-8749-aa770e764460.png` | `Detective/PreRendered3DV4/det_key_se_chroma_v04.png` |
| Elias five-direction idle | `exec-49e748c9-932f-4434-9895-08489c897aeb.png` | `Detective/PreRendered3DV4/det_standing_idle_5dir_chroma_v04.png` |
| Elias five-direction walk | `exec-68a45348-a360-44b2-a1ce-d393e24990cc.png` | `Detective/PreRendered3DV4/det_walk_5dir_4frame_chroma_v04.png` |
| Elias seated idle | `exec-2fe0aa18-3acb-4f3e-b001-1940e3dbb1b4.png` | `Detective/PreRendered3DV4/det_seated_idle_strip_chroma_v04.png` |
| Elias stand-up | `exec-c976161b-982a-4b3f-a76b-a9b0006d8747.png` | `Detective/PreRendered3DV4/det_stand_up_sheet_chroma_v04.png` |
| Vivian southwest key | `exec-a1b7cd7e-6b08-4bea-b477-5ab1939ff4a0.png` | `Client/PreRendered3DV4/vivian_key_sw_chroma_v04.png` |
| Vivian southwest arrival | `exec-06340fa0-447e-4453-a457-f92204f210e2.png` | `Client/PreRendered3DV4/client_arrival_sw_strip_chroma_v04.png` |
| Vivian northeast departure | `exec-b1298d67-f24f-42d3-b38e-80d11842a4d2.png` | `Client/PreRendered3DV4/client_departure_ne_strip_chroma_v04.png` |

Chroma-free RGBA masters and registered runtime previews sit beside these files. The previous V3 runtime set is preserved under `Generated/Characters/RuntimeBackupPreRendered3DV4`.
