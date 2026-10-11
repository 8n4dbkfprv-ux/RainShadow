"""Install the reviewed Blender terrace, and its local navigation patch.
The original city raster is retained outside the authored roof/landing.
"""
import json, shutil, hashlib, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'ArtSource/Blender/ShippingRoofOct11'
OUT=ROOT/'ArtSource/Generated/CityDistrict/ShippingRoofOct11'
OLD=ROOT/'ArtSource/Generated/CityDistrict/WharfLadderLampsOct10'
OUT.mkdir(exist_ok=True);(OUT/'export').mkdir(exist_ok=True);(OUT/'Review').mkdir(exist_ok=True)
g=json.loads((SRC/'geometry.json').read_text())
# Crops have identical cameras, lighting and colour management to the current masters.
if '--nav-only' not in sys.argv:
 for mode in ['day','dusk']:
  im=Image.open(OLD/'export'/f'{mode}_master.png').convert('RGB')
  crop=Image.open(SRC/f'{mode}_crop.png').convert('RGB');box=g['renderBox']
  assert crop.size==(box[2]-box[0],box[3]-box[1]),crop.size
  mask=Image.new('L',crop.size);a=np.asarray(mask).copy();yy,xx=np.indices(a.shape)
  a[:]=np.minimum(1,np.minimum.reduce([xx,yy,a.shape[1]-1-xx,a.shape[0]-1-yy])/32)*255
  im.paste(crop,box,Image.fromarray(a));im.save(OUT/'export'/f'{mode}_master.png')
 import package_wharf_puddles_oct10 as package
 package.OLD=OLD;package.OUT=OUT
 package.prepare([{'box':g['renderBox']}],label='roof');package.install()
area_path=ROOT/'RainShadow Shared/Resources/Areas/city_wharf_ladder.area.json'
sr_path=ROOT/'RainShadow Shared/Resources/Areas/city_wharf_ladder.sr.png'
backup=OUT/'NavigationBefore';backup.mkdir(exist_ok=True)
for p in [area_path,sr_path]:
 if not (backup/p.name).exists():shutil.copy2(p,backup/p.name)
a=json.loads((backup/area_path.name).read_text());area=a['area']
old=json.loads((ROOT/'ArtSource/Blender/WharfHighGround/platform_obstacles.json').read_text())
for key in ['obstacles','sightPermeableObstacles']: area[key]=[r for r in area.get(key,[]) if r not in old]
area['props']=[p for p in area['props'] if p['id']!='wharf.loading.platform']
area['elevationSurfaces']=g['surfaces'];area['ladders']=[g['ladder']]
# Work at one pixel per world unit then conservatively choose full floor cells.
size=(5120,3840);mask=Image.new('L',size);draw=ImageDraw.Draw(mask)
def pts(poly):return [(p['x'],3840-p['y']) for p in poly]
def corners(s):
 o,u,v=[s[k] for k in ['origin','axisU','axisV']]
 return [o,{k:o[k]+u[k] for k in o},{k:o[k]+u[k]+v[k] for k in o},{k:o[k]+v[k] for k in o}]
draw.polygon(pts(g['roofOuter']),fill=8)
for s in g['surfaces']:draw.polygon(pts(corners(s)),fill=7)
draw.polygon(pts(g['chimney']),fill=10)
access=Image.new('L',size);ad=ImageDraw.Draw(access)
for surface in g['surfaces'][1:]:ad.polygon(pts(corners(surface)),fill=255)
# Navigation is 16 x 12 world units. Patch floor only when the entire cell fits.
sr=Image.open(backup/sr_path.name).convert('L');assert sr.size==(320,320),sr.size
patch={}
for row in range(320):
 for col in range(320):
  b=mask.crop((col*16,row*12,(col+1)*16,(row+1)*12));lo,hi=b.getextrema()
  if hi:
   value=7 if lo==hi==7 else 8
   if hi==10:value=0
   if access.crop((col*16,row*12,(col+1)*16,(row+1)*12)).getbbox():value=7
   sr.putpixel((col,row),value);patch[(col,319-row)]=value
# Split only obstacles intersecting the local patch; the raster stays the sole authority.
for key in ['obstacles','sightPermeableObstacles']:
 kept=[]
 for r in area[key]:
  cells=[(c,y) for y in range(int(r['y']//12),int(np.ceil((r['y']+r['h'])/12))) for c in range(int(r['x']//16),int(np.ceil((r['x']+r['w'])/16)))]
  if not any(c in patch for c in cells):kept.append(r);continue
  for c,y in cells:
   if (c,y) not in patch:kept.append(dict(x=c*16,y=y*12,w=16,h=12))
 area[key]=kept
sr_path.unlink();sr.save(sr_path)
area_path.write_text(json.dumps(a,indent=2)+'\n')
(OUT/'navigation_receipt.json').write_text(json.dumps({'cells':len(patch),'source':str(SRC/'Shipping_Roof_Authored.blend')},indent=2))
print('Roof art and navigation installed:',len(patch),'cells')

payload=OUT/'navigation_payload';payload.mkdir(exist_ok=True)
receipt={}
for source in [area_path,sr_path]:
 dest=payload/source.name
 if dest.exists():dest.unlink()
 shutil.copy2(source,dest)
 receipt[str(source.relative_to(ROOT))]=hashlib.sha256(source.read_bytes()).hexdigest()
(OUT/'navigation_installation_receipt.json').write_text(json.dumps({'installedSHA256':receipt},indent=2)+'\n')
