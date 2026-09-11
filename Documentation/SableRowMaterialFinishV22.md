# Sable Row material finish V22

Built-in Image Generator produced a six-swatch texture atlas. The original and six inset crops are stored under ArtSource/Blender/SableRowDistrictV22/textures. Exact prompt is texture_prompt.txt; crops use macOS sips (400x610 pixels each), with no artificial upscaling. Integrated via world-space box mapping, restrained albedo blending and fine bump into 15 materials. Assignment list in reviews/material_assignments.json. Material images packed into the Blender file.

Covered varnished oak, awning steel, tires and entrance rubber, laundry and blind linen, diner ivory enamel/crockery/laminate and clay flues. Existing finished masonry, paving, glass, frames, cars, galvanized metal and roofs retained. Emissive materials and dark recess materials were not treated as missing albedo textures.

Geometry: replaced the apartment entry slab and glass-over-wood arrangement with actual wooden stiles and rails around a glazed opening, a recessed lower panel, glazing bars and a dark vestibule backing. The opening is visible in final entrance renders. Previous wide awning and escape clearance geometry retained. No change to navigation, projection or runtime assets.

Reviewed completed entrance and district daylight/noir renders. Geometry checks confirm the replacement glass does not intersect the door frame and the retired solid slab is hidden. All six new texture images are packed. Staged Blender scene and review-resolution renders only, not full-resolution installed masters. Live geometry/material operations and incremental pre-edit backup are saved in the V22 directory.
