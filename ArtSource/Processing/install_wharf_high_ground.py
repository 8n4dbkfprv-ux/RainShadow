"""Install the live-Blender-authored platform's projected surface contract.

Does not rebake the city search map or replace its plate. Solid faces and rails
become ordinary sight-permeable authored obstacles in the existing raster.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
geometry = json.loads((ROOT / 'ArtSource/Blender/WharfHighGround/platform_geometry.json').read_text())
path = ROOT / 'RainShadow Shared/Resources/Areas/city_wharf_ladder.area.json'
document = json.loads(path.read_text())
area = document['area']
# The overlay is registered to projected feet, so the ordinary ground ring,
# shadow, click target and projectile origin all use the visible floor.
prop = dict(id='wharf.loading.platform', textureName='wharf_loading_platform_v01',
            layer='floorEffects', groundPoint=geometry['worldOrigin'], anchorX=.5,
            anchorY=.5, worldSize=geometry['worldSize'], depthBias=9000)
# makeProp applies the floor layer to both root and child. Cancel the child's
# duplicate offset for this overlay so it sits above the plate, below actors.
area['props'] = [p for p in area['props'] if p['id'] != prop['id']] + [prop]
area['elevationSurfaces'] = geometry['surfaces']
ownership = ROOT / 'ArtSource/Blender/WharfHighGround/platform_obstacles.json'
old = area.pop('loadingPlatformObstacleRects', None)
if old is None: old = json.loads(ownership.read_text()) if ownership.exists() else []
for key in ['obstacles', 'sightPermeableObstacles']:
    area[key] = [r for r in area.get(key, []) if r not in old]

# Small local mask, four samples per world unit. Emit aligned 16x12 cells;
# SearchMap remains the sole runtime clearance authority.
left, bottom, width, height, scale = 1456, 2004, 464, 420, 4
mask = Image.new('L', (width * scale, height * scale))
draw = ImageDraw.Draw(mask)
def xy(p): return ((p['x'] - left) * scale, (p['y'] - bottom) * scale)
for face in geometry['solidFaces']: draw.polygon([xy(p) for p in face], fill=255)
for plane in geometry['surfaces']:
    o, u, v = [plane[k] for k in ['origin', 'axisU', 'axisV']]
    corners = [o, {k:o[k]+u[k] for k in o}, {k:o[k]+u[k]+v[k] for k in o}, {k:o[k]+v[k] for k in o}]
    draw.polygon([xy(p) for p in corners], fill=0)
for edge in geometry['edges']: draw.line([xy(p) for p in edge], fill=255, width=4)
rects = []
for y in range(0, height, 12):
    run = None
    for x in range(0, width, 16):
        if mask.crop((x*scale,y*scale,(x+16)*scale,(y+12)*scale)).getbbox():
            if run is None: run = dict(x=left+x,y=bottom+y,w=16,h=12)
            else: run['w'] += 16
        elif run is not None:
            rects.append(run); run = None
    if run is not None: rects.append(run)
for key in ['obstacles', 'sightPermeableObstacles']: area[key] += rects
ownership.write_text(json.dumps(rects, indent=2) + '\n')
path.write_text(json.dumps(document, indent=2) + '\n')
print(f'Installed {len(rects)} sight-permeable cells and {len(geometry["surfaces"])} elevation planes')
