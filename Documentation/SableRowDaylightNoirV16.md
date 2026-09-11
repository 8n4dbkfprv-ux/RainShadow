# Sable Row daylight noir — V16

8 September 2026. Requested follow-through on a daylight lighting pass, two distinctive business frontages and a working freight scene. Work performed through live Blender MCP with inspection, incremental backup and viewport/render checks between batches.

## Lighting

Daylight has private copies of all light objects and light data, plus its own world. The sun is directed along (-0.75, 0.45, -0.65), approximately 36.6 degrees below the horizon, with energy 2.1, a 1.2-degree angular size and warm-neutral colour. The broad area light is reduced to 1100 W with a cool tint. Sky strength is 0.40 and exposure +0.4. Street point-light pools are off in daylight; existing emissive fixture surfaces remain. The intent is clear directional shadows with readable shaded doors, not uniform darkening. The V15 noir lights are retained.

## Businesses

Radio Repair becomes Harbor Pawn, reusing the existing shop and windows. Added oxblood fascia, cream lettering, a hanging three-ball brass emblem and small display-window trade lettering. Dockside Lodging has a projecting ROOMS blade sign, two wall brackets and a DAILY / WEEKLY entrance label. Neither business requires changing the building mass or door openings.

## Freight

An unbranded period-inspired light flatbed truck occupies the annex forecourt: rounded bonnet, split windshield, separate glazed cab openings, curved front fenders, steel wheels and hubcaps, running boards, grille bars, individual timber deck planks and open stake sides. Two detailed crates reuse existing generated timber materials and component meshes. A timber-and-steel two-wheel hand truck stands near the warehouse wall. The vehicle is an authored background prop, not a drivable rig or a dimensional replica of a named model.

Period reference: [The Henry Ford’s 1948 F-1](https://www.thehenryford.org/collections/explore/artifact/271123), establishing the early postwar truck family; [Library of Congress pawnshop photograph, circa 1915–1920](https://www.loc.gov/item/2014702996/). Daytime noir direction follows the location-based street character discussed in [Criterion’s account of The Naked City](https://www.criterion.com/current/posts/7340-walkers-in-the-city-jules-dassin-and-bruce-goldstein-in-new-york).

Existing generated textures were reused. Main buildings, apartment details, camera and street geometry are retained. The saved blend and renders remain staged art: no runtime area, navigation, cover or actor-lighting installation.

## Final verification

Final native day and noir masters are 9408 × 7020, Cycles 32 samples. Both were visually reviewed, alongside the freight detail and overview previews. Projection: day +36.69° / −36.68° (worst 0.19°); noir +36.67° / −36.65° (worst 0.22°). Both pass the 1.5° gate. The truck was shifted 0.15 m south after preview inspection to clear the existing crate stack. Updated bounds are recorded in validation.json; this is an authoring footprint check, not vehicle turning or runtime navigation validation. All comparison links resolve.
